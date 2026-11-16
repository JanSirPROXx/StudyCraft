import SwiftUI

// Zeigt eine Kartenseite: Überschriften, Absätze mit fett/kursiv/`Code`, Listen, Zitate, Tabellen,
// Code-Blöcke und eingebettete Bilder.
struct MarkdownView: View, Equatable {
  let blocks: [MDBlock]
  let resolver: ImageResolver
  var size: CGFloat = 21

  static func == (lhs: MarkdownView, rhs: MarkdownView) -> Bool {
    lhs.blocks == rhs.blocks && lhs.size == rhs.size
  }

  private enum Chunk {
    case block(MDBlock)
    case list([(depth: Int, marker: String, text: String)])
  }

  // Aufeinanderfolgende Listenpunkte werden zu einer Liste, damit sie enger stehen als Absätze.
  private var chunks: [Chunk] {
    var result: [Chunk] = []
    for block in blocks {
      if case .listItem(let depth, let marker, let text) = block {
        if case .list(var items)? = result.last {
          items.append((depth, marker, text))
          result[result.count - 1] = .list(items)
        } else {
          result.append(.list([(depth, marker, text)]))
        }
      } else {
        result.append(.block(block))
      }
    }
    return result
  }

  var body: some View {
    VStack(alignment: .leading, spacing: size * 0.7) {
      ForEach(Array(chunks.enumerated()), id: \.offset) { _, chunk in
        switch chunk {
        case .block(let block): view(for: block)
        case .list(let items): list(items)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private func view(for block: MDBlock) -> some View {
    switch block {
    case .heading(let level, let text):
      inline(text)
        .font(.system(size: headingSize(level), weight: level <= 2 ? .bold : .semibold))
        .padding(.top, level == 1 ? 2 : 0)
    case .paragraph(let text):
      inline(text).font(.system(size: size))
    case .listItem:
      EmptyView()
    case .code(_, let text):
      ScrollView(.horizontal, showsIndicators: false) {
        Text(text)
          .font(.system(size: size * 0.8, design: .monospaced))
          .padding(14)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .background(Theme.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    case .quote(let text):
      HStack(alignment: .top, spacing: 12) {
        RoundedRectangle(cornerRadius: 2).fill(Theme.accent).frame(width: 4)
        inline(text).font(.system(size: size)).foregroundStyle(Theme.textSecondary)
      }
      .fixedSize(horizontal: false, vertical: true)
    case .image(let alt, let path):
      MarkdownImage(alt: alt, path: path, resolver: resolver)
    case .rule:
      Divider().overlay(Theme.separator)
    case .table(let header, let rows):
      table(header: header, rows: rows)
    }
  }

  private func headingSize(_ level: Int) -> CGFloat {
    switch level {
    case 1: size * 1.55
    case 2: size * 1.3
    case 3: size * 1.15
    default: size
    }
  }

  private func list(_ items: [(depth: Int, marker: String, text: String)]) -> some View {
    VStack(alignment: .leading, spacing: size * 0.3) {
      ForEach(Array(items.enumerated()), id: \.offset) { _, item in
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(item.marker)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
            .frame(minWidth: size * 0.9, alignment: .trailing)
          inline(item.text).font(.system(size: size))
        }
        .padding(.leading, CGFloat(item.depth) * size * 1.1)
      }
    }
  }

  private func table(header: [String], rows: [[String]]) -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
      Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
        GridRow {
          ForEach(Array(header.enumerated()), id: \.offset) { _, cell in
            inline(cell).font(.system(size: size * 0.9, weight: .semibold))
          }
        }
        Divider().overlay(Theme.separator)
        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
          GridRow {
            ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
              inline(cell).font(.system(size: size * 0.9))
            }
          }
        }
      }
    }
  }

  private func inline(_ source: String) -> Text {
    Text(Self.attributed(source))
  }

  static func attributed(_ source: String) -> AttributedString {
    let options = AttributedString.MarkdownParsingOptions(
      interpretedSyntax: .inlineOnlyPreservingWhitespace,
      failurePolicy: .returnPartiallyParsedIfPossible)
    var text = (try? AttributedString(markdown: source, options: options)) ?? AttributedString(source)
    for run in text.runs {
      if run.inlinePresentationIntent?.contains(.code) == true {
        text[run.range].backgroundColor = UIColor(Theme.field)
      }
    }
    return text
  }
}

struct MarkdownImage: View {
  let alt: String
  let path: String
  let resolver: ImageResolver
  @State private var image: UIImage?
  @State private var failed = false

  var body: some View {
    Group {
      if let url = remoteURL {
        AsyncImage(url: url) { phase in
          if let image = phase.image {
            image.resizable().scaledToFit()
          } else if phase.error != nil {
            missing
          } else {
            ProgressView()
          }
        }
      } else if let image {
        Image(uiImage: image).resizable().scaledToFit()
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          .accessibilityLabel(alt)
      } else if failed {
        missing
      } else {
        ProgressView().frame(maxWidth: .infinity, minHeight: 80)
      }
    }
    .frame(maxHeight: 460)
    .frame(maxWidth: .infinity, alignment: .leading)
    .task(id: path) {
      guard remoteURL == nil else { return }
      guard let url = resolver.resolve(path), let loaded = await ImageLoader.load(url) else {
        failed = true
        return
      }
      image = loaded
    }
  }

  private var remoteURL: URL? {
    guard path.hasPrefix("http://") || path.hasPrefix("https://") else { return nil }
    return URL(string: path)
  }

  private var missing: some View {
    Label(alt.isEmpty ? path : alt, systemImage: "photo")
      .font(.footnote)
      .foregroundStyle(Theme.textTertiary)
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Theme.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}
