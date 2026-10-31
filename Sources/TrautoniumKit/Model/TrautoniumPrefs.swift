import Foundation

public enum OutputRoutingMode: String, Codable, CaseIterable, Sendable {
    case internalSynth = "Internal Synth"
    case midiOut = "MIDI Out"
    case both = "Synth + MIDI"

    public var title: String { rawValue }
    public var shortTitle: String {
        switch self {
        case .internalSynth: return "SYNTH"
        case .midiOut: return "MIDI OUT"
        case .both: return "BOTH"
        }
    }
}

public enum MIDIMode: String, Codable, CaseIterable, Sendable {
    case mpe = "MPE (Multi-Channel 2-16)"
    case standard = "Standard Poly (Ch 1)"

    public var title: String { rawValue }
}

public struct TrautoniumPrefs: Codable, Sendable, Equatable {
    public var pressSource: PressSource = .force
    public var pressCurve: PressCurve = .linear
    public var forceFloorGrams: Float = 0.0     // Minimum sensitivity threshold (grams)
    public var forceMaxGrams: Float = 320.0     // Full pressure saturation threshold (grams)
    public var areaFloor: Float = 0.0           // Capacitance area floor
    public var areaMax: Float = 0.0             // Capacitance area max (0 = auto-adjust)
    public var isCalibrated: Bool = false
    public var gateThresholdGrams: Float = 0.0  // Hysteresis threshold (0 = always triggered on contact)
    public var minLevel: Float = 0.12           // Minimum volume at lightest feather touch
    public var snapSpeedMs: Float = 120.0       // Time constant for magnetic scale attraction
    public var enableHaptics: Bool = true       // Tactile click on semitone crossing
    public var masterVolume: Float = 0.85

    // MIDI & MPE Configuration
    public var routingMode: OutputRoutingMode = .both
    public var midiMode: MIDIMode = .mpe
    public var mpeBendRange: Int = 48           // ±48 semitones (MPE industry standard)
    public var midiBaseChannel: Int = 1         // 1..16 (Ch 1 = MPE Global / Standard)
    public var sendMPECC74: Bool = true         // Y-axis to CC74 Timbre/Slide
    public var sendAftertouch: Bool = true      // Force Touch pressure to Channel Aftertouch
    public var selectedMIDIDestinationName: String = "Virtual Port (MacTrautonium MPE)"

    // Audio Output Configuration
    public var selectedAudioOutputDeviceUID: String = "" // Empty = System Default Output

    public init() {}
}
