import CoreHaptics
import UIKit

// Die Haptik des Ultra-Dopamin-Modus: ein Grollen, das beim Halten immer stärker wird (die Glühbirne lädt sich
// auf), dann ein Aufblitz mit drei aufsteigenden Taps. Ohne CoreHaptics (iPad, Simulator) passiert hier
// nichts; die gewöhnlichen Impulse aus `Haptics` übernehmen dann.
@MainActor
final class RewardHaptics {
  private var engine: CHHapticEngine?
  private var rumble: CHHapticAdvancedPatternPlayer?
  let supported = CHHapticEngine.capabilitiesForHardware().supportsHaptics

  init() {
    guard supported else { return }
    do {
      let engine = try CHHapticEngine()
      engine.isAutoShutdownEnabled = false
      engine.resetHandler = { [weak self] in
        Task { @MainActor in try? self?.engine?.start() }
      }
      try engine.start()
      self.engine = engine
    } catch {
      engine = nil
    }
  }

  private func event(
    _ type: CHHapticEvent.EventType, intensity: Float, sharpness: Float, at time: TimeInterval,
    duration: TimeInterval = 0
  ) -> CHHapticEvent {
    CHHapticEvent(
      eventType: type,
      parameters: [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
      ], relativeTime: time, duration: duration)
  }

  // Ein tiefes Grollen, das über `duration` hinweg von leise zu voll anschwillt, mit knarzenden Stößen
  // dazwischen, die immer dichter kommen.
  func startRumble(duration: TimeInterval) {
    guard let engine else { return }
    stopRumble()
    var events = [event(.hapticContinuous, intensity: 1, sharpness: 0.2, at: 0, duration: duration)]
    var time = 0.05
    var gap = 0.16
    while time < duration {
      let progress = Float(time / duration)
      events.append(event(.hapticTransient, intensity: 0.25 + 0.75 * progress, sharpness: 0.5 + 0.5 * progress, at: time))
      time += gap
      gap = max(0.03, gap * 0.82)
    }
    let intensity = CHHapticParameterCurve(
      parameterID: .hapticIntensityControl,
      controlPoints: [
        .init(relativeTime: 0, value: 0.1),
        .init(relativeTime: duration * 0.4, value: 0.3),
        .init(relativeTime: duration * 0.75, value: 0.65),
        .init(relativeTime: duration, value: 1),
      ], relativeTime: 0)
    let sharpness = CHHapticParameterCurve(
      parameterID: .hapticSharpnessControl,
      controlPoints: [
        .init(relativeTime: 0, value: -0.1), .init(relativeTime: duration, value: 0.6),
      ], relativeTime: 0)
    do {
      let pattern = try CHHapticPattern(events: events, parameterCurves: [intensity, sharpness])
      let player = try engine.makeAdvancedPlayer(with: pattern)
      try player.start(atTime: CHHapticTimeImmediate)
      rumble = player
    } catch {
      rumble = nil
    }
  }

  func stopRumble() {
    try? rumble?.stop(atTime: CHHapticTimeImmediate)
    rumble = nil
  }

  // Der Aufblitz: ein satter Schlag, ein abklingendes Beben, drei aufsteigende Taps wie „Ja – genau – richtig“
  // und danach leises Funkeln.
  func playBurst() {
    guard let engine else { return }
    stopRumble()
    var events = [
      event(.hapticTransient, intensity: 1, sharpness: 0.9, at: 0),
      event(.hapticContinuous, intensity: 0.8, sharpness: 0.25, at: 0.02, duration: 0.3),
      event(.hapticTransient, intensity: 0.6, sharpness: 0.9, at: 0.14),
      event(.hapticTransient, intensity: 0.8, sharpness: 0.9, at: 0.24),
      event(.hapticTransient, intensity: 1, sharpness: 1, at: 0.34),
    ]
    var time = 0.5
    var level: Float = 0.45
    while time < 1.1 {
      events.append(event(.hapticTransient, intensity: level, sharpness: 1, at: time))
      time += Double.random(in: 0.06...0.1)
      level = max(0.1, level - 0.05)
    }
    let decay = CHHapticParameterCurve(
      parameterID: .hapticIntensityControl,
      controlPoints: [.init(relativeTime: 0.02, value: 1), .init(relativeTime: 0.32, value: 0)],
      relativeTime: 0)
    play(events: events, curves: [decay], on: engine)
  }

  // Ein kleiner Gewinn: zwei knackige Schläge.
  func playSmallWin() {
    guard let engine else { return }
    stopRumble()
    let events = [
      event(.hapticTransient, intensity: 0.9, sharpness: 0.9, at: 0),
      event(.hapticTransient, intensity: 0.6, sharpness: 1, at: 0.075),
      event(.hapticTransient, intensity: 0.35, sharpness: 1, at: 0.14),
    ]
    play(events: events, curves: [], on: engine)
  }

  private func play(events: [CHHapticEvent], curves: [CHHapticParameterCurve], on engine: CHHapticEngine) {
    do {
      let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
      let player = try engine.makePlayer(with: pattern)
      try player.start(atTime: CHHapticTimeImmediate)
    } catch {}
  }
}
