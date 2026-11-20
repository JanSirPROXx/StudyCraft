import Foundation

// Der Katalog der Decks, die man in „Entdecken“ laden kann. Er liegt als `catalog.json` zusammen mit den
// Decks selbst an einem festen Ort im Netz (siehe `DiscoverConfig`); jedes Deck ist ein Ordner mit
// Markdown-Dateien und Bildern, genau wie ein selbst angelegtes Deck.
struct DiscoverCatalog: Codable, Sendable {
  var version: Int
  var decks: [DiscoverDeck]
}

struct DiscoverDeck: Codable, Identifiable, Hashable, Sendable {
  var id: String  // Ordnername im Katalog, nur a–z, 0–9 und „-“
  var title: String
  var subtitle: String
  var description: String
  var language: String  // ISO-639-1, zum Beispiel „en“ oder „de“
  var tags: [String]
  var cardCount: Int
  var thumbnail: String?  // Pfad relativ zum Deck-Ordner im Katalog
  var folderName: String  // so heißt der Ordner im Lernordner des Nutzers
  var revision: Int
  var size: Int  // Bytes aller Dateien
  var files: [String]  // Pfade relativ zum Deck-Ordner; nur Markdown und Bilder

  // Alles, was aus dem Netz kommt, wird geprüft, bevor es auf die Platte darf: keine Pfade, die aus dem
  // Deck-Ordner ausbrechen, und nur Dateitypen, die die App ohnehin liest.
  var isSafe: Bool {
    guard Self.isSafeID(id), Self.isSafeName(folderName), !files.isEmpty else { return false }
    return files.allSatisfy(Self.isSafeFile) && (thumbnail.map(Self.isSafeFile) ?? true)
  }

  static let allowedExtensions: Set<String> = [
    "md", "markdown", "png", "jpg", "jpeg", "gif", "webp", "heic",
  ]

  private static func isSafeID(_ id: String) -> Bool {
    !id.isEmpty
      && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") && !$0.isUppercase }
  }

  private static func isSafeName(_ name: String) -> Bool {
    let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return !clean.isEmpty && clean == name && !name.contains("/") && !name.contains(":")
      && !name.hasPrefix(".") && name != ProgressFiles.folderName
  }

  private static func isSafeFile(_ path: String) -> Bool {
    guard !path.hasPrefix("/"), !path.contains("\\") else { return false }
    let parts = path.split(separator: "/", omittingEmptySubsequences: false)
    guard !parts.isEmpty,
      parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !$0.hasPrefix(".") })
    else { return false }
    return allowedExtensions.contains((path as NSString).pathExtension.lowercased())
  }

  // Sprachname in der Sprache der App, zum Beispiel „Englisch“.
  var languageName: String {
    Locale.current.localizedString(forLanguageCode: language)?.localizedCapitalized
      ?? language.uppercased()
  }
}

enum DiscoverConfig {
  // Die Decks liegen im öffentlichen Repository der App; die Nutzer bekommen davon nichts mit.
  static let defaultBase = URL(
    string: "https://raw.githubusercontent.com/JanSirPROXx/StudyCraft/main/Discover/")!

  static var baseURL: URL {
    #if DEBUG
      let arguments = CommandLine.arguments
      if let flag = arguments.firstIndex(of: "-StudyCraftDiscoverBase"), flag + 1 < arguments.count {
        let text = arguments[flag + 1]
        return text.hasSuffix("/") ? URL(string: text)! : URL(string: text + "/")!
      }
    #endif
    return defaultBase
  }

  static func catalogURL(base: URL) -> URL { base.appendingPathComponent("catalog.json") }

  static func fileURL(base: URL, deckID: String, path: String) -> URL {
    var url = base.appendingPathComponent("decks", isDirectory: true)
      .appendingPathComponent(deckID, isDirectory: true)
    for part in path.split(separator: "/") { url.appendPathComponent(String(part)) }
    return url
  }

  static func decode(_ data: Data) throws -> DiscoverCatalog {
    var catalog = try JSONDecoder().decode(DiscoverCatalog.self, from: data)
    catalog.decks = catalog.decks.filter(\.isSafe)
    return catalog
  }
}

enum DiscoverError: LocalizedError {
  case server(Int)
  case exists(String)

  var errorDescription: String? {
    switch self {
    case .server: "Der Server hat nicht geantwortet. Bitte versuche es später noch einmal."
    case .exists(let name): "In deinem Lernordner gibt es schon einen Ordner „\(name)“."
    }
  }
}

// Lädt ein Deck Datei für Datei in einen Zwischenordner und verschiebt ihn erst, wenn alles da ist.
// So bleibt nie ein halbes Deck im Lernordner liegen.
enum DiscoverInstaller {
  static let parallelDownloads = 6

  static func install(
    _ deck: DiscoverDeck, base: URL, into root: URL, session: URLSession = .shared,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws {
    let destination = root.appendingPathComponent(deck.folderName, isDirectory: true)
    if FileManager.default.fileExists(atPath: destination.path) {
      throw DiscoverError.exists(deck.folderName)
    }

    let staging = FileManager.default.temporaryDirectory
      .appendingPathComponent("discover-" + UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: staging) }

    let files = deck.files
    let folder = staging.appendingPathComponent("deck", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

    try await withThrowingTaskGroup(of: Void.self) { group in
      var next = 0
      var finished = 0
      func startNext(_ group: inout ThrowingTaskGroup<Void, Error>) {
        guard next < files.count else { return }
        let path = files[next]
        next += 1
        group.addTask {
          let url = DiscoverConfig.fileURL(base: base, deckID: deck.id, path: path)
          let (data, response) = try await session.data(from: url)
          if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw DiscoverError.server(http.statusCode)
          }
          let target = folder.appendingPathComponent(path)
          try FileManager.default.createDirectory(
            at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
          try data.write(to: target)
        }
      }
      for _ in 0..<min(parallelDownloads, files.count) { startNext(&group) }
      while try await group.next() != nil {
        finished += 1
        progress(Double(finished) / Double(files.count))
        startNext(&group)
      }
    }

    try FileIO.move(folder, to: destination)
  }
}
