import Foundation

// Ein Lerntag beginnt wie bei Anki um 4 Uhr morgens: wer um 1 Uhr nachts noch lernt, lernt für "gestern".
// Tage werden als fortlaufende Ganzzahl geführt, damit sie sich über Geräte und Zeitzonen hinweg
// ohne Datumsformat-Probleme speichern und vergleichen lassen.
enum StudyClock {
  static let rolloverHour = 4

  static func dayIndex(for date: Date, timeZone: TimeZone = .current) -> Int {
    let shifted =
      date.timeIntervalSince1970 - Double(rolloverHour * 3600)
      + Double(timeZone.secondsFromGMT(for: date))
    return Int((shifted / 86400).rounded(.down))
  }

  // Der Moment, in dem der Lerntag `day` beginnt.
  static func startOfDay(_ day: Int, timeZone: TimeZone = .current) -> Date {
    let guess = Date(timeIntervalSince1970: Double(day * 86400 + rolloverHour * 3600))
    return Date(
      timeIntervalSince1970: guess.timeIntervalSince1970
        - Double(timeZone.secondsFromGMT(for: guess)))
  }
}

// Zeitabstände in der Kürze der Bewertungs-Buttons: "< 1 Min", "10 Min", "1 Tag", "4 Tage", "1,5 Mon.".
enum IntervalFormat {
  private static let number: NumberFormatter = {
    let f = NumberFormatter()
    f.locale = Locale(identifier: "de")
    f.maximumFractionDigits = 1
    f.minimumFractionDigits = 0
    return f
  }()

  static func short(_ seconds: TimeInterval) -> String {
    if seconds <= 60 { return "< 1 Min" }
    if seconds < 3600 { return "\(Int((seconds / 60).rounded())) Min" }
    if seconds < 86400 { return "\(Int((seconds / 3600).rounded())) Std" }
    let days = (seconds / 86400).rounded()
    if days < 31 { return days == 1 ? "1 Tag" : "\(Int(days)) Tage" }
    if days < 365 { return "\(format(days / 30.4)) Mon." }
    return "\(format(days / 365)) J."
  }

  // "in 3 Stunden", "morgen", "in 5 Tagen" für die Meldung, wenn gerade nichts fällig ist.
  static func relative(_ seconds: TimeInterval) -> String {
    if seconds < 3600 { return "in \(max(1, Int((seconds / 60).rounded()))) Min" }
    if seconds < 86400 {
      let hours = Int((seconds / 3600).rounded())
      return hours == 1 ? "in 1 Stunde" : "in \(hours) Stunden"
    }
    let days = Int((seconds / 86400).rounded())
    if days <= 1 { return "morgen" }
    return "in \(days) Tagen"
  }

  private static func format(_ value: Double) -> String {
    number.string(from: NSNumber(value: value)) ?? String(value)
  }
}
