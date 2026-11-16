import Foundation

// Die Blöcke, aus denen eine Kartenseite besteht. Inline-Formatierung (fett, kursiv, `Code`, Links)
// bleibt im Text und wird beim Anzeigen von `AttributedString` übernommen.
enum MDBlock: Equatable, Sendable {
  case heading(level: Int, text: String)
  case paragraph(String)
  case listItem(depth: Int, marker: String, text: String)
  case code(language: String?, text: String)
  case quote(String)
  case image(alt: String, path: String)
  case rule
  case table(header: [String], rows: [[String]])
}

enum MarkdownParser {
  static func parse(_ source: String) -> [MDBlock] {
    let lines = stripComments(source).components(separatedBy: "\n")
    var blocks: [MDBlock] = []
    var paragraph: [String] = []
    var indents: [Int] = []  // Einrückungsebenen der aktuellen Liste
    var i = 0

    func flush() {
      if !paragraph.isEmpty {
        blocks += splitImages(paragraph.joined(separator: "\n"))
        paragraph = []
      }
    }

    while i < lines.count {
      let line = lines[i].replacingOccurrences(of: "\t", with: "    ")
      let trimmed = line.trimmingCharacters(in: .whitespaces)

      if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
        flush()
        indents = []
        let fence = String(trimmed.prefix(3))
        let language = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
        var code: [String] = []
        i += 1
        while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
          code.append(lines[i])
          i += 1
        }
        i += 1
        blocks.append(.code(language: language.isEmpty ? nil : language, text: code.joined(separator: "\n")))
        continue
      }
      if trimmed.isEmpty {
        flush()
        indents = []
        i += 1
        continue
      }
      if let heading = heading(trimmed) {
        flush()
        indents = []
        blocks.append(heading)
        i += 1
        continue
      }
      if isRule(trimmed) {
        flush()
        indents = []
        blocks.append(.rule)
        i += 1
        continue
      }
      if trimmed.hasPrefix(">") {
        flush()
        indents = []
        var quote: [String] = []
        while i < lines.count {
          let t = lines[i].trimmingCharacters(in: .whitespaces)
          guard t.hasPrefix(">") else { break }
          var content = String(t.dropFirst())
          if content.hasPrefix(" ") { content.removeFirst() }
          quote.append(content)
          i += 1
        }
        blocks.append(.quote(quote.joined(separator: "\n")))
        continue
      }
      if let item = listItem(line) {
        flush()
        while let last = indents.last, last > item.indent { indents.removeLast() }
        if indents.last != item.indent { indents.append(item.indent) }
        blocks.append(
          .listItem(depth: min(indents.count - 1, 4), marker: item.marker, text: item.text))
        i += 1
        continue
      }
      if line.contains("|"), i + 1 < lines.count, isTableSeparator(lines[i + 1]) {
        flush()
        indents = []
        let header = cells(line)
        i += 2
        var rows: [[String]] = []
        while i < lines.count, lines[i].contains("|"),
          !lines[i].trimmingCharacters(in: .whitespaces).isEmpty
        {
          rows.append(cells(lines[i]))
          i += 1
        }
        blocks.append(.table(header: header, rows: rows))
        continue
      }
      // Eingerückte Fortsetzung eines Listenpunkts.
      if paragraph.isEmpty, line.hasPrefix("  "), case .listItem(let d, let m, let t)? = blocks.last
      {
        blocks[blocks.count - 1] = .listItem(depth: d, marker: m, text: t + "\n" + trimmed)
        i += 1
        continue
      }
      indents = []
      paragraph.append(line)
      i += 1
    }
    flush()
    return blocks
  }

  // MARK: Bausteine

  private static func stripComments(_ text: String) -> String {
    guard text.contains("<!--"),
      let regex = try? NSRegularExpression(pattern: "<!--.*?-->", options: [.dotMatchesLineSeparators])
    else { return text }
    return regex.stringByReplacingMatches(
      in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
  }

  private static func heading(_ trimmed: String) -> MDBlock? {
    let hashes = trimmed.prefix { $0 == "#" }.count
    guard (1...6).contains(hashes), trimmed.dropFirst(hashes).first == " " else { return nil }
    var text = trimmed.dropFirst(hashes).trimmingCharacters(in: .whitespaces)
    while text.hasSuffix("#") { text.removeLast() }
    return .heading(level: hashes, text: text.trimmingCharacters(in: .whitespaces))
  }

  private static func isRule(_ trimmed: String) -> Bool {
    let compact = trimmed.replacingOccurrences(of: " ", with: "")
    guard compact.count >= 3, let first = compact.first, "-*_".contains(first) else { return false }
    return compact.allSatisfy { $0 == first }
  }

  private static func listItem(_ line: String) -> (indent: Int, marker: String, text: String)? {
    let indent = line.prefix { $0 == " " }.count
    let rest = line.dropFirst(indent)
    guard let first = rest.first else { return nil }
    if "-*+".contains(first), rest.dropFirst().first == " " {
      var text = rest.dropFirst(2).trimmingCharacters(in: .whitespaces)
      if text.hasPrefix("[ ] ") { return (indent, "☐", String(text.dropFirst(4))) }
      if text.lowercased().hasPrefix("[x] ") { return (indent, "☑", String(text.dropFirst(4))) }
      if text.isEmpty { text = " " }
      return (indent, "•", text)
    }
    let digits = rest.prefix { $0.isNumber }
    if !digits.isEmpty, digits.count <= 9 {
      let after = rest.dropFirst(digits.count)
      if let delimiter = after.first, ".)".contains(delimiter), after.dropFirst().first == " " {
        return (indent, "\(digits).", after.dropFirst(2).trimmingCharacters(in: .whitespaces))
      }
    }
    return nil
  }

  private static func isTableSeparator(_ line: String) -> Bool {
    let compact = line.replacingOccurrences(of: " ", with: "")
    return compact.contains("-") && compact.contains("|")
      && compact.allSatisfy { "|:-".contains($0) }
  }

  private static func cells(_ line: String) -> [String] {
    var parts = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    if parts.first?.isEmpty == true { parts.removeFirst() }
    if parts.last?.isEmpty == true { parts.removeLast() }
    return parts
  }

  // Bilder stehen als eigene Blöcke: `![Beschreibung](pfad.png)` und der Obsidian-Stil `![[pfad.png]]`.
  private static let imagePattern = try? NSRegularExpression(
    pattern: #"!\[\[([^\]|]+)(?:\|[^\]]*)?\]\]|!\[([^\]]*)\]\(\s*<?([^)>]+?)>?\s*\)"#)

  static func splitImages(_ text: String) -> [MDBlock] {
    guard text.contains("!["), let regex = imagePattern else { return paragraphs(text) }
    let ns = text as NSString
    var blocks: [MDBlock] = []
    var cursor = 0
    for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
      blocks += paragraphs(ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
      if match.range(at: 1).location != NSNotFound {
        blocks.append(.image(alt: "", path: ns.substring(with: match.range(at: 1))))
      } else {
        var path = ns.substring(with: match.range(at: 3))
        // `![](pfad.png "Titel")`: der Titel gehört nicht zum Pfad.
        if let quote = path.range(of: " \"") { path = String(path[..<quote.lowerBound]) }
        blocks.append(.image(alt: ns.substring(with: match.range(at: 2)), path: path))
      }
      cursor = match.range.location + match.range.length
    }
    blocks += paragraphs(ns.substring(from: cursor))
    return blocks
  }

  private static func paragraphs(_ text: String) -> [MDBlock] {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? [] : [.paragraph(trimmed)]
  }
}
