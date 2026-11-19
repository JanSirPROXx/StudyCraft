import Observation
import SwiftUI
import UIKit

enum AppearanceMode: String, CaseIterable, Identifiable {
  case system, light, dark
  var id: String { rawValue }
  var title: String {
    switch self {
    case .system: "System"
    case .light: "Hell"
    case .dark: "Dunkel"
    }
  }
  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
}

// Der Zustand der ganzen App: der gewählte Lernordner, die Decks darin, der Lernstand und die
// Einstellungen. Alles Langsame (Ordner einlesen, Dateien schreiben) läuft abseits des Hauptthreads.
@MainActor @Observable
final class AppModel {
  private enum Keys {
    static let bookmark = "rootBookmark"
    static let studyMode = "studyMode"
    static let appearance = "appearanceMode"
    static let deviceID = "deviceID"
  }

  // Einstellungen
  var studyMode: StudyMode {
    didSet { defaults.set(studyMode.rawValue, forKey: Keys.studyMode) }
  }
  var appearance: AppearanceMode {
    didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
  }

  // Zustand
  private(set) var rootURL: URL?
  private(set) var isRestoring = true
  private(set) var hasScanned = false
  private(set) var isScanning = false
  private(set) var decks: [DeckNode] = []
  private(set) var counts: [String: DeckCounts] = [:]
  private(set) var totalCards = 0
  private(set) var progress: ProgressBook
  var errorMessage: String?
  var activeSession: StudySession?

  @ObservationIgnored private(set) var cardsByID: [String: Card] = [:]
  @ObservationIgnored private(set) var imageIndex: [String: URL] = [:]
  @ObservationIgnored let scheduler = Scheduler()
  @ObservationIgnored private let defaults = UserDefaults.standard
  @ObservationIgnored private let deviceID: String
  @ObservationIgnored private var scopedURL: URL?
  @ObservationIgnored private var parseCache: [String: CachedFile] = [:]
  @ObservationIgnored private var signature = ""
  @ObservationIgnored private var watcher: FolderWatcher?
  @ObservationIgnored private var pollTask: Task<Void, Never>?
  @ObservationIgnored private var changeTask: Task<Void, Never>?
  @ObservationIgnored private var saveTask: Task<Void, Never>?
  @ObservationIgnored private let writer = ProgressWriter()
  @ObservationIgnored private var ownLoaded = false
  @ObservationIgnored private var dirty = false
  @ObservationIgnored private var refreshAgain = false
  @ObservationIgnored private var appActive = true

  // Wie weit im Voraus Lernkarten (z. B. "in 10 Minuten") schon zur Sitzung gehören.
  static let learnAhead: TimeInterval = 20 * 60

  init() {
    studyMode = defaults.string(forKey: Keys.studyMode).flatMap(StudyMode.init) ?? .shuffle
    appearance = defaults.string(forKey: Keys.appearance).flatMap(AppearanceMode.init) ?? .system
    let id = defaults.string(forKey: Keys.deviceID) ?? UUID().uuidString
    defaults.set(id, forKey: Keys.deviceID)
    deviceID = id
    progress = ProgressBook(deviceID: id, deviceName: UIDevice.current.model)
  }

  var rootName: String { rootURL?.lastPathComponent ?? "" }

  // MARK: Ordner wählen

  func restore() async {
    defer { isRestoring = false }
    #if DEBUG
      let arguments = CommandLine.arguments
      if let flag = arguments.firstIndex(of: "-StudyCraftRoot"), flag + 1 < arguments.count {
        await open(URL(fileURLWithPath: arguments[flag + 1]), scoped: false)
        return
      }
    #endif
    guard let data = defaults.data(forKey: Keys.bookmark) else { return }
    var stale = false
    do {
      let url = try URL(
        resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
      let scoped = url.startAccessingSecurityScopedResource()
      if stale, let fresh = try? url.bookmarkData() { defaults.set(fresh, forKey: Keys.bookmark) }
      await open(url, scoped: scoped)
    } catch {
      defaults.removeObject(forKey: Keys.bookmark)
      errorMessage = "Der Lernordner ist nicht mehr erreichbar. Bitte wähle ihn erneut."
    }
  }

  // Der Ordner kommt aus dem Dateien-Dialog; der Zugriff gilt nur, solange er "geöffnet" ist.
  func choose(_ url: URL) {
    let scoped = url.startAccessingSecurityScopedResource()
    do {
      let data = try url.bookmarkData(
        options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
      defaults.set(data, forKey: Keys.bookmark)
    } catch {
      if scoped { url.stopAccessingSecurityScopedResource() }
      errorMessage = "Der Ordner konnte nicht gemerkt werden: \(error.localizedDescription)"
      return
    }
    Task { await open(url, scoped: scoped) }
  }

  private func open(_ url: URL, scoped: Bool) async {
    await flush()
    closeRoot()
    rootURL = url
    scopedURL = scoped ? url : nil
    hasScanned = false
    progress = ProgressBook(deviceID: deviceID, deviceName: UIDevice.current.model)
    ownLoaded = false
    dirty = false
    decks = []
    counts = [:]
    cardsByID = [:]
    totalCards = 0
    parseCache = [:]
    signature = ""

    let watcher = FolderWatcher(root: url) { [weak self] in
      Task { @MainActor in self?.folderChanged() }
    }
    watcher.ownDeviceID = deviceID
    watcher.start()
    self.watcher = watcher

    pollTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(10))
        guard let self, !Task.isCancelled else { return }
        if self.appActive { await self.refresh() }
      }
    }
    await refresh()
  }

  private func closeRoot() {
    pollTask?.cancel()
    changeTask?.cancel()
    saveTask?.cancel()
    watcher?.stop()
    watcher = nil
    scopedURL?.stopAccessingSecurityScopedResource()
    scopedURL = nil
    rootURL = nil
  }

  // MARK: Einlesen

  private func folderChanged() {
    changeTask?.cancel()
    changeTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(600))
      guard !Task.isCancelled else { return }
      await self?.refresh()
    }
  }

  func refresh() async {
    guard let root = rootURL else { return }
    if isScanning {
      refreshAgain = true
      return
    }
    isScanning = true
    let cache = parseCache
    let ownID = deviceID
    async let scanned = Task.detached(priority: .userInitiated) {
      FolderScanner.scan(root: root, cache: cache)
    }.value
    async let loaded = Task.detached(priority: .userInitiated) {
      ProgressFiles.loadAll(root: root, ownID: ownID)
    }.value
    let (library, files) = await (scanned, loaded)
    isScanning = false
    guard root == rootURL else { return }

    parseCache = library.cache
    if library.signature != signature {
      signature = library.signature
      decks = library.decks
      cardsByID = library.cards
      imageIndex = library.imageIndex
      totalCards = library.cards.count
    }
    if !ownLoaded {
      if let own = files.own { progress.adopt(own: own) }
      ownLoaded = true
    }
    progress.setRemotes(files.remotes)
    hasScanned = true
    recomputeCounts()

    if refreshAgain {
      refreshAgain = false
      await refresh()
    }
  }

  func setActive(_ active: Bool) {
    appActive = active
    if active {
      Task { await refresh() }
    } else {
      Task { await flush() }
    }
  }

  // MARK: Zählen

  func recomputeCounts() {
    let now = Date()
    let today = StudyClock.dayIndex(for: now)
    var result: [String: DeckCounts] = [:]

    func visit(_ node: DeckNode) -> DeckCounts {
      var counts = DeckCounts()
      for card in node.cards where !card.hidden {
        counts.total += 1
        guard let state = progress.state(for: card.id) else {
          counts.new += 1
          continue
        }
        switch state.queue {
        case .new: counts.new += 1
        case .learning, .relearning:
          if state.due <= now.addingTimeInterval(Self.learnAhead) { counts.due += 1 }
        case .review:
          if StudyClock.dayIndex(for: state.due) <= today { counts.due += 1 }
        }
      }
      for child in node.children {
        let c = visit(child)
        counts.new += c.new
        counts.due += c.due
        counts.total += c.total
      }
      result[node.id] = counts
      return counts
    }
    for deck in decks { _ = visit(deck) }
    counts = result
  }

  func counts(for node: DeckNode) -> DeckCounts { counts[node.id] ?? DeckCounts() }

  // MARK: Lernen

  func startSession(_ node: DeckNode) {
    activeSession = StudySession(deck: node, mode: studyMode, model: self)
  }

  // Was nötig ist, um eine Antwort wieder zurückzunehmen.
  struct RatingToken {
    var cardID: String
    var old: CardProgress?
    var day: Int
    var log: DayLog
  }

  @discardableResult
  func record(card: Card, old: CardProgress?, new: CardProgress, rating: Rating, seconds: TimeInterval)
    -> RatingToken
  {
    var log = DayLog()
    log.reviews = 1
    log.seconds = seconds
    if old == nil || old?.queue == .new {
      log.newCards = 1
    } else if old?.queue == .review {
      log.reviewCards = 1
      if rating != .again { log.reviewCorrect = 1 }
    }
    let day = StudyClock.dayIndex(for: new.updatedAt)
    progress.record(cardID: card.id, progress: new, day: day, log: log)
    dirty = true
    scheduleSave()
    recomputeCounts()
    return RatingToken(cardID: card.id, old: old, day: day, log: log)
  }

  func undo(_ token: RatingToken) {
    progress.revert(cardID: token.cardID, to: token.old, day: token.day, log: token.log)
    dirty = true
    scheduleSave()
    recomputeCounts()
  }

  // MARK: Speichern

  private func scheduleSave() {
    saveTask?.cancel()
    saveTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled else { return }
      await self?.flush()
    }
  }

  func flush() async {
    saveTask?.cancel()
    guard dirty, let root = rootURL else { return }
    dirty = false
    do {
      try await writer.write(progress.own, root: root)
    } catch {
      dirty = true
      errorMessage = "Der Lernfortschritt konnte nicht gespeichert werden: \(error.localizedDescription)"
    }
  }

  // MARK: Bilder

  func imageResolver(for card: Card) -> ImageResolver {
    ImageResolver(directory: card.directory, root: rootURL, index: imageIndex)
  }

  func imageResolver(deckID: String) -> ImageResolver {
    ImageResolver(directory: folderURL(deckID), root: rootURL, index: imageIndex)
  }

  // MARK: Decks und Karten bearbeiten

  func folderURL(_ deckID: String) -> URL {
    let root = rootURL ?? URL(fileURLWithPath: "/")
    return deckID.isEmpty ? root : root.appendingPathComponent(deckID, isDirectory: true)
  }

  private func fail(_ message: String, _ error: Error) {
    errorMessage = "\(message): \(error.localizedDescription)"
  }

  // Alle Decks als flache Liste (für die Auswahl beim Anlegen einer Karte), Unterdecks mit Pfad.
  var deckChoices: [(id: String, title: String)] {
    var result: [(String, String)] = []
    func add(_ nodes: [DeckNode]) {
      for node in nodes {
        result.append((node.id, node.id.isEmpty ? node.name : node.id.replacingOccurrences(of: "/", with: " › ")))
        add(node.children)
      }
    }
    add(decks)
    return result
  }

  // Die Kennung eines neuen Decks unter `parent`, oder nil mit Fehlermeldung. Der Ordner entsteht erst,
  // wenn die erste Karte gespeichert wird.
  func newDeckID(parent: String, name: String) -> String? {
    let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty else { return nil }
    guard !clean.contains("/"), !clean.contains(":"), !clean.hasPrefix("."),
      clean != ProgressFiles.folderName
    else {
      errorMessage = "Der Name darf weder „/“ noch „:“ enthalten und nicht mit einem Punkt beginnen."
      return nil
    }
    let id = parent.isEmpty ? clean : parent + "/" + clean
    if FileManager.default.fileExists(atPath: folderURL(id).path) {
      errorMessage = "Es gibt schon ein Deck „\(clean)“."
      return nil
    }
    return id
  }

  func renameDeck(_ node: DeckNode, to newName: String) async -> Bool {
    let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !node.id.isEmpty, !name.isEmpty else { return false }
    guard !name.contains("/"), !name.contains(":"), !name.hasPrefix(".") else {
      errorMessage = "Der Name darf weder „/“ noch „:“ enthalten und nicht mit einem Punkt beginnen."
      return false
    }
    let parent = node.id.contains("/") ? String(node.id[..<node.id.lastIndex(of: "/")!]) + "/" : ""
    let newID = parent + name
    if newID == node.id { return true }
    let source = folderURL(node.id)
    let destination = folderURL(newID)
    let caseOnly = newID.lowercased() == node.id.lowercased()
    if !caseOnly, FileManager.default.fileExists(atPath: destination.path) {
      errorMessage = "Es gibt schon einen Ordner „\(name)“."
      return false
    }
    do {
      try await Task.detached { try FileIO.move(source, to: destination) }.value
    } catch {
      fail("Das Deck konnte nicht umbenannt werden", error)
      return false
    }
    // Der Lernstand zieht mit: Karten-Kennungen beginnen mit dem Ordnerpfad.
    let oldPrefix = node.id + "/"
    var mapping: [String: String] = [:]
    for id in progress.merged.keys where id.hasPrefix(oldPrefix) {
      mapping[id] = newID + "/" + id.dropFirst(oldPrefix.count)
    }
    progress.migrate(mapping)
    dirty = true
    scheduleSave()
    await refresh()
    return true
  }

  func deleteDeck(_ node: DeckNode) async {
    guard !node.id.isEmpty else { return }
    let url = folderURL(node.id)
    do {
      try await Task.detached { try FileIO.remove(url) }.value
    } catch {
      fail("Das Deck konnte nicht gelöscht werden", error)
    }
    await refresh()
  }

  // In diese Datei kommen neue Karten eines Decks: die erste Listen-Datei direkt in seinem Ordner.
  private func listFile(in deckID: String) -> URL? {
    let candidates = cardsByID.values.filter {
      $0.deckID == deckID && parseCache[$0.filePath]?.parsed?.isList == true
    }
    return candidates.min { $0.filePath.localizedStandardCompare($1.filePath) == .orderedAscending }?
      .fileURL
  }

  func saveCard(_ card: Card?, deckID: String, front: String, back: String) async -> Bool {
    do {
      if let card {
        try await Task.detached { try CardStore.update(card: card, front: front, back: back) }.value
        if !card.isSingle {
          let renamed = CardIdentity.id(
            file: card.filePath,
            card: ParsedCard(front: CardParser.trimmed(front), back: CardParser.trimmed(back)),
            index: 0, isSingle: false)
          progress.migrate([card.id: renamed])
          dirty = true
          scheduleSave()
        }
      } else {
        let target = listFile(in: deckID)
        let folder = folderURL(deckID)
        try await Task.detached {
          try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
          if let target {
            try CardStore.append(to: target, front: front, back: back)
          } else {
            try CardStore.createList(in: folder, front: front, back: back)
          }
        }.value
      }
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
    await refresh()
    return true
  }

  func setHidden(_ hidden: Bool, card: Card) async {
    do {
      try await Task.detached { try CardStore.setHidden(hidden, card: card) }.value
    } catch {
      errorMessage = error.localizedDescription
    }
    await refresh()
  }

  func deleteCard(_ card: Card) async {
    do {
      try await Task.detached { try CardStore.remove(card: card) }.value
    } catch {
      errorMessage = error.localizedDescription
    }
    await refresh()
  }

  // Legt ein Bild aus der Fotomediathek im Ordner des Decks ab und gibt den Dateinamen zurück.
  func addImage(_ data: Data, deckID: String) async -> String? {
    guard let image = UIImage(data: data) else { return nil }
    let folder = folderURL(deckID)
    do {
      return try await Task.detached {
        let name = "Bild-" + Self.imageStamp() + ".jpg"
        let longest = max(image.size.width, image.size.height)
        var output = image
        if longest > 2000 {
          let scale = 2000 / longest
          let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
          let format = UIGraphicsImageRendererFormat.default()
          format.scale = 1
          output = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
          }
        }
        guard let jpeg = output.jpegData(compressionQuality: 0.85) else {
          throw CocoaError(.fileWriteUnknown)
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileIO.writeData(jpeg, to: folder.appendingPathComponent(name))
        return name
      }.value
    } catch {
      fail("Das Bild konnte nicht gespeichert werden", error)
      return nil
    }
  }

  nonisolated private static func imageStamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
    return formatter.string(from: Date())
  }

  // MARK: Statistik

  func makeStats() -> StatsSummary {
    let now = Date()
    let today = StudyClock.dayIndex(for: now)
    var stats = StatsSummary()
    stats.today = progress.days[today] ?? DayLog()
    stats.cardsToday = progress.merged.values.reduce(0) {
      $0 + (StudyClock.dayIndex(for: $1.updatedAt) == today ? 1 : 0)
    }

    let active = Set(progress.days.filter { $0.value.reviews > 0 }.keys)
    var day = active.contains(today) ? today : today - 1
    while active.contains(day) {
      stats.streak += 1
      day -= 1
    }
    var run = 0
    var previous: Int?
    for d in active.sorted() {
      run = (previous.map { d == $0 + 1 } ?? false) ? run + 1 : 1
      stats.longestStreak = max(stats.longestStreak, run)
      previous = d
    }
    stats.activeDays = active.count
    stats.totalReviews = progress.days.values.reduce(0) { $0 + $1.reviews }
    stats.totalSeconds = progress.days.values.reduce(0) { $0 + $1.seconds }
    stats.recent = (0..<14).reversed().map { offset in
      DayPoint(day: today - offset, reviews: progress.days[today - offset]?.reviews ?? 0)
    }

    var reviewed = 0
    var correct = 0
    for offset in 0..<30 {
      guard let log = progress.days[today - offset] else { continue }
      reviewed += log.reviewCards
      correct += log.reviewCorrect
    }
    stats.retention = reviewed >= 5 ? Double(correct) / Double(reviewed) : nil

    for card in cardsByID.values where !card.hidden {
      switch progress.state(for: card.id)?.queue {
      case nil, .new?: stats.newCards += 1
      case .learning?, .relearning?: stats.learningCards += 1
      case .review?:
        if (progress.state(for: card.id)?.interval ?? 0) >= 21 {
          stats.matureCards += 1
        } else {
          stats.youngCards += 1
        }
      }
    }
    return stats
  }
}

struct DayPoint: Identifiable {
  var day: Int
  var reviews: Int
  var id: Int { day }
  var date: Date { StudyClock.startOfDay(day) }
}

struct StatsSummary {
  var today = DayLog()
  var cardsToday = 0  // verschiedene Karten, die heute beantwortet wurden
  var streak = 0
  var longestStreak = 0
  var activeDays = 0
  var totalReviews = 0
  var totalSeconds = 0.0
  var recent: [DayPoint] = []
  var retention: Double?
  var newCards = 0
  var learningCards = 0
  var youngCards = 0
  var matureCards = 0
}
