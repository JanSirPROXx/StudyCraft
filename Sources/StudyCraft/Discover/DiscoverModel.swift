import Observation
import SwiftUI

// Der Zustand von „Entdecken“: der Katalog, die laufenden Downloads und die Auswahl (Suche, Sprache).
@MainActor @Observable
final class DiscoverModel {
  enum Phase: Equatable {
    case idle, loading, loaded
    case failed(String)
  }

  private(set) var phase = Phase.idle
  private(set) var decks: [DiscoverDeck] = []
  private(set) var showsCachedCatalog = false
  private(set) var downloads: [String: Double] = [:]  // Deck-Kennung → Fortschritt 0…1
  private(set) var justInstalled: Set<String> = []
  var search = ""
  var language: String?  // nil: alle Sprachen

  @ObservationIgnored private unowned let app: AppModel
  @ObservationIgnored private let base: URL
  @ObservationIgnored private let session: URLSession

  init(app: AppModel, base: URL = DiscoverConfig.baseURL, session: URLSession = .shared) {
    self.app = app
    self.base = base
    self.session = session
  }

  // MARK: Katalog

  func load(force: Bool = false) async {
    if phase == .loading || (phase == .loaded && !force) { return }
    phase = .loading
    do {
      var request = URLRequest(
        url: DiscoverConfig.catalogURL(base: base), cachePolicy: .reloadIgnoringLocalCacheData,
        timeoutInterval: 15)
      request.setValue("application/json", forHTTPHeaderField: "Accept")
      let (data, response) = try await session.data(for: request)
      if let http = response as? HTTPURLResponse, http.statusCode != 200 {
        throw DiscoverError.server(http.statusCode)
      }
      let catalog = try DiscoverConfig.decode(data)
      decks = catalog.decks
      showsCachedCatalog = false
      try? data.write(to: Self.cacheURL, options: .atomic)
      phase = .loaded
    } catch {
      // Ohne Netz zeigen wir den zuletzt geladenen Katalog; Laden geht dann natürlich nicht.
      if let data = try? Data(contentsOf: Self.cacheURL),
        let catalog = try? DiscoverConfig.decode(data), !catalog.decks.isEmpty
      {
        decks = catalog.decks
        showsCachedCatalog = true
        phase = .loaded
      } else {
        phase = .failed("Die Decks konnten nicht geladen werden. Prüfe deine Internetverbindung.")
      }
    }
  }

  private static var cacheURL: URL {
    URL.cachesDirectory.appendingPathComponent("discover-catalog.json")
  }

  // MARK: Filter

  // Die Sprachen, die es im Katalog gibt, nach Anzahl der Decks.
  var languages: [String] {
    let counts = Dictionary(grouping: decks, by: \.language).mapValues(\.count)
    return counts.keys.sorted { (counts[$0] ?? 0, $1) > (counts[$1] ?? 0, $0) }
  }

  var filtered: [DiscoverDeck] {
    let words = search.lowercased().split(whereSeparator: \.isWhitespace)
    return decks.filter { deck in
      if let language, deck.language != language { return false }
      guard !words.isEmpty else { return true }
      let haystack = (
        [deck.title, deck.subtitle, deck.description, deck.languageName] + deck.tags
      ).joined(separator: " ").folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
      return words.allSatisfy {
        haystack.contains(String($0).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil))
      }
    }
  }

  // MARK: Laden

  func thumbnailURL(_ deck: DiscoverDeck) -> URL? {
    deck.thumbnail.map { DiscoverConfig.fileURL(base: base, deckID: deck.id, path: $0) }
  }

  func isInstalled(_ deck: DiscoverDeck) -> Bool {
    if app.decks.contains(where: { $0.id == deck.folderName }) { return true }
    guard justInstalled.contains(deck.id), let root = app.rootURL else { return false }
    return FileManager.default.fileExists(atPath: root.appendingPathComponent(deck.folderName).path)
  }

  func install(_ deck: DiscoverDeck) async {
    guard let root = app.rootURL, downloads[deck.id] == nil, !isInstalled(deck) else { return }
    downloads[deck.id] = 0
    defer { downloads[deck.id] = nil }
    do {
      try await DiscoverInstaller.install(deck, base: base, into: root, session: session) {
        [weak self] value in
        Task { @MainActor in
          if self?.downloads[deck.id] != nil { self?.downloads[deck.id] = value }
        }
      }
      justInstalled.insert(deck.id)
      Haptics.success()
      await app.refresh()
    } catch let error as DiscoverError {
      app.errorMessage = error.localizedDescription
    } catch {
      app.errorMessage =
        "„\(deck.title)“ konnte nicht geladen werden. Prüfe deine Internetverbindung und versuche es noch einmal."
    }
  }
}
