import SwiftUI

// Der Startbildschirm: alle Decks als aufklappbare Liste, daneben blau die neuen und grün die
// fälligen Karten. Ein Tipp auf ein Deck startet die Lernsitzung.
struct DeckListView: View {
  @Environment(AppModel.self) private var model
  @State private var settings = false
  @AppStorage("expandedDecks") private var expandedStorage = ""

  private struct Row: Identifiable {
    var node: DeckNode
    var depth: Int
    var id: String { node.id }
  }

  private var expanded: Set<String> {
    Set(expandedStorage.split(separator: "\n").map(String.init))
  }

  // Die sichtbaren Zeilen: aufgeklappte Decks zeigen ihre Unterdecks direkt darunter.
  private var rows: [Row] {
    var result: [Row] = []
    func add(_ nodes: [DeckNode], depth: Int) {
      for node in nodes {
        result.append(Row(node: node, depth: depth))
        if expanded.contains(node.id) { add(node.children, depth: depth + 1) }
      }
    }
    add(model.decks, depth: 0)
    return result
  }

  private func toggle(_ id: String) {
    var set = expanded
    if set.contains(id) { set.remove(id) } else { set.insert(id) }
    withAnimation(.snappy) { expandedStorage = set.sorted().joined(separator: "\n") }
  }

  var body: some View {
    NavigationStack {
      Group {
        if model.decks.isEmpty {
          emptyState
        } else {
          List {
            ForEach(rows) { row in
              DeckRow(
                node: row.node, depth: row.depth, counts: model.counts(for: row.node),
                expanded: expanded.contains(row.node.id),
                toggle: { toggle(row.node.id) },
                open: { model.startSession(row.node) }
              )
              .listRowBackground(Theme.card)
              .listRowSeparatorTint(Theme.separator)
            }
          }
          .listStyle(.insetGrouped)
          .scrollContentBackground(.hidden)
        }
      }
      .background(Theme.background)
      .navigationTitle("Decks")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          if model.isScanning && model.hasScanned {
            ProgressView()
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            settings = true
          } label: {
            Image(systemName: "gearshape")
          }
          .accessibilityLabel("Einstellungen")
        }
      }
      .refreshable { await model.refresh() }
    }
    .sheet(isPresented: $settings) { SettingsView() }
  }

  @ViewBuilder
  private var emptyState: some View {
    if !model.hasScanned {
      VStack(spacing: 14) {
        ProgressView()
        Text("Lernordner wird gelesen …")
          .font(.subheadline)
          .foregroundStyle(Theme.textSecondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollView {
        ContentUnavailableView {
          Label("Noch keine Karten", systemImage: "rectangle.stack")
        } description: {
          Text(
            "In „\(model.rootName)“ liegen keine Markdown-Dateien mit Karten. Eine Datei ist eine Karte, wenn ihre erste Zeile @studyCraft oder @studyCraft_List lautet."
          )
        } actions: {
          Button("Beispiel-Deck anlegen") { createSample() }
            .buttonStyle(.borderedProminent)
          Button("Kartenformat ansehen") { settings = true }
        }
        .padding(.top, 60)
      }
      .refreshable { await model.refresh() }
    }
  }

  private func createSample() {
    guard let root = model.rootURL else { return }
    do {
      try SampleDeck.write(into: root)
      Task { await model.refresh() }
    } catch {
      model.errorMessage = "Das Beispiel-Deck konnte nicht angelegt werden: \(error.localizedDescription)"
    }
  }
}

private struct DeckRow: View {
  let node: DeckNode
  let depth: Int
  let counts: DeckCounts
  let expanded: Bool
  let toggle: () -> Void
  let open: () -> Void

  var body: some View {
    HStack(spacing: 0) {
      // Der Pfeil klappt auf, der Rest der Zeile startet das Lernen.
      Group {
        if node.children.isEmpty {
          Color.clear
        } else {
          Button(action: toggle) {
            Image(systemName: "chevron.right")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(Theme.textTertiary)
              .rotationEffect(.degrees(expanded ? 90 : 0))
              .frame(width: 44, height: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(expanded ? "Zuklappen" : "Aufklappen")
        }
      }
      .frame(width: 30, height: 44)
      .padding(.leading, CGFloat(depth) * 18)

      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text(node.name)
            .font(.headline)
            .foregroundStyle(Theme.textPrimary)
          Text(counts.total == 1 ? "1 Karte" : "\(counts.total) Karten")
            .font(.footnote)
            .foregroundStyle(Theme.textTertiary)
        }
        Spacer(minLength: 8)
        HStack(spacing: 0) {
          count(counts.new, color: Theme.newBlue)
          count(counts.due, color: Theme.success)
        }
      }
      .padding(.vertical, 4)
      .contentShape(Rectangle())
      .onTapGesture(perform: open)
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isButton)
      .accessibilityHint("Startet das Lernen")
      .accessibilityValue("\(counts.new) neu, \(counts.due) fällig")
    }
  }

  private func count(_ value: Int, color: Color) -> some View {
    Text("\(value)")
      .font(.system(.body, design: .rounded).weight(.semibold).monospacedDigit())
      .foregroundStyle(value == 0 ? Theme.textTertiary.opacity(0.7) : color)
      .frame(minWidth: 40, alignment: .trailing)
  }
}
