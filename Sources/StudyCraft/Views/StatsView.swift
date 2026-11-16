import Charts
import SwiftUI

// Statistik: wie viel heute gelernt wurde, die Lernsträhne und ein Überblick über die letzten Tage.
struct StatsView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    let stats = model.makeStats()
    NavigationStack {
      ScrollView {
        VStack(spacing: 14) {
          HStack(spacing: 14) {
            today(stats)
            streak(stats)
          }
          .fixedSize(horizontal: false, vertical: true)
          chart(stats)
          cards(stats)
          details(stats)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
      }
      .background(Theme.background)
      .navigationTitle("Statistik")
      .navigationBarTitleDisplayMode(.large)
    }
  }

  private func today(_ stats: StatsSummary) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Label("Heute", systemImage: "checkmark.circle")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Theme.textSecondary)
      Text("\(stats.cardsToday)")
        .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
        .contentTransition(.numericText())
      Text(
        stats.cardsToday == 1 ? "Karte gelernt" : "Karten gelernt"
      )
      .font(.footnote)
      .foregroundStyle(Theme.textSecondary)
      Spacer(minLength: 0)
      if stats.today.reviews > 0 {
        Text(todayDetail(stats.today))
          .font(.caption)
          .foregroundStyle(Theme.textTertiary)
      }
    }
    .surface()
  }

  private func todayDetail(_ log: DayLog) -> String {
    var parts: [String] = []
    if log.reviews > 0 { parts.append(log.reviews == 1 ? "1 Antwort" : "\(log.reviews) Antworten") }
    if log.newCards > 0 { parts.append("\(log.newCards) neu") }
    let minutes = Int((log.seconds / 60).rounded())
    if minutes > 0 { parts.append("\(minutes) Min") }
    return parts.joined(separator: " · ")
  }

  private func streak(_ stats: StatsSummary) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Label("Lernserie", systemImage: "flame.fill")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(stats.streak > 0 ? Theme.warning : Theme.textSecondary)
      Text("\(stats.streak)")
        .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
      Text(stats.streak == 1 ? "Tag in Folge" : "Tage in Folge")
        .font(.footnote)
        .foregroundStyle(Theme.textSecondary)
      Spacer(minLength: 0)
      Text(
        stats.streak > 0 && stats.today.reviews == 0
          ? "Lerne heute, um sie zu halten" : "Längste: \(stats.longestStreak)"
      )
      .font(.caption)
      .foregroundStyle(Theme.textTertiary)
    }
    .surface()
  }

  private func chart(_ stats: StatsSummary) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Letzte 14 Tage")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Theme.textSecondary)
      Chart(stats.recent) { point in
        BarMark(
          x: .value("Tag", point.date, unit: .day),
          y: .value("Karten", point.reviews)
        )
        .foregroundStyle(point.day == stats.recent.last?.day ? Theme.accent : Theme.accent.opacity(0.45))
        .cornerRadius(4)
      }
      .chartXAxis {
        AxisMarks(values: .stride(by: .day, count: 3)) { _ in
          AxisValueLabel(format: .dateTime.day().month(.defaultDigits), centered: true)
            .foregroundStyle(Theme.textTertiary)
        }
      }
      .chartYAxis {
        AxisMarks(position: .leading) { _ in
          AxisGridLine().foregroundStyle(Theme.separator)
          AxisValueLabel().foregroundStyle(Theme.textTertiary)
        }
      }
      .frame(height: 150)
    }
    .surface()
  }

  private func cards(_ stats: StatsSummary) -> some View {
    let total = max(1, stats.newCards + stats.learningCards + stats.youngCards + stats.matureCards)
    let rows: [(String, Int, Color)] = [
      ("Neu", stats.newCards, Theme.newBlue),
      ("Lernen", stats.learningCards, Theme.warning),
      ("Jung", stats.youngCards, Theme.success.opacity(0.6)),
      ("Gefestigt", stats.matureCards, Theme.success),
    ]
    return VStack(alignment: .leading, spacing: 12) {
      Text("Deine Karten")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Theme.textSecondary)
      GeometryReader { geometry in
        HStack(spacing: 2) {
          ForEach(rows, id: \.0) { row in
            if row.1 > 0 {
              Rectangle().fill(row.2)
                .frame(width: max(4, geometry.size.width * Double(row.1) / Double(total)))
            }
          }
        }
        .clipShape(Capsule())
      }
      .frame(height: 10)
      .background(Theme.raised, in: Capsule())
      ForEach(rows, id: \.0) { row in
        HStack {
          Circle().fill(row.2).frame(width: 8, height: 8)
          Text(row.0).font(.subheadline)
          Spacer()
          Text("\(row.1)").font(.subheadline.monospacedDigit()).foregroundStyle(Theme.textSecondary)
        }
      }
    }
    .surface()
  }

  private func details(_ stats: StatsSummary) -> some View {
    VStack(spacing: 12) {
      detail("Antworten insgesamt", "\(stats.totalReviews)")
      Divider().overlay(Theme.separator)
      detail("Gelernte Tage", "\(stats.activeDays)")
      Divider().overlay(Theme.separator)
      detail(
        "Behaltensrate (30 Tage)",
        stats.retention.map { "\(Int(($0 * 100).rounded())) %" } ?? "–")
      Divider().overlay(Theme.separator)
      detail("Lernzeit insgesamt", duration(stats.totalSeconds))
    }
    .surface()
  }

  private func detail(_ title: String, _ value: String) -> some View {
    HStack {
      Text(title).font(.subheadline)
      Spacer()
      Text(value).font(.subheadline.monospacedDigit()).foregroundStyle(Theme.textSecondary)
    }
  }

  private func duration(_ seconds: Double) -> String {
    let minutes = Int((seconds / 60).rounded())
    if minutes < 60 { return "\(minutes) Min" }
    return "\(minutes / 60) Std \(minutes % 60) Min"
  }
}
