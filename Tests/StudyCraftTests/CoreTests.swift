import XCTest

@testable import StudyCraft

final class CardParserTests: XCTestCase {
  func testRequiresIdentifierOnFirstLine() {
    XCTAssertNil(CardParser.parse("Frage\n---\nAntwort"))
    XCTAssertNil(CardParser.parse("\n@studyCraft\nFrage\n---\nAntwort"))
    XCTAssertNotNil(CardParser.parse("@studyCraft\nFrage\n---\nAntwort"))
    XCTAssertNotNil(CardParser.parse("@STUDYCRAFT_LIST\nFrage\n---\nAntwort"))
  }

  func testSingleCard() throws {
    let file = try XCTUnwrap(CardParser.parse("@studyCraft\n\n# Frage\n\n---\n\nAntwort **fett**\n"))
    XCTAssertFalse(file.isList)
    XCTAssertEqual(file.cards, [ParsedCard(front: "# Frage", back: "Antwort **fett**")])
  }

  func testListSplitsOnDoubleRule() throws {
    let text = "@studyCraft_List\nA1\n---\nB1\n===\nA2\n---\nB2\n===\nA3\n---\nB3"
    let file = try XCTUnwrap(CardParser.parse(text))
    XCTAssertTrue(file.isList)
    XCTAssertEqual(file.cards.map(\.front), ["A1", "A2", "A3"])
    XCTAssertEqual(file.cards.map(\.back), ["B1", "B2", "B3"])
  }

  func testRulesInsideCodeFencesAreContent() throws {
    let text = "@studyCraft_List\nFrage\n```\n---\n===\n```\n---\nAntwort"
    let file = try XCTUnwrap(CardParser.parse(text))
    XCTAssertEqual(file.cards.count, 1)
    XCTAssertEqual(file.cards[0].front, "Frage\n```\n---\n===\n```")
  }

  func testSecondRuleInBackStaysInBack() throws {
    let file = try XCTUnwrap(CardParser.parse("@studyCraft\nF\n---\nB1\n---\nB2"))
    XCTAssertEqual(file.cards[0].back, "B1\n---\nB2")
  }

  func testCardsWithoutBackOrFrontAreSkipped() throws {
    let file = try XCTUnwrap(CardParser.parse("@studyCraft_List\nNur vorne\n===\nF\n---\nB\n===\n---\nNur hinten"))
    XCTAssertEqual(file.cards, [ParsedCard(front: "F", back: "B", chunk: 1)])
  }

  func testWindowsLineEndingsAndBOM() throws {
    let file = try XCTUnwrap(CardParser.parse("\u{FEFF}@studyCraft\r\nF\r\n---\r\nB\r\n"))
    XCTAssertEqual(file.cards, [ParsedCard(front: "F", back: "B")])
  }

  func testCardIdentity() {
    let a = ParsedCard(front: "Was  ist\nX?", back: "1")
    let b = ParsedCard(front: "Was ist X?", back: "andere Antwort")
    XCTAssertEqual(CardIdentity.id(file: "a.md", card: a, index: 0, isSingle: true), "a.md")
    // Whitespace und die Rückseite ändern die Identität nicht, Reihenfolge ebenfalls nicht.
    XCTAssertEqual(
      CardIdentity.id(file: "a.md", card: a, index: 0, isSingle: false),
      CardIdentity.id(file: "a.md", card: b, index: 5, isSingle: false))
  }
}

final class MarkdownParserTests: XCTestCase {
  func testBlocks() {
    let blocks = MarkdownParser.parse(
      """
      # Titel
      Text **fett**

      - eins
        - zwei
      - [x] fertig
      1. erst

      ```swift
      let a = 1
      ```
      > Zitat
      """)
    XCTAssertEqual(
      blocks,
      [
        .heading(level: 1, text: "Titel"),
        .paragraph("Text **fett**"),
        .listItem(depth: 0, marker: "•", text: "eins"),
        .listItem(depth: 1, marker: "•", text: "zwei"),
        .listItem(depth: 0, marker: "☑", text: "fertig"),
        .listItem(depth: 0, marker: "1.", text: "erst"),
        .code(language: "swift", text: "let a = 1"),
        .quote("Zitat"),
      ])
  }

  func testImages() {
    XCTAssertEqual(
      MarkdownParser.parse("Vorher ![Alt](bilder/a%20b.png \"Titel\") nachher"),
      [
        .paragraph("Vorher"), .image(alt: "Alt", path: "bilder/a%20b.png"),
        .paragraph("nachher"),
      ])
    XCTAssertEqual(
      MarkdownParser.parse("![[foto.jpg|300]]"), [.image(alt: "", path: "foto.jpg")])
  }

  func testTable() {
    XCTAssertEqual(
      MarkdownParser.parse("| A | B |\n|---|---|\n| 1 | 2 |"),
      [.table(header: ["A", "B"], rows: [["1", "2"]])])
  }

  func testCommentsAreRemoved() {
    XCTAssertEqual(MarkdownParser.parse("a <!-- weg --> b"), [.paragraph("a  b")])
  }
}

final class SchedulerTests: XCTestCase {
  let scheduler = Scheduler()
  let now = Date(timeIntervalSince1970: 1_800_000_000)

  func seconds(_ p: CardProgress?, _ rating: Rating) -> TimeInterval {
    scheduler.intervals(for: p, now: now)[rating]!
  }

  func testNewCardIntervals() {
    XCTAssertEqual(seconds(nil, .again), 60)
    XCTAssertEqual(seconds(nil, .hard), 330)
    XCTAssertEqual(seconds(nil, .good), 600)
    XCTAssertEqual(seconds(nil, .easy), 4 * 86400)
    XCTAssertEqual(IntervalFormat.short(seconds(nil, .again)), "< 1 Min")
    XCTAssertEqual(IntervalFormat.short(seconds(nil, .hard)), "6 Min")
    XCTAssertEqual(IntervalFormat.short(seconds(nil, .good)), "10 Min")
    XCTAssertEqual(IntervalFormat.short(seconds(nil, .easy)), "4 Tage")
  }

  func testGraduationAfterLastLearningStep() {
    let step1 = scheduler.apply(nil, rating: .good, now: now)
    XCTAssertEqual(step1.queue, .learning)
    XCTAssertEqual(step1.step, 1)
    let graduated = scheduler.apply(step1, rating: .good, now: now.addingTimeInterval(600))
    XCTAssertEqual(graduated.queue, .review)
    XCTAssertEqual(graduated.interval, 1)
    XCTAssertEqual(IntervalFormat.short(seconds(step1, .good)), "1 Tag")
  }

  func testReviewIntervalsGrowWithEase() {
    var card = CardProgress(startingEase: 2.5, now: now)
    card.queue = .review
    card.interval = 10
    card.due = StudyClock.startOfDay(StudyClock.dayIndex(for: now))
    let hard = scheduler.apply(card, rating: .hard, now: now)
    let good = scheduler.apply(card, rating: .good, now: now)
    let easy = scheduler.apply(card, rating: .easy, now: now)
    XCTAssertEqual(hard.interval, 12)
    XCTAssertEqual(good.interval, 25)
    XCTAssertEqual(easy.interval, 32)
    XCTAssertEqual(hard.ease, 2.35, accuracy: 0.001)
    XCTAssertEqual(good.ease, 2.5, accuracy: 0.001)
    XCTAssertEqual(easy.ease, 2.65, accuracy: 0.001)
  }

  func testLapseGoesToRelearningAndLowersEase() {
    var card = CardProgress(startingEase: 1.35, now: now)
    card.queue = .review
    card.interval = 30
    card.due = StudyClock.startOfDay(StudyClock.dayIndex(for: now))
    let lapsed = scheduler.apply(card, rating: .again, now: now)
    XCTAssertEqual(lapsed.queue, .relearning)
    XCTAssertEqual(lapsed.lapses, 1)
    XCTAssertEqual(lapsed.ease, 1.3, accuracy: 0.001)  // nie unter 130 %
    XCTAssertEqual(lapsed.due.timeIntervalSince(now), 600, accuracy: 1)
    let back = scheduler.apply(lapsed, rating: .good, now: now.addingTimeInterval(600))
    XCTAssertEqual(back.queue, .review)
    XCTAssertEqual(back.interval, 1)
  }

  func testOverdueCardsGetCredit() {
    var card = CardProgress(startingEase: 2.5, now: now)
    card.queue = .review
    card.interval = 10
    card.due = StudyClock.startOfDay(StudyClock.dayIndex(for: now) - 4)
    XCTAssertEqual(scheduler.apply(card, rating: .good, now: now).interval, 30)  // (10 + 4/2) * 2.5
  }

  func testIntervalLabels() {
    XCTAssertEqual(IntervalFormat.short(86400), "1 Tag")
    XCTAssertEqual(IntervalFormat.short(40 * 86400), "1,3 Mon.")
    XCTAssertEqual(IntervalFormat.short(2 * 3600), "2 Std")
    XCTAssertEqual(IntervalFormat.short(400 * 86400), "1,1 J.")
  }

  func testStudyDayRollsOverAtFourAM() {
    let zone = TimeZone(identifier: "Europe/Zurich")!
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    let late = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 2))!
    let morning = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 5))!
    XCTAssertEqual(
      StudyClock.dayIndex(for: late, timeZone: zone) + 1, StudyClock.dayIndex(for: morning, timeZone: zone))
    let start = StudyClock.startOfDay(StudyClock.dayIndex(for: morning, timeZone: zone), timeZone: zone)
    XCTAssertEqual(calendar.component(.hour, from: start), 4)
    XCTAssertEqual(StudyClock.dayIndex(for: start, timeZone: zone), StudyClock.dayIndex(for: morning, timeZone: zone))
  }
}

final class ProgressMergeTests: XCTestCase {
  func state(_ interval: Int, at time: TimeInterval) -> CardProgress {
    var p = CardProgress(startingEase: 2.5, now: Date(timeIntervalSince1970: time))
    p.queue = .review
    p.interval = interval
    return p
  }

  func testNewestAnswerWinsAcrossDevices() {
    var book = ProgressBook(deviceID: "A", deviceName: "iPhone")
    var other = DeviceProgress(deviceID: "B", deviceName: "iPad")
    other.cards["x"] = state(7, at: 200)
    other.cards["y"] = state(3, at: 50)
    other.days["100"] = DayLog(reviews: 5)
    book.setRemotes([other])
    book.record(cardID: "y", progress: state(9, at: 100), day: 100, log: DayLog(reviews: 2))
    XCTAssertEqual(book.state(for: "x")?.interval, 7)
    XCTAssertEqual(book.state(for: "y")?.interval, 9)
    XCTAssertEqual(book.days[100]?.reviews, 7)

    // Nach dem Neuaufbau (zum Beispiel beim nächsten Einlesen) gilt dasselbe.
    book.setRemotes([other])
    XCTAssertEqual(book.state(for: "y")?.interval, 9)
    XCTAssertEqual(book.days[100]?.reviews, 7)
  }

  func testOwnFileIsNotCountedTwice() {
    var book = ProgressBook(deviceID: "A", deviceName: "iPhone")
    var file = DeviceProgress(deviceID: "A", deviceName: "iPhone")
    file.days["5"] = DayLog(reviews: 3)
    book.adopt(own: file)
    book.setRemotes([file])  // dieselbe Datei als "fremde" Datei
    XCTAssertEqual(book.days[5]?.reviews, 3)
  }

  func testFilesRoundTrip() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    var mine = DeviceProgress(deviceID: "A", deviceName: "iPhone")
    mine.cards["c"] = state(4, at: 1_700_000_000)
    var theirs = DeviceProgress(deviceID: "B", deviceName: "Mac")
    theirs.days["9"] = DayLog(reviews: 1)
    try ProgressFiles.write(mine, root: root)
    try ProgressFiles.write(theirs, root: root)
    let loaded = ProgressFiles.loadAll(root: root, ownID: "A")
    XCTAssertEqual(loaded.own?.cards["c"]?.interval, 4)
    XCTAssertEqual(loaded.remotes.map(\.deviceID), ["B"])
  }
}

final class ScannerTests: XCTestCase {
  func testDecksFollowFolders() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let fm = FileManager.default
    try fm.createDirectory(at: root.appendingPathComponent("Bio/Zelle"), withIntermediateDirectories: true)
    try fm.createDirectory(at: root.appendingPathComponent("Leer"), withIntermediateDirectories: true)
    try fm.createDirectory(at: root.appendingPathComponent("_StudyCraft"), withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }
    try "@studyCraft_List\nA\n---\nB\n===\nC\n---\nD".write(
      to: root.appendingPathComponent("Bio/Zelle/a.md"), atomically: true, encoding: .utf8)
    try "@studyCraft\nF\n---\nB".write(
      to: root.appendingPathComponent("Bio/b.md"), atomically: true, encoding: .utf8)
    try "Keine Karte".write(
      to: root.appendingPathComponent("Bio/notiz.md"), atomically: true, encoding: .utf8)
    try "@studyCraft\nLose\n---\nKarte".write(
      to: root.appendingPathComponent("lose.md"), atomically: true, encoding: .utf8)

    let library = FolderScanner.scan(root: root, cache: [:])
    XCTAssertEqual(library.cards.count, 4)
    XCTAssertEqual(library.decks.map(\.name), ["Bio", "Allgemein"])
    let bio = library.decks[0]
    XCTAssertEqual(bio.cardCount, 3)
    XCTAssertEqual(bio.children.map(\.name), ["Zelle"])
    XCTAssertEqual(bio.cards.map(\.id), ["Bio/b.md"])

    // Unverändert: gleicher Fingerabdruck, Cache wird genutzt.
    let again = FolderScanner.scan(root: root, cache: library.cache)
    XCTAssertEqual(again.signature, library.signature)
    try "@studyCraft\nF\n---\nB2".write(
      to: root.appendingPathComponent("Bio/b.md"), atomically: true, encoding: .utf8)
    XCTAssertNotEqual(FolderScanner.scan(root: root, cache: library.cache).signature, library.signature)
  }
}
