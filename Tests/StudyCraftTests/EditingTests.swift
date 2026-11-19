import XCTest

@testable import StudyCraft

final class ShuffleTests: XCTestCase {
  func testEveryCardExactlyOnce() {
    let items = Array(0..<60)
    for _ in 0..<50 {
      XCTAssertEqual(SmartShuffle.order(items, avoiding: nil).sorted(), items)
    }
  }

  func testNeverStartsWithTheLastCard() {
    let items = Array(0..<5)
    for _ in 0..<300 {
      XCTAssertNotEqual(SmartShuffle.order(items, avoiding: 3).first, 3)
    }
  }

  func testSourceNeighboursAreSeparated() {
    let items = Array(0..<40)
    var clashes = 0
    var pairs = 0
    for _ in 0..<50 {
      let order = SmartShuffle.order(items, avoiding: nil)
      for (a, b) in zip(order, order.dropFirst()) {
        pairs += 1
        if abs(a - b) == 1 { clashes += 1 }
      }
    }
    // Reiner Zufall hätte bei 40 Karten rund 5 % Nachbarn aus der Datei; hier fast keine.
    XCTAssertLessThan(Double(clashes) / Double(pairs), 0.02)
  }

  func testSmallInputs() {
    XCTAssertEqual(SmartShuffle.order([Int](), avoiding: nil), [])
    XCTAssertEqual(SmartShuffle.order([1], avoiding: 1), [1])
    XCTAssertEqual(Set(SmartShuffle.order([1, 2], avoiding: 1)), [1, 2])
  }
}

final class SwipeRuleTests: XCTestCase {
  func testSlowDragStopsAtFirstLevelUntilHeld() {
    XCTAssertEqual(SwipeRule.rating(dx: 120, armed: true, strong: false, predicted: 130), .good)
    XCTAssertEqual(SwipeRule.rating(dx: 120, armed: true, strong: true, predicted: 130), .easy)
    XCTAssertEqual(SwipeRule.rating(dx: -120, armed: true, strong: false, predicted: -130), .hard)
    XCTAssertEqual(SwipeRule.rating(dx: -120, armed: true, strong: true, predicted: -130), .again)
  }

  func testShortDragSnapsBack() {
    XCTAssertNil(SwipeRule.rating(dx: 40, armed: false, strong: false, predicted: 60))
    XCTAssertNil(SwipeRule.rating(dx: -40, armed: false, strong: false, predicted: -60))
  }

  func testFastFlickCountsAsFirstLevel() {
    XCTAssertEqual(SwipeRule.rating(dx: 50, armed: false, strong: false, predicted: 500), .good)
    XCTAssertEqual(SwipeRule.rating(dx: -50, armed: false, strong: false, predicted: -500), .hard)
    // Eine Prognose in die Gegenrichtung ist kein Wisch.
    XCTAssertNil(SwipeRule.rating(dx: 50, armed: false, strong: false, predicted: -500))
  }
}

final class HiddenAndChunkTests: XCTestCase {
  func testHiddenMarkerIsRemovedAndKeepsIdentity() throws {
    let plain = try XCTUnwrap(CardParser.parse("@studyCraft_List\n\nFrage\n---\nAntwort\n"))
    let hidden = try XCTUnwrap(
      CardParser.parse("@studyCraft_List\n\n<!-- hidden -->\nFrage\n---\nAntwort\n"))
    XCTAssertEqual(hidden.cards.first?.front, "Frage")
    XCTAssertEqual(hidden.cards.first?.hidden, true)
    XCTAssertEqual(plain.cards.first?.hidden, false)
    XCTAssertEqual(
      CardIdentity.id(file: "a.md", card: plain.cards[0], index: 0, isSingle: false),
      CardIdentity.id(file: "a.md", card: hidden.cards[0], index: 0, isSingle: false))
  }

  func testChunkIndexFollowsSeparators() throws {
    let file = try XCTUnwrap(
      CardParser.parse("@studyCraft_List\nA\n---\n1\n===\n===\nB\n---\n2\n"))
    XCTAssertEqual(file.cards.map(\.chunk), [0, 2])
  }

  func testLayoutRoundTripsExactly() throws {
    let text = "@studyCraft_List\n\n# A\n---\n```\n===\n```\n===\nB\n---\nC\n"
    XCTAssertEqual(try XCTUnwrap(CardParser.layout(text)).text, text)
  }
}

final class CardStoreTests: XCTestCase {
  var folder: URL!

  override func setUpWithError() throws {
    folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: folder)
  }

  private func write(_ name: String, _ text: String) throws -> URL {
    let url = folder.appendingPathComponent(name)
    try text.write(to: url, atomically: true, encoding: .utf8)
    return url
  }

  private func cards(_ url: URL) throws -> [Card] {
    let text = try String(contentsOf: url, encoding: .utf8)
    let parsed = try XCTUnwrap(CardParser.parse(text))
    let single = !parsed.isList && parsed.cards.count == 1
    return parsed.cards.enumerated().map { index, card in
      Card(
        id: "\(url.lastPathComponent)#\(index)", deckID: "", front: card.front, back: card.back,
        fileURL: url, filePath: url.lastPathComponent, order: index, chunk: card.chunk,
        hidden: card.hidden, isSingle: single)
    }
  }

  func testEditKeepsOtherCardsUntouched() throws {
    let url = try write("l.md", "@studyCraft_List\n\nA\n---\n1\n===\nB\n---\n2\n===\nC\n---\n3\n")
    let second = try cards(url)[1]
    try CardStore.update(card: second, front: "B neu", back: "2 neu\n\n- x")
    XCTAssertEqual(
      try String(contentsOf: url, encoding: .utf8),
      "@studyCraft_List\n\nA\n---\n1\n===\nB neu\n---\n2 neu\n\n- x\n===\nC\n---\n3\n")
  }

  func testEditRejectsSeparatorsInText() throws {
    let url = try write("l.md", "@studyCraft_List\n\nA\n---\n1\n")
    let card = try cards(url)[0]
    XCTAssertThrowsError(try CardStore.update(card: card, front: "A", back: "x\n===\ny"))
    XCTAssertThrowsError(try CardStore.update(card: card, front: "", back: "x"))
    XCTAssertEqual(
      try String(contentsOf: url, encoding: .utf8), "@studyCraft_List\n\nA\n---\n1\n")
  }

  func testEditDetectsExternalChange() throws {
    let url = try write("l.md", "@studyCraft_List\n\nA\n---\n1\n")
    let card = try cards(url)[0]
    try "@studyCraft_List\n\nGeändert\n---\n1\n".write(to: url, atomically: true, encoding: .utf8)
    XCTAssertThrowsError(try CardStore.update(card: card, front: "A2", back: "1"))
  }

  func testHideAndUnhide() throws {
    let url = try write("l.md", "@studyCraft_List\n\nA\n---\n1\n===\nB\n---\n2\n")
    try CardStore.setHidden(true, card: try cards(url)[1])
    XCTAssertEqual(
      try String(contentsOf: url, encoding: .utf8),
      "@studyCraft_List\n\nA\n---\n1\n===\n<!-- hidden -->\nB\n---\n2\n")
    XCTAssertEqual(try cards(url).map(\.hidden), [false, true])
    try CardStore.setHidden(false, card: try cards(url)[1])
    XCTAssertEqual(
      try String(contentsOf: url, encoding: .utf8),
      "@studyCraft_List\n\nA\n---\n1\n===\nB\n---\n2\n")
  }

  func testEditKeepsHiddenState() throws {
    let url = try write("l.md", "@studyCraft_List\n\n<!-- hidden -->\nA\n---\n1\n")
    try CardStore.update(card: try cards(url)[0], front: "A2", back: "1")
    XCTAssertEqual(try cards(url).map(\.hidden), [true])
    XCTAssertEqual(try cards(url).map(\.front), ["A2"])
  }

  func testRemoveFromListAndFile() throws {
    let url = try write("l.md", "@studyCraft_List\n\nA\n---\n1\n===\nB\n---\n2\n===\nC\n---\n3\n")
    try CardStore.remove(card: try cards(url)[0])
    XCTAssertEqual(try cards(url).map(\.front), ["B", "C"])
    try CardStore.remove(card: try cards(url)[1])
    XCTAssertEqual(try cards(url).map(\.front), ["B"])
    try CardStore.remove(card: try cards(url)[0])
    XCTAssertEqual(try cards(url).count, 0)  // die Datei bleibt, nur ohne Karten
    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

    let single = try write("s.md", "@studyCraft\nF\n---\nB\n")
    try CardStore.remove(card: try cards(single)[0])
    XCTAssertFalse(FileManager.default.fileExists(atPath: single.path))
  }

  func testAppendAndCreate() throws {
    let url = try write("l.md", "@studyCraft_List\n\nA\n---\n1\n")
    try CardStore.append(to: url, front: "B", back: "2")
    try CardStore.append(to: url, front: "C", back: "3")
    XCTAssertEqual(
      try String(contentsOf: url, encoding: .utf8),
      "@studyCraft_List\n\nA\n---\n1\n===\nB\n---\n2\n===\nC\n---\n3\n")

    let empty = try write("e.md", "@studyCraft_List\n")
    try CardStore.append(to: empty, front: "X", back: "Y")
    XCTAssertEqual(try cards(empty).map(\.front), ["X"])

    let created = try CardStore.createList(in: folder, front: "N", back: "M")
    XCTAssertEqual(created.lastPathComponent, "Karten.md")
    let second = try CardStore.createList(in: folder, front: "N2", back: "M2")
    XCTAssertEqual(second.lastPathComponent, "Karten 2.md")
    XCTAssertEqual(try cards(created).map(\.back), ["M"])
  }
}

final class UndoAndMigrationTests: XCTestCase {
  func progress(_ interval: Int, at time: TimeInterval) -> CardProgress {
    var p = CardProgress(startingEase: 2.5, now: Date(timeIntervalSince1970: time))
    p.queue = .review
    p.interval = interval
    return p
  }

  func testRevertRestoresCardAndDayLog() {
    var book = ProgressBook(deviceID: "A", deviceName: "iPhone")
    let old = progress(3, at: 100)
    book.record(cardID: "c", progress: old, day: 7, log: DayLog(reviews: 1, seconds: 4))
    book.record(cardID: "c", progress: progress(8, at: 200), day: 7, log: DayLog(reviews: 1, seconds: 6))
    book.revert(cardID: "c", to: old, day: 7, log: DayLog(reviews: 1, seconds: 6))
    XCTAssertEqual(book.state(for: "c")?.interval, 3)
    XCTAssertEqual(book.days[7]?.reviews, 1)
    XCTAssertEqual(book.days[7]?.seconds, 4)
    XCTAssertEqual(book.own.days["7"]?.reviews, 1)

    book.revert(cardID: "c", to: nil, day: 7, log: DayLog(reviews: 1, seconds: 4))
    XCTAssertNil(book.state(for: "c"))
    XCTAssertEqual(book.days[7]?.reviews, 0)
  }

  func testMigrateMovesProgress() {
    var book = ProgressBook(deviceID: "A", deviceName: "iPhone")
    var other = DeviceProgress(deviceID: "B", deviceName: "iPad")
    other.cards["Alt/x.md"] = progress(5, at: 10)
    book.setRemotes([other])
    book.record(cardID: "Alt/y.md", progress: progress(2, at: 20), day: 1, log: DayLog(reviews: 1))
    book.migrate(["Alt/x.md": "Neu/x.md", "Alt/y.md": "Neu/y.md"])
    XCTAssertEqual(book.state(for: "Neu/x.md")?.interval, 5)  // kam von einem anderen Gerät
    XCTAssertEqual(book.state(for: "Neu/y.md")?.interval, 2)
    XCTAssertNil(book.own.cards["Alt/y.md"])
    XCTAssertEqual(book.own.cards["Neu/x.md"]?.interval, 5)
  }
}
