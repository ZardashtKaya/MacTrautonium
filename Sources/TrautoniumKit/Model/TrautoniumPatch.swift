import Foundation

public enum WaveformType: Int, Codable, CaseIterable, Sendable {
    case sawtooth = 0
    case neon = 1

    public var title: String {
        switch self {
        case .sawtooth: return "Sawtooth"
        case .neon: return "Neon (Sala)"
        }
    }
}

public enum SnapMode: Int, Codable, CaseIterable, Sendable {
    case off = 0
    case soft = 1
    case hard = 2

    public var title: String {
        switch self {
        case .off: return "Continuous"
        case .soft: return "Soft Attraction"
        case .hard: return "Hard Quantize"
        }
    }
}

public enum PressSource: Int, Codable, CaseIterable, Sendable {
    case force = 0
    case area = 1
    case fixed = 2

    public var title: String {
        switch self {
        case .force: return "Force Touch (Grams)"
        case .area: return "Contact Area"
        case .fixed: return "Fixed (Test)"
        }
    }
}

public enum PressCurve: Int, Codable, CaseIterable, Sendable {
    case linear = 0
    case soft = 1
    case hard = 2

    public var title: String {
        switch self {
        case .linear: return "Linear"
        case .soft: return "Soft Touch"
        case .hard: return "Hard Pressure"
        }
    }
}

public struct ManualParams: Codable, Sendable, Equatable {
    public var lowNote: Int = 57           // MIDI note at left ribbon edge (A3=57, A2=45)
    public var span: Int = 2               // Octave span across trackpad width (1..4)
    public var isMono: Bool = false        // Polyphonic by default; true = single voice legato
    public var glideMs: Float = 20.0       // Portamento glide speed in ms
    public var snapMode: SnapMode = .off   // Continuous pitch vs snapping
    public var waveform: WaveformType = .sawtooth
    public var mainLevel: Float = 0.8      // Fundamental master oscillator level
    public var subDividers: [Int] = [2, 3, 4, 5] // 4 subharmonic integer divisors (f/N)
    public var subLevels: [Float] = [0.55, 0.40, 0.30, 0.20] // 4 subharmonic volumes
    public var noiseLevel: Float = 0.0     // Vintage breath noise
    public var analogDrift: Float = 0.2    // Analog tube drift in cents
    public var vowel: Int = -1             // -1: off, 0: A, 1: E, 2: I, 3: O, 4: U
    public var register: Int = 1           // 0: Bass, 1: Tenor, 2: Soprano
    public var cutoff: Float = 1800.0      // Filter cutoff in Hz
    public var resonance: Float = 0.15     // Filter resonance (0..0.95)
    public var pressureBrightness: Float = 0.6 // Cutoff modulation by touch pressure
    public var attackMs: Float = 5.0       // Attack time in ms
    public var decayMs: Float = 300.0      // Decay time in ms
    public var sustain: Float = 1.0        // Sustain level (0 = percussive pluck, 1 = organ)
    public var releaseMs: Float = 120.0    // Release time in ms
    public var volume: Float = 0.65        // Manual volume

    public init() {}
}

public struct TrautoniumPatch: Codable, Sendable, Equatable {
    public var name: String = "Mixtur Classic"
    public var manuals: [ManualParams] = [
        ManualParams(), // Manual I (Upper)
        ManualParams()  // Manual II (Lower)
    ]
    public var isSplit: Bool = true        // Split trackpad into 2 manuals (top/bottom)
    public var scaleIndex: Int = 0         // Scale index (0 = Chromatic)
    public var tonic: Int = 9              // Tonic pitch class (0=C, 9=A)
    public var reverbMix: Float = 0.25     // Stereo Reverb dry/wet
    public var echoMix: Float = 0.0        // Stereo Tape Delay mix
    public var echoTimeMs: Float = 350.0   // Delay time in ms
    public var echoFeedback: Float = 0.35  // Delay feedback
    public var saturation: Float = 0.15    // Analog soft-clipping warmth

    public init() {
        // Configure default Manual I (Lead/Melody)
        manuals[0].lowNote = 57            // A3..A5
        manuals[0].span = 2
        manuals[0].waveform = .sawtooth
        manuals[0].subDividers = [2, 3, 4, 5]
        manuals[0].subLevels = [0.55, 0.40, 0.30, 0.20]
        manuals[0].vowel = -1              // Pure raw subharmonic mixture
        manuals[0].cutoff = 2200.0

        // Configure default Manual II (Bass/Mixtur)
        manuals[1].lowNote = 45            // A2..A4 (one octave lower)
        manuals[1].span = 2
        manuals[1].waveform = .neon
        manuals[1].subDividers = [2, 4, 6, 8]
        manuals[1].subLevels = [0.50, 0.50, 0.25, 0.25]
        manuals[1].vowel = 0               // Vowel "A" formant active
        manuals[1].register = 0            // Bass register
        manuals[1].cutoff = 1400.0
    }
}
