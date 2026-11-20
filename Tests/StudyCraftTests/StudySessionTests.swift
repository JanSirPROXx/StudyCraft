import XCTest

@testable import StudyCraft

@MainActor
final class StudySessionTests: XCTestCase {
  private let deckID = "SessionTestDeck"

  override func setUp() {
    super.setUp()
    UserDefaults.standard.removeObject(forKey: "studySession.v1.\(deckID)")
  }

  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: "studySession.v1.\(deckID)")
    super.tearDown()
  }

  private func deck(count: Int = 5) -> DeckNode {
    let cards = (0..<count).map { n in
      Card(
        id: "\(deckID)/c\(n)", deckID: deckID, front: "F\(n)", back: "B\(n)",
        fileURL: URL(fileURLWithPath: "/tmp/none.md"), filePath: "\(deckID)/none.md", order: n,
        chunk: n, hidden: false, isSingle: false)
    }
    return DeckNode(id: deckID, name: deckID, cards: cards, children: [])
  }

  func testRestartInNewModeShowsAllCardsAgain() {
    let model = AppModel()
    let session = StudySession(deck: deck(), mode: .new, model: model)
    while !session.isFinished { session.rate(.good) }
    XCTAssertTrue(session.isFinished)

    session.restart()
    XCTAssertFalse(session.isFinished)
    XCTAssertEqual(session.mode, .shuffle)
    XCTAssertEqual(session.total, 5)
    XCTAssertEqual(session.finished, 0)
  }

  func testRestartInShuffleModeShowsAllCardsAgain() {
    let model = AppModel()
    let session = StudySession(deck: deck(), mode: .shuffle, model: model)
    while !session.isFinished { session.rate(.good) }
    session.restart()
    XCTAssertFalse(session.isFinished)
    XCTAssertEqual(session.total, 5)
  }

  func testSessionResumesWhereItWasClosed() {
    let model = AppModel()
    let first = StudySession(deck: deck(), mode: .shuffle, model: model)
    first.rate(.good)
    first.rate(.again)
    first.rate(.easy)
    let answered = first.answered
    let finished = first.finished
    let remaining = first.remaining

    let second = StudySession(deck: deck(), mode: .shuffle, model: model)
    XCTAssertEqual(second.finished, finished)
    XCTAssertEqual(second.remaining, remaining)
    XCTAssertEqual(second.total, first.total)
    XCTAssertEqual(second.answered, answered)
    XCTAssertEqual(second.current?.id, first.current?.id)
  }

  func testFinishedSessionStartsFresh() {
    let model = AppModel()
    let first = StudySession(deck: deck(), mode: .shuffle, model: model)
    while !first.isFinished { first.rate(.good) }

    let second = StudySession(deck: deck(), mode: .shuffle, model: model)
    XCTAssertEqual(second.finished, 0)
    XCTAssertEqual(second.total, 5)
  }

  func testCardsAddedSinceLastTimeAreAppended() {
    let model = AppModel()
    let first = StudySession(deck: deck(count: 3), mode: .sorted, model: model)
    first.rate(.good)

    let second = StudySession(deck: deck(count: 5), mode: .sorted, model: model)
    XCTAssertEqual(second.total, 5)
    XCTAssertEqual(second.finished, 1)
  }
}
