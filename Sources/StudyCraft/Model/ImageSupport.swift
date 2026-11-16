import ImageIO
import UIKit

// Findet die Datei zu einem Bildverweis in einer Karte: relativ zur Markdown-Datei, relativ zum
// Lernordner, oder (wie in Obsidian) allein über den Dateinamen irgendwo im Lernordner.
struct ImageResolver: Sendable {
  var directory: URL?
  var root: URL?
  var index: [String: URL]

  static let empty = ImageResolver(directory: nil, root: nil, index: [:])

  func resolve(_ reference: String) -> URL? {
    var path = reference.trimmingCharacters(in: .whitespaces).removingPercentEncoding ?? reference
    if path.hasPrefix("./") { path.removeFirst(2) }
    let fm = FileManager.default
    for base in [directory, root] {
      guard let base else { continue }
      let candidate = base.appendingPathComponent(path)
      if fm.fileExists(atPath: candidate.path) { return candidate }
      // Noch nicht aus iCloud geladen: Der Platzhalter liegt unter dem Namen ".name.icloud".
      let placeholder = candidate.deletingLastPathComponent()
        .appendingPathComponent("." + candidate.lastPathComponent + ".icloud")
      if fm.fileExists(atPath: placeholder.path) { return candidate }
    }
    let name = (path as NSString).lastPathComponent.lowercased()
    return index[name]
  }
}

enum ImageLoader {
  private static let cache = NSCache<NSString, UIImage>()

  // Liest das Bild koordiniert (iCloud lädt es dabei nach) und verkleinert es auf Bildschirmgröße.
  static func load(_ url: URL) async -> UIImage? {
    let key = url.path as NSString
    if let cached = cache.object(forKey: key) { return cached }
    let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
      try? FileManager.default.startDownloadingUbiquitousItem(at: url)
      guard let data = try? FileIO.readData(url),
        let source = CGImageSourceCreateWithData(data as CFData, nil)
      else { return nil }
      let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: 2000,
      ]
      guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
        return nil
      }
      return UIImage(cgImage: cg)
    }.value
    if let image { cache.setObject(image, forKey: key) }
    return image
  }

  static func clear() { cache.removeAllObjects() }
}
