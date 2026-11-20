import XCTest

@testable import StudyCraft

final class DiscoverCatalogTests: XCTestCase {
  private func deckJSON(
    id: String = "demo", folder: String = "Demo", files: [String] = ["Karten.md"], thumbnail: String? = nil
  ) -> String {
    let list = files.map { "\"\($0)\"" }.joined(separator: ",")
    let thumb = thumbnail.map { "\"\($0)\"" } ?? "null"
    return """
      {"id":"\(id)","title":"Demo","subtitle":"s","description":"d","language":"en","tags":["a"],
       "cardCount":2,"thumbnail":\(thumb),"folderName":"\(folder)","revision":1,"size":10,"files":[\(list)]}
      """
  }

  private func catalog(_ decks: [String]) -> Data {
    Data("{\"version\":1,\"decks\":[\(decks.joined(separator: ","))]}".utf8)
  }

  func testDecodesAValidCatalog() throws {
    let result = try DiscoverConfig.decode(catalog([deckJSON(thumbnail: "thumbnail.jpg")]))
    XCTAssertEqual(result.decks.count, 1)
    XCTAssertEqual(result.decks[0].languageName.isEmpty, false)
  }

  func testRejectsDecksThatWouldEscapeTheirFolder() throws {
    let bad = [
      deckJSON(id: "a", files: ["../../etc/passwd.md"]),
      deckJSON(id: "b", files: ["/absolute.md"]),
      deckJSON(id: "c", files: ["ok/../../x.md"]),
      deckJSON(id: "d", files: [".hidden.md"]),
      deckJSON(id: "e", files: ["script.sh"]),
      deckJSON(id: "f", files: ["Karten.md"], thumbnail: "../t.jpg"),
      deckJSON(id: "g", folder: "../Evil"),
      deckJSON(id: "h", folder: "a/b"),
      deckJSON(id: "i", folder: ".hidden"),
      deckJSON(id: "j", folder: "_StudyCraft"),
      deckJSON(id: "UPPER", folder: "Ok"),
      deckJSON(id: "has space", folder: "Ok"),
      deckJSON(id: "k", files: []),
    ]
    let good = deckJSON(id: "good", files: ["Europe/Karten.md", "Maps/map-ch.png"])
    let result = try DiscoverConfig.decode(catalog(bad + [good]))
    XCTAssertEqual(result.decks.map(\.id), ["good"])
  }

  func testFileURLEscapesSpacesAndUnicode() {
    let base = URL(string: "https://example.com/Discover/")!
    let url = DiscoverConfig.fileURL(base: base, deckID: "demo", path: "Level 1 – Easy/Frage ü.md")
    XCTAssertEqual(
      url.absoluteString,
      "https://example.com/Discover/decks/demo/Level%201%20%E2%80%93%20Easy/Frage%20%C3%BC.md")
  }
}

final class DiscoverInstallerTests: XCTestCase {
  private var base: URL!
  private var root: URL!

  override func setUpWithError() throws {
    let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    base = temp.appendingPathComponent("Discover", isDirectory: true)
    root = temp.appendingPathComponent("Lernordner", isDirectory: true)
    let deck = base.appendingPathComponent("decks/demo", isDirectory: true)
    try FileManager.default.createDirectory(
      at: deck.appendingPathComponent("Europe"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try "@studyCraft_List\n\nFrage\n---\nAntwort".write(
      to: deck.appendingPathComponent("Europe/Karten.md"), atomically: true, encoding: .utf8)
    try Data([1, 2, 3]).write(to: deck.appendingPathComponent("bild.png"))
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: base.deletingLastPathComponent())
  }

  private func deck(files: [String]) -> DiscoverDeck {
    DiscoverDeck(
      id: "demo", title: "Demo", subtitle: "", description: "", language: "en", tags: [],
      cardCount: 1, thumbnail: nil, folderName: "Demo Deck", revision: 1, size: 0, files: files)
  }

  func testDownloadsAllFilesIntoTheStudyFolder() async throws {
    let progress = ProgressLog()
    try await DiscoverInstaller.install(
      deck(files: ["Europe/Karten.md", "bild.png"]), base: base, into: root
    ) { value in progress.add(value) }

    let installed = root.appendingPathComponent("Demo Deck")
    XCTAssertTrue(FileManager.default.fileExists(atPath: installed.appendingPathComponent("Europe/Karten.md").path))
    XCTAssertEqual(try Data(contentsOf: installed.appendingPathComponent("bild.png")), Data([1, 2, 3]))
    XCTAssertEqual(progress.values.last, 1)

    // The installed deck is a normal deck for the scanner.
    let library = FolderScanner.scan(root: root, cache: [:])
    XCTAssertEqual(library.cards.count, 1)
    XCTAssertEqual(library.decks.first?.name, "Demo Deck")
  }

  func testMissingFileLeavesNothingBehind() async throws {
    do {
      try await DiscoverInstaller.install(
        deck(files: ["Europe/Karten.md", "fehlt.png"]), base: base, into: root
      ) { _ in }
      XCTFail("expected an error")
    } catch {}
    XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Demo Deck").path))
  }

  func testRefusesToOverwriteAnExistingFolder() async throws {
    try FileManager.default.createDirectory(
      at: root.appendingPathComponent("Demo Deck"), withIntermediateDirectories: true)
    do {
      try await DiscoverInstaller.install(deck(files: ["bild.png"]), base: base, into: root) { _ in }
      XCTFail("expected an error")
    } catch let error as DiscoverError {
      guard case .exists = error else { return XCTFail("wrong error \(error)") }
    }
  }
}

private final class ProgressLog: @unchecked Sendable {
  private let lock = NSLock()
  private var storage: [Double] = []
  func add(_ value: Double) {
    lock.lock()
    storage.append(value)
    lock.unlock()
  }
  var values: [Double] {
    lock.lock()
    defer { lock.unlock() }
    return storage
  }
}

@MainActor
final class DiscoverFilterTests: XCTestCase {
  private func model() throws -> DiscoverModel {
    let json = """
      {"version":1,"decks":[
       {"id":"capitals","title":"Capitals of the World","subtitle":"Learn capitals","description":"Geography quiz","language":"en","tags":["Geography"],"cardCount":194,"thumbnail":null,"folderName":"Capitals","revision":1,"size":1,"files":["a.md"]},
       {"id":"schweiz","title":"Schweiz","subtitle":"Kantone und Hauptorte","description":"Allgemeinwissen","language":"de","tags":["Schweiz"],"cardCount":300,"thumbnail":null,"folderName":"Schweiz","revision":1,"size":1,"files":["a.md"]}]}
      """
    let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    try Data(json.utf8).write(to: temp.appendingPathComponent("catalog.json"))
    return DiscoverModel(app: AppModel(), base: temp)
  }

  func testFiltersByLanguageAndSearch() async throws {
    let discover = try model()
    await discover.load()
    XCTAssertEqual(discover.decks.count, 2)
    XCTAssertEqual(Set(discover.languages), ["en", "de"])

    discover.language = "de"
    XCTAssertEqual(discover.filtered.map(\.id), ["schweiz"])
    discover.language = nil

    discover.search = "geography"
    XCTAssertEqual(discover.filtered.map(\.id), ["capitals"])
    discover.search = "kantone"
    XCTAssertEqual(discover.filtered.map(\.id), ["schweiz"])
    discover.search = "hauptorte schweiz"
    XCTAssertEqual(discover.filtered.map(\.id), ["schweiz"])
    discover.search = "xyz"
    XCTAssertTrue(discover.filtered.isEmpty)
  }
}
