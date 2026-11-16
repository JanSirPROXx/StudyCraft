import Foundation

// Meldet Änderungen im Lernordner, damit Karten, die am Mac hinzukommen, sich ändern oder verschwinden,
// ohne Zutun erscheinen. Drei Wege ergänzen sich:
//  - `NSFilePresenter` meldet Änderungen, die iCloud oder das Dateisystem koordiniert einspielen,
//  - `NSMetadataQuery` meldet Änderungen an Dateien in iCloud Drive, die der Ordner-Zugriff erreicht,
//  - das regelmäßige Neu-Einlesen im AppModel fängt auf, was beide übersehen.
final class FolderWatcher: NSObject, NSFilePresenter, @unchecked Sendable {
  let presentedItemURL: URL?
  let presentedItemOperationQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    return queue
  }()

  private let onChange: @Sendable () -> Void
  private var query: NSMetadataQuery?
  private var observers: [NSObjectProtocol] = []

  init(root: URL, onChange: @escaping @Sendable () -> Void) {
    presentedItemURL = root
    self.onChange = onChange
    super.init()
  }

  @MainActor func start() {
    NSFileCoordinator.addFilePresenter(self)

    let query = NSMetadataQuery()
    query.searchScopes = [NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope]
    query.predicate = NSPredicate(format: "%K LIKE[c] '*.md'", NSMetadataItemFSNameKey)
    let notify: @Sendable (Notification) -> Void = { [onChange] _ in onChange() }
    observers = [
      NotificationCenter.default.addObserver(
        forName: .NSMetadataQueryDidUpdate, object: query, queue: .main, using: notify),
      NotificationCenter.default.addObserver(
        forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main, using: notify),
    ]
    query.start()
    self.query = query
  }

  @MainActor func stop() {
    NSFileCoordinator.removeFilePresenter(self)
    query?.stop()
    query = nil
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
    observers = []
  }

  // MARK: NSFilePresenter

  func presentedItemDidChange() { onChange() }
  func presentedSubitemDidAppear(at url: URL) { relevant(url) }
  func presentedSubitemDidChange(at url: URL) { relevant(url) }
  func presentedSubitem(at oldURL: URL, didMoveTo newURL: URL) { onChange() }
  func accommodatePresentedSubitemDeletion(
    at url: URL, completionHandler: @escaping @Sendable ((any Error)?) -> Void
  ) {
    completionHandler(nil)
    onChange()
  }

  // Die eigene Fortschrittsdatei zu schreiben soll kein Neu-Einlesen auslösen.
  private func relevant(_ url: URL) {
    if url.path.contains("/\(ProgressFiles.folderName)/"), url.lastPathComponent.hasPrefix("progress-"),
      url.lastPathComponent.contains(ownDeviceID)
    {
      return
    }
    onChange()
  }

  var ownDeviceID = "-"
}
