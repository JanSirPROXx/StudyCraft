import AVFoundation

// Die Klänge des Ultra-Dopamin-Modus. Es gibt keine Audio-Dateien: alles wird beim ersten Gebrauch aus
// Sinuswellen und Rauschen berechnet (Glockentöne, Sternenstaub, ein weiches Whoomp) und als kleine WAV-Daten
// abgespielt. Der Ton folgt dem Stumm-Schalter und lässt Musik und Podcasts weiterlaufen.
@MainActor
final class RewardAudio {
  private var charge: AVAudioPlayer?
  private var small: AVAudioPlayer?
  private var burst: AVAudioPlayer?
  private var started = false

  func prepare() {
    guard !started else { return }
    started = true
    try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
    try? AVAudioSession.sharedInstance().setActive(true)
    Task.detached(priority: .userInitiated) {
      let sounds = (Synth.charge(), Synth.small(), Synth.burst())
      await MainActor.run { [weak self] in self?.install(sounds) }
    }
  }

  private func install(_ sounds: (Data, Data, Data)) {
    charge = try? AVAudioPlayer(data: sounds.0)
    small = try? AVAudioPlayer(data: sounds.1)
    burst = try? AVAudioPlayer(data: sounds.2)
    for player in [charge, small, burst] { player?.prepareToPlay() }
    charge?.volume = 0.8
    small?.volume = 0.9
    burst?.volume = 1
  }

  func startCharge() {
    charge?.stop()
    charge?.currentTime = 0
    charge?.volume = 0.8
    charge?.play()
  }

  func stopCharge() {
    guard let charge, charge.isPlaying else { return }
    charge.setVolume(0, fadeDuration: 0.08)
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(100))
      charge.stop()
    }
  }

  func playSmall() {
    stopCharge()
    small?.currentTime = 0
    small?.play()
  }

  func playBurst() {
    charge?.stop()
    burst?.currentTime = 0
    burst?.play()
  }
}

// Die Klangerzeugung: Mono, 44,1 kHz, 16 Bit.
private enum Synth {
  static let rate = 44100.0

  // Ein Glockenton aus Teiltönen, die nicht ganzzahlig zueinander stehen (das macht ihn "metallisch").
  private static func bell(_ frequency: Double, _ t: Double, decay: Double) -> Double {
    guard t >= 0 else { return 0 }
    let partials: [(ratio: Double, amplitude: Double, damping: Double)] = [
      (1, 1, 1), (2.0, 0.45, 1.4), (2.76, 0.32, 1.8), (5.4, 0.16, 2.6), (8.93, 0.08, 3.4),
    ]
    var sum = 0.0
    for part in partials {
      sum += part.amplitude * sin(2 * .pi * frequency * part.ratio * t) * exp(-t * decay * part.damping)
    }
    return sum * min(1, t * 900)  // kurzes Einblenden gegen Knacken
  }

  private static func noise() -> Double { Double.random(in: -1...1) }

  private static func wav(_ samples: [Double]) -> Data {
    let peak = max(0.0001, samples.map(abs).max() ?? 1)
    let gain = 0.92 / peak
    var pcm = [Int16]()
    pcm.reserveCapacity(samples.count)
    for sample in samples {
      pcm.append(Int16(max(-1, min(1, tanh(sample * gain * 1.1))) * 32000))
    }
    var data = Data()
    func put<T: FixedWidthInteger>(_ value: T) {
      withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
    data.append("RIFF".data(using: .ascii)!)
    put(UInt32(36 + pcm.count * 2))
    data.append("WAVEfmt ".data(using: .ascii)!)
    put(UInt32(16)); put(UInt16(1)); put(UInt16(1))
    put(UInt32(rate)); put(UInt32(rate) * 2); put(UInt16(2)); put(UInt16(16))
    data.append("data".data(using: .ascii)!)
    put(UInt32(pcm.count * 2))
    for value in pcm { put(value) }
    return data
  }

  // Der Anlauf: ein steigender Ton mit Rattern, das immer schneller wird (0,9 s).
  static func charge() -> Data {
    let duration = 0.9
    var samples = [Double](repeating: 0, count: Int(duration * rate))
    var ticks: [Double] = []
    var tickTime = 0.0
    var interval = 0.15
    while tickTime < duration {
      ticks.append(tickTime)
      tickTime += interval
      interval = max(0.028, interval * 0.84)
    }
    var phase = 0.0
    for index in samples.indices {
      let t = Double(index) / rate
      let progress = t / duration
      let frequency = 180 * pow(6.5, progress)
      phase += 2 * .pi * frequency / rate
      let vibrato = 1 + 0.12 * sin(2 * .pi * (14 + 30 * progress) * t)
      var value = (sin(phase) * 0.6 + sin(phase * 2) * 0.25) * vibrato * (0.05 + 0.35 * progress * progress)
      for tick in ticks where t >= tick && t < tick + 0.02 {  // Ratterkörner
        let since = t - tick
        value += sin(2 * .pi * (1800 + 2200 * progress) * since) * exp(-since * 170) * (0.25 + 0.4 * progress)
      }
      samples[index] = value * min(1, t * 60) * min(1, (duration - t) * 40)
    }
    return wav(samples)
  }

  // Ein heller Sternenstaub-Ton: ein kurzer, reiner Ton mit schnellem Abklingen.
  private static func sparkle(_ frequency: Double, _ t: Double) -> Double {
    guard t >= 0 else { return 0 }
    return sin(2 * .pi * frequency * t) * exp(-t * 30) * min(1, t * 1500)
  }

  // Ein kleines „Richtig“: zwei aufsteigende Glockentöne (0,8 s).
  static func small() -> Data {
    let count = Int(0.8 * rate)
    var samples = [Double](repeating: 0, count: count)
    for index in 0..<count {
      let t = Double(index) / rate
      var value = bell(1318.5, t, decay: 5) * 0.55 + bell(1760, t - 0.09, decay: 5) * 0.5
      value += sparkle(3951, t - 0.1) * 0.12
      samples[index] = value
    }
    return wav(samples)
  }

  // Der Aha-Moment: ein weiches „Whoomp“, ein aufsteigendes Glockenspiel und Sternenstaub (2 s).
  static func burst() -> Data {
    let duration = 2.0
    let count = Int(duration * rate)
    var samples = [Double](repeating: 0, count: count)
    let arpeggio: [Double] = [1046.5, 1318.5, 1568, 2093, 2637]
    let pentatonic: [Double] = [2093, 2349, 2637, 3136, 3520, 4186]
    var sparkles: [(time: Double, frequency: Double, level: Double)] = []
    var time = 0.3
    while time < 1.6 {
      sparkles.append((time, pentatonic.randomElement()!, max(0.07, 0.3 - time * 0.15)))
      time += Double.random(in: 0.06...0.13)
    }
    var thumbPhase = 0.0
    for index in 0..<count {
      let t = Double(index) / rate
      let thumbFrequency = 50 + 80 * exp(-t * 9)
      thumbPhase += 2 * .pi * thumbFrequency / rate
      var value = sin(thumbPhase) * exp(-t * 8) * 0.8 + noise() * exp(-t * 40) * 0.2
      for (note, frequency) in arpeggio.enumerated() {
        value += bell(frequency, t - 0.07 - Double(note) * 0.06, decay: 3) * 0.3
      }
      for frequency in [523.25, 659.25, 783.99, 1046.5] {
        value += bell(frequency, t - 0.4, decay: 1.6) * 0.16
      }
      for event in sparkles {
        value += sparkle(event.frequency, t - event.time) * event.level
      }
      samples[index] = value * min(1, (duration - t) * 8)
    }
    return wav(samples)
  }
}
