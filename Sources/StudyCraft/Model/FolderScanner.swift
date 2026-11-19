import CryptoKit
import Foundation

struct CachedFile: Sendable {
  var modified: Date
  var size: Int
  var parsed: ParsedFile?  // nil: gelesen, aber keine Karten-Datei
}

struct ScannedLibrary: Sendable {
  var decks: [DeckNode]
  var cards: [String: Card]
  var imageIndex: [String: URL]
  var cache: [String: CachedFile]
  var signature: String
}

// Liest den Lernordner: jeder Unterordner mit Karten wird zum Deck, jede `.md`-Datei mit Kennung in der
// ersten Zeile liefert Karten. Bereits gelesene, unveränderte Dateien kommen aus dem Cache.
enum FolderScanner {
  private static let imageExtensions: Set<String> = [
    "png", "jpg", "jpeg", "gif", "heic", "heif", "webp", "tif", "tiff", "bmp",
  ]

  private struct Entry {
    var path: String
    var url: URL
    var modified: Date
    var size: Int
  }

  static func scan(root: URL, cache: [String: CachedFile]) -> ScannedLibrary {
    var entries: [Entry] = []
    var images: [String: URL] = [:]
    walk(root, relative: "", entries: &entries, images: &images)
    entries.sort { $0.path < $1.path }

    var newCache: [String: CachedFile] = [:]
    var cards: [String: Card] = [:]
    var signatureInput = ""

    for entry in entries {
      signatureInput += "\(entry.path)|\(entry.modified.timeIntervalSince1970)|\(entry.size)\n"
      let file: CachedFile
      if let cached = cache[entry.path], cached.modified == entry.modified, cached.size == entry.size {
        file = cached
      } else if let text = try? FileIO.readString(entry.url) {
        file = CachedFile(
          modified: entry.modified, size: entry.size, parsed: CardParser.parse(text))
      } else {
        // Nicht lesbar (zum Beispiel noch nicht aus iCloud geladen): nicht merken, beim nächsten Mal erneut versuchen.
        continue
      }
      newCache[entry.path] = file
      guard let parsed = file.parsed else { continue }

      let deckID = parentFolder(of: entry.path)
      let single = !parsed.isList && parsed.cards.count == 1
      var seen = Set<String>()
      for (index, card) in parsed.cards.enumerated() {
        var id = CardIdentity.id(file: entry.path, card: card, index: index, isSingle: single)
        var copy = 2
        while seen.contains(id) {  // zwei Karten mit gleicher Vorderseite in einer Datei
          id = CardIdentity.id(file: entry.path, card: card, index: index, isSingle: single) + "~\(copy)"
          copy += 1
        }
        seen.insert(id)
        cards[id] = Card(
          id: id, deckID: deckID, front: card.front, back: card.back, fileURL: entry.url,
          filePath: entry.path, order: index, chunk: card.chunk, hidden: card.hidden,
          isSingle: single)
      }
    }

    let digest = SHA256.hash(data: Data(signatureInput.utf8))
    let signature = digest.prefix(8).map { String(format: "%02x", $0) }.joined() + "-\(images.count)"
    return ScannedLibrary(
      decks: DeckTree.build(from: Array(cards.values)), cards: cards, imageIndex: images,
      cache: newCache, signature: signature)
  }

  private static func parentFolder(of path: String) -> String {
    guard let slash = path.lastIndex(of: "/") else { return "" }
    return String(path[..<slash])
  }

  private static func walk(
    _ directory: URL, relative: String, entries: inout [Entry], images: inout [String: URL]
  ) {
    let keys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey]
    let fm = FileManager.default
    let items = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys)) ?? []
    for item in items {
      var name = item.lastPathComponent
      var placeholder = false
      if name.hasPrefix("."), name.hasSuffix(".icloud") {
        // Eine Datei, die iCloud noch nicht auf das Gerät geladen hat.
        name = String(name.dropFirst().dropLast(7))
        placeholder = true
      } else if name.hasPrefix(".") {
        continue
      }
      let values = try? item.resourceValues(forKeys: Set(keys))
      let path = relative.isEmpty ? name : relative + "/" + name

      if values?.isDirectory == true {
        if name == ProgressFiles.folderName { continue }
        walk(item, relative: path, entries: &entries, images: &images)
        continue
      }

      let ext = (name as NSString).pathExtension.lowercased()
      let url = placeholder ? directory.appendingPathComponent(name) : item
      if ext == "md" || ext == "markdown" {
        if placeholder { try? fm.startDownloadingUbiquitousItem(at: url) }
        entries.append(
          Entry(
            path: path, url: url, modified: values?.contentModificationDate ?? .distantPast,
            size: values?.fileSize ?? 0))
      } else if imageExtensions.contains(ext) {
        images[name.lowercased()] = url
      }
    }
  }
}
