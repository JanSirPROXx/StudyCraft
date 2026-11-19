import Foundation

// Was an einem Lerntag passiert ist. Jedes Gerät führt sein eigenes Protokoll; die Summe über alle
// Geräte ergibt die Statistik.
struct DayLog: Codable, Equatable, Sendable {
  var reviews = 0
  var newCards = 0
  var reviewCards = 0  // Antworten auf bereits gelernte Karten …
  var reviewCorrect = 0  // … und wie viele davon nicht "Nochmal" waren (Behaltensrate)
  var seconds = 0.0

  mutating func add(_ other: DayLog) {
    reviews += other.reviews
    newCards += other.newCards
    reviewCards += other.reviewCards
    reviewCorrect += other.reviewCorrect
    seconds += other.seconds
  }

  mutating func subtract(_ other: DayLog) {
    reviews = max(0, reviews - other.reviews)
    newCards = max(0, newCards - other.newCards)
    reviewCards = max(0, reviewCards - other.reviewCards)
    reviewCorrect = max(0, reviewCorrect - other.reviewCorrect)
    seconds = max(0, seconds - other.seconds)
  }
}

// Die Datei, die ein Gerät in den Lernordner schreibt (`_StudyCraft/progress-<Geräte-ID>.json`).
// Jedes Gerät schreibt nur seine eigene Datei und liest die der anderen: so entstehen in iCloud
// keine Schreibkonflikte, und der Stand lässt sich trotzdem zusammenführen.
struct DeviceProgress: Codable, Equatable, Sendable {
  var version = 1
  var deviceID: String
  var deviceName = ""
  var cards: [String: CardProgress] = [:]
  var days: [String: DayLog] = [:]  // Schlüssel: Lerntag als Zahl
}

// Der zusammengeführte Lernstand aller Geräte. Pro Karte gewinnt die jüngste Antwort.
struct ProgressBook: Sendable {
  private(set) var own: DeviceProgress
  private(set) var remotes: [DeviceProgress] = []
  private(set) var merged: [String: CardProgress] = [:]
  private(set) var days: [Int: DayLog] = [:]

  init(deviceID: String, deviceName: String) {
    own = DeviceProgress(deviceID: deviceID, deviceName: deviceName)
  }

  func state(for cardID: String) -> CardProgress? { merged[cardID] }

  // Der eigene Stand aus der Datei dieses Geräts (beim Öffnen des Ordners).
  mutating func adopt(own file: DeviceProgress) {
    guard file.deviceID == own.deviceID else { return }
    own.cards = file.cards
    own.days = file.days
    rebuild()
  }

  mutating func setRemotes(_ files: [DeviceProgress]) {
    remotes = files.filter { $0.deviceID != own.deviceID }
    rebuild()
  }

  mutating func record(cardID: String, progress: CardProgress, day: Int, log: DayLog) {
    own.cards[cardID] = progress
    merged[cardID] = progress
    var entry = own.days[String(day)] ?? DayLog()
    entry.add(log)
    own.days[String(day)] = entry
    var total = days[day] ?? DayLog()
    total.add(log)
    days[day] = total
  }

  // Nimmt eine Antwort zurück: der Stand der Karte und das Tagesprotokoll sind danach wie vorher.
  mutating func revert(cardID: String, to old: CardProgress?, day: Int, log: DayLog) {
    if let old {
      own.cards[cardID] = old
      merged[cardID] = old
    } else {
      own.cards.removeValue(forKey: cardID)
      merged.removeValue(forKey: cardID)
    }
    if var entry = own.days[String(day)] {
      entry.subtract(log)
      own.days[String(day)] = entry
    }
    if var total = days[day] {
      total.subtract(log)
      days[day] = total
    }
  }

  // Karten haben eine neue Kennung bekommen (Deck umbenannt, Vorderseite geändert): der Lernstand zieht um.
  mutating func migrate(_ mapping: [String: String]) {
    for (old, new) in mapping where old != new {
      guard let state = own.cards[old] ?? merged[old] else { continue }
      own.cards[new] = state
      own.cards.removeValue(forKey: old)
    }
    rebuild()
  }

  private mutating func rebuild() {
    merged = [:]
    days = [:]
    for file in remotes + [own] {
      for (id, progress) in file.cards {
        if let existing = merged[id], existing.updatedAt > progress.updatedAt { continue }
        merged[id] = progress
      }
      for (key, log) in file.days {
        guard let day = Int(key) else { continue }
        var total = days[day] ?? DayLog()
        total.add(log)
        days[day] = total
      }
    }
  }
}

// MARK: Dateien

enum ProgressFiles {
  static let folderName = "_StudyCraft"

  static func directory(in root: URL) -> URL {
    root.appendingPathComponent(folderName, isDirectory: true)
  }

  private static var decoder: JSONDecoder {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
  }

  private static var encoder: JSONEncoder {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    e.outputFormatting = [.sortedKeys]
    return e
  }

  // Alle Fortschrittsdateien im Ordner. Die Datei dieses Geräts kommt getrennt zurück.
  static func loadAll(root: URL, ownID: String) -> (own: DeviceProgress?, remotes: [DeviceProgress])
  {
    let fm = FileManager.default
    let directory = directory(in: root)
    let names = (try? fm.contentsOfDirectory(atPath: directory.path)) ?? []
    var own: DeviceProgress?
    var remotes: [DeviceProgress] = []
    for name in names {
      // Noch nicht geladene iCloud-Dateien: Download anstoßen, beim nächsten Durchlauf lesen.
      if name.hasPrefix(".progress-"), name.hasSuffix(".json.icloud") {
        let real = String(name.dropFirst().dropLast(7))
        try? fm.startDownloadingUbiquitousItem(at: directory.appendingPathComponent(real))
        continue
      }
      guard name.hasPrefix("progress-"), name.hasSuffix(".json") else { continue }
      let url = directory.appendingPathComponent(name)
      guard let data = try? FileIO.readData(url),
        let file = try? decoder.decode(DeviceProgress.self, from: data)
      else { continue }
      if file.deviceID == ownID {
        if own == nil || file.cards.count > own!.cards.count { own = file }
      } else {
        remotes.append(file)
      }
    }
    return (own, remotes)
  }

  static func write(_ progress: DeviceProgress, root: URL) throws {
    let directory = directory(in: root)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("progress-\(progress.deviceID).json")
    let data = try encoder.encode(progress)
    try FileIO.writeData(data, to: url)
  }
}

// Schreibzugriffe nacheinander, damit eine ältere Fassung nie eine neuere überschreibt.
actor ProgressWriter {
  func write(_ progress: DeviceProgress, root: URL) throws {
    try ProgressFiles.write(progress, root: root)
  }
}

// Lesen und Schreiben im Lernordner immer koordiniert: iCloud lädt dabei fehlende Dateien nach und
// meldet Änderungen an die anderen Geräte.
enum FileIO {
  static func readData(_ url: URL) throws -> Data {
    var coordinationError: NSError?
    var result: Result<Data, Error>?
    NSFileCoordinator(filePresenter: nil).coordinate(
      readingItemAt: url, options: [], error: &coordinationError
    ) { location in
      result = Result { try Data(contentsOf: location) }
    }
    if let coordinationError { throw coordinationError }
    return try result?.get() ?? Data()
  }

  static func readString(_ url: URL) throws -> String {
    let data = try readData(url)
    if let text = String(data: data, encoding: .utf8) { return text }
    if let text = String(data: data, encoding: .isoLatin1) { return text }
    throw CocoaError(.fileReadInapplicableStringEncoding)
  }

  static func move(_ source: URL, to destination: URL) throws {
    var coordinationError: NSError?
    var result: Result<Void, Error>?
    NSFileCoordinator(filePresenter: nil).coordinate(
      writingItemAt: source, options: .forMoving, writingItemAt: destination,
      options: .forReplacing, error: &coordinationError
    ) { from, to in
      result = Result { try FileManager.default.moveItem(at: from, to: to) }
    }
    if let coordinationError { throw coordinationError }
    try result?.get()
  }

  static func remove(_ url: URL) throws {
    var coordinationError: NSError?
    var result: Result<Void, Error>?
    NSFileCoordinator(filePresenter: nil).coordinate(
      writingItemAt: url, options: .forDeleting, error: &coordinationError
    ) { location in
      result = Result { try FileManager.default.removeItem(at: location) }
    }
    if let coordinationError { throw coordinationError }
    try result?.get()
  }

  static func writeData(_ data: Data, to url: URL) throws {
    var coordinationError: NSError?
    var result: Result<Void, Error>?
    NSFileCoordinator(filePresenter: nil).coordinate(
      writingItemAt: url, options: .forReplacing, error: &coordinationError
    ) { location in
      result = Result { try data.write(to: location, options: .atomic) }
    }
    if let coordinationError { throw coordinationError }
    try result?.get()
  }
}
