import FancyCore
import JavaScriptKit

/// Every sound is synthesized live with Web Audio; there are no sample files.
final class Synth {
  private var context: JSObject?
  private var output: JSObject?
  private var noise: JSObject?

  /// Must run synchronously inside a user gesture, or browsers keep audio muted.
  /// `whenRunning` fires once the context has actually resumed.
  func unlock(whenRunning: (() -> Void)? = nil) {
    if context == nil, let constructor = (window.AudioContext.function ?? window.webkitAudioContext.function) {
      let context = constructor.new()
      let output = context.createGain!().object!
      output.gain.object!.value = .number(0.45)
      _ = output.connect!(context.destination)
      self.context = context
      self.output = output
      noise = makeNoise(context)
    }
    guard let resumed = context?.resume!().object.flatMap(JSPromise.init) else { return }
    if let whenRunning {
      _ = resumed.then { _ in
        whenRunning()
        return .undefined
      }
    }
  }

  func play(_ effect: SoundEffect) {
    guard let context, context.state.string == "running" else { return }
    let now = context.currentTime.number ?? 0
    for tone in effect.tones {
      schedule(tone, at: now + tone.delay, in: context)
    }
  }

  private func schedule(_ tone: Tone, at start: Double, in context: JSObject) {
    guard let output else { return }
    let end = start + tone.duration
    let amp = context.createGain!().object!
    let gain = amp.gain.object!
    _ = gain.setValueAtTime!(0.0001, start)
    _ = gain.exponentialRampToValueAtTime!(tone.gain, start + tone.attack)
    _ = gain.exponentialRampToValueAtTime!(0.0001, end)
    _ = amp.connect!(output)

    let source: JSObject
    if case .noise(let filterType) = tone.wave {
      source = context.createBufferSource!().object!
      source.buffer = noise.map(JSValue.object) ?? .null
      source.loop = .boolean(true)
      let filter = context.createBiquadFilter!().object!
      filter.type = .string(filterType)
      filter.frequency.object!.value = .number(tone.frequency)
      filter.Q.object!.value = .number(tone.q)
      _ = source.connect!(filter)
      _ = filter.connect!(amp)
    } else {
      source = context.createOscillator!().object!
      source.type = .string(tone.wave.oscillatorType)
      let frequency = source.frequency.object!
      _ = frequency.setValueAtTime!(tone.frequency, start)
      if let target = tone.glide {
        _ = frequency.exponentialRampToValueAtTime!(target, end)
      }
      if let fm = tone.fm {
        let modulator = context.createOscillator!().object!
        modulator.frequency.object!.value = .number(tone.frequency * fm.ratio)
        let depth = context.createGain!().object!
        _ = depth.gain.object!.setValueAtTime!(tone.frequency * fm.index, start)
        _ = depth.gain.object!.exponentialRampToValueAtTime!(max(1, tone.frequency * fm.index * 0.05), end)
        _ = modulator.connect!(depth)
        _ = depth.connect!(frequency)
        _ = modulator.start!(start)
        _ = modulator.stop!(end + 0.05)
      }
      _ = source.connect!(amp)
    }
    _ = source.start!(start)
    _ = source.stop!(end + 0.05)
  }

  private func makeNoise(_ context: JSObject) -> JSObject {
    let rate = Int(context.sampleRate.number ?? 44_100)
    let buffer = context.createBuffer!(1, rate, rate).object!
    var generator = SystemRandomNumberGenerator()
    let samples = (0..<rate).map { _ in Float.random(in: -1...1, using: &generator) }
    _ = buffer.getChannelData!(0).object!.set!(JSTypedArray<Float32>(samples))
    return buffer
  }
}

struct Tone {
  enum Wave {
    case sine, square, sawtooth, triangle
    case noise(filter: String)

    var oscillatorType: String {
      switch self {
      case .sine: "sine"
      case .square: "square"
      case .sawtooth: "sawtooth"
      case .triangle: "triangle"
      case .noise: "sine"
      }
    }
  }

  var wave: Wave
  var frequency: Double
  var glide: Double? = nil
  var duration: Double
  var gain: Double
  var attack: Double = 0.003
  var delay: Double = 0
  var fm: (ratio: Double, index: Double)? = nil
  var q: Double = 1
}

extension SoundEffect {
  var tones: [Tone] {
    switch self {
    case .key:
      // Paper-dry and mid-only, with a faint second tick as the key comes back up.
      [
        Tone(wave: .noise(filter: "bandpass"), frequency: Double.random(in: 1800...2200), duration: 0.016, gain: 0.5, attack: 0.001, q: 4),
        Tone(wave: .noise(filter: "bandpass"), frequency: Double.random(in: 700...800), duration: 0.02, gain: 0.25, attack: 0.001, q: 3),
        Tone(
          wave: .noise(filter: "bandpass"), frequency: Double.random(in: 1300...1500), duration: 0.012, gain: 0.18, attack: 0.001,
          delay: Double.random(in: 0.035...0.045), q: 4
        ),
      ]
    case .enter:
      [
        Tone(wave: .noise(filter: "bandpass"), frequency: 1500, duration: 0.028, gain: 0.55, attack: 0.001, q: 3.5),
        Tone(wave: .noise(filter: "bandpass"), frequency: 600, duration: 0.036, gain: 0.35, attack: 0.001, q: 3),
        Tone(wave: .noise(filter: "bandpass"), frequency: 1100, duration: 0.016, gain: 0.22, attack: 0.001, delay: 0.06, q: 4),
      ]
    case .error:
      [
        Tone(wave: .sawtooth, frequency: 155, glide: 92, duration: 0.22, gain: 0.09),
        Tone(wave: .square, frequency: 78, duration: 0.22, gain: 0.04),
      ]
    case .open:
      [523.25, 659.25, 987.77].enumerated().map { index, frequency in
        Tone(wave: .triangle, frequency: frequency, duration: 0.09, gain: 0.12, delay: Double(index) * 0.045)
      }
    case .close:
      [987.77, 659.25, 523.25].enumerated().map { index, frequency in
        Tone(wave: .triangle, frequency: frequency, duration: 0.08, gain: 0.1, delay: Double(index) * 0.04)
      }
    case .blip:
      [Tone(wave: .square, frequency: 1318.5, glide: 1760, duration: 0.04, gain: 0.04, attack: 0.001)]
    case .popup:
      [
        Tone(wave: .sine, frequency: 880, duration: 0.6, gain: 0.16, fm: (ratio: 3.5, index: 1.6)),
        Tone(wave: .sine, frequency: 1320, duration: 0.4, gain: 0.06, delay: 0.05, fm: (ratio: 1.41, index: 0.8)),
      ]
    case .boot:
      [
        Tone(wave: .noise(filter: "lowpass"), frequency: 140, duration: 0.45, gain: 0.5, attack: 0.002, q: 4),
        Tone(wave: .sine, frequency: 55, glide: 49, duration: 0.6, gain: 0.25, attack: 0.002),
      ]
        // Cmaj7 with a quarter-tone-flat 9th and a slightly flat #11 above it.
        + [(261.63, 0.09), (329.63, 0.09), (392.0, 0.09), (493.88, 0.09), (571.0, 0.035), (733.6, 0.055)]
        .enumerated().map { index, note in
          Tone(
            wave: .sine, frequency: note.0, duration: 2.6, gain: note.1, attack: 0.02,
            delay: 0.35 + Double(index) * 0.012, fm: (ratio: 2.0, index: 0.9)
          )
        }
        + [Tone(wave: .triangle, frequency: 130.81 * 1.003, duration: 2.8, gain: 0.08, attack: 0.03, delay: 0.36)]
    }
  }
}
