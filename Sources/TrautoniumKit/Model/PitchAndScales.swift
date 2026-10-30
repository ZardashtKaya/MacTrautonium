import Foundation

public enum ScaleCategory: String, CaseIterable, Sendable, Identifiable {
    case diatonic = "Diatonic & Modes"
    case melodicMinor = "Jazz & Melodic Minor"
    case harmonic = "Harmonic Modes"
    case pentatonic = "Pentatonic & Folk"
    case symmetric = "Symmetric & Modern"
    case world = "World, Maqams & Ragas"

    public var id: String { rawValue }
}

public struct ScaleDefinition: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let category: ScaleCategory
    public let mask: UInt16 // Bit k: 1 if pitch class (k semitones above tonic) is in scale

    public init(id: String, name: String, category: ScaleCategory, mask: UInt16) {
        self.id = id
        self.name = name
        self.category = category
        self.mask = mask
    }

    public init(id: String, name: String, category: ScaleCategory, semitones: [Int]) {
        self.id = id
        self.name = name
        self.category = category
        self.mask = semitones.reduce(0) { $0 | UInt16(1 << ($1 % 12)) }
    }

    public func contains(semitoneFromTonic: Int) -> Bool {
        let semi = ((semitoneFromTonic % 12) + 12) % 12
        return ((mask >> semi) & 1) != 0
    }

    public func notesSummary(tonic: Int) -> String {
        var names: [String] = []
        for semi in 0..<12 {
            if ((mask >> semi) & 1) != 0 {
                let pc = (tonic + semi) % 12
                names.append(Scales.tonicNames[pc])
            }
        }
        return names.joined(separator: ", ")
    }
}

public enum Scales {
    public static let tonicNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    public static let all: [ScaleDefinition] = [
        // 1. Diatonic & Modes
        ScaleDefinition(id: "chromatic", name: "Chromatic (All 12)", category: .diatonic, mask: 0x0FFF),
        ScaleDefinition(id: "major", name: "Ionian (Major)", category: .diatonic, semitones: [0, 2, 4, 5, 7, 9, 11]),
        ScaleDefinition(id: "dorian", name: "Dorian", category: .diatonic, semitones: [0, 2, 3, 5, 7, 9, 10]),
        ScaleDefinition(id: "phrygian", name: "Phrygian", category: .diatonic, semitones: [0, 1, 3, 5, 7, 8, 10]),
        ScaleDefinition(id: "lydian", name: "Lydian", category: .diatonic, semitones: [0, 2, 4, 6, 7, 9, 11]),
        ScaleDefinition(id: "mixolydian", name: "Mixolydian", category: .diatonic, semitones: [0, 2, 4, 5, 7, 9, 10]),
        ScaleDefinition(id: "minor", name: "Aeolian (Natural Minor)", category: .diatonic, semitones: [0, 2, 3, 5, 7, 8, 10]),
        ScaleDefinition(id: "locrian", name: "Locrian", category: .diatonic, semitones: [0, 1, 3, 5, 6, 8, 10]),

        // 2. Jazz & Melodic Minor Modes
        ScaleDefinition(id: "melodic_minor", name: "Melodic Minor (Jazz)", category: .melodicMinor, semitones: [0, 2, 3, 5, 7, 9, 11]),
        ScaleDefinition(id: "dorian_b2", name: "Dorian ♭2 (Phrygian ♮6)", category: .melodicMinor, semitones: [0, 1, 3, 5, 7, 9, 10]),
        ScaleDefinition(id: "lydian_aug", name: "Lydian Augmented (#5)", category: .melodicMinor, semitones: [0, 2, 4, 6, 8, 9, 11]),
        ScaleDefinition(id: "lydian_dom", name: "Lydian Dominant (Overtone)", category: .melodicMinor, semitones: [0, 2, 4, 6, 7, 9, 10]),
        ScaleDefinition(id: "mixolydian_b6", name: "Mixolydian ♭6 (Hindu)", category: .melodicMinor, semitones: [0, 2, 4, 5, 7, 8, 10]),
        ScaleDefinition(id: "locrian_sharp2", name: "Locrian ♮2 (Half-Dim)", category: .melodicMinor, semitones: [0, 2, 3, 5, 6, 8, 10]),
        ScaleDefinition(id: "altered", name: "Altered (Super Locrian)", category: .melodicMinor, semitones: [0, 1, 3, 4, 6, 8, 10]),

        // 3. Harmonic Modes
        ScaleDefinition(id: "harmonic_minor", name: "Harmonic Minor", category: .harmonic, semitones: [0, 2, 3, 5, 7, 8, 11]),
        ScaleDefinition(id: "dorian_sharp4", name: "Dorian #4 (Romanian)", category: .harmonic, semitones: [0, 2, 3, 6, 7, 9, 10]),
        ScaleDefinition(id: "phrygian_dom", name: "Phrygian Dominant (Spanish)", category: .harmonic, semitones: [0, 1, 4, 5, 7, 8, 10]),
        ScaleDefinition(id: "harmonic_major", name: "Harmonic Major", category: .harmonic, semitones: [0, 2, 4, 5, 7, 8, 11]),
        ScaleDefinition(id: "double_harmonic", name: "Double Harmonic (Byzantine)", category: .harmonic, semitones: [0, 1, 4, 5, 7, 8, 11]),
        ScaleDefinition(id: "hungarian_minor", name: "Hungarian Gypsy Minor", category: .harmonic, semitones: [0, 2, 3, 6, 7, 8, 11]),

        // 4. Pentatonic & Folk
        ScaleDefinition(id: "pent_major", name: "Major Pentatonic", category: .pentatonic, semitones: [0, 2, 4, 7, 9]),
        ScaleDefinition(id: "pent_minor", name: "Minor Pentatonic", category: .pentatonic, semitones: [0, 3, 5, 7, 10]),
        ScaleDefinition(id: "blues", name: "Blues Scale", category: .pentatonic, semitones: [0, 3, 5, 6, 7, 10]),
        ScaleDefinition(id: "major_blues", name: "Major Blues", category: .pentatonic, semitones: [0, 2, 3, 4, 7, 9]),
        ScaleDefinition(id: "insen", name: "Japanese Insen", category: .pentatonic, semitones: [0, 1, 5, 7, 10]),
        ScaleDefinition(id: "hirajoshi", name: "Japanese Hirajoshi", category: .pentatonic, semitones: [0, 2, 3, 7, 8]),
        ScaleDefinition(id: "kumoi", name: "Japanese Kumoi", category: .pentatonic, semitones: [0, 2, 3, 7, 9]),
        ScaleDefinition(id: "iwato", name: "Japanese Iwato", category: .pentatonic, semitones: [0, 1, 5, 6, 10]),
        ScaleDefinition(id: "pelog", name: "Balinese Pelog", category: .pentatonic, semitones: [0, 1, 3, 7, 8]),

        // 5. Symmetric & Modern
        ScaleDefinition(id: "whole_tone", name: "Whole Tone", category: .symmetric, semitones: [0, 2, 4, 6, 8, 10]),
        ScaleDefinition(id: "dim_half_whole", name: "Diminished (Half-Whole)", category: .symmetric, semitones: [0, 1, 3, 4, 6, 7, 9, 10]),
        ScaleDefinition(id: "dim_whole_half", name: "Diminished (Whole-Half)", category: .symmetric, semitones: [0, 2, 3, 5, 6, 8, 9, 11]),
        ScaleDefinition(id: "augmented", name: "Augmented (Hexatonic)", category: .symmetric, semitones: [0, 3, 4, 7, 8, 11]),
        ScaleDefinition(id: "prometheus", name: "Prometheus (Scriabin)", category: .symmetric, semitones: [0, 2, 4, 6, 9, 10]),
        ScaleDefinition(id: "enigmatic", name: "Enigmatic (Verdi)", category: .symmetric, semitones: [0, 1, 4, 6, 8, 10, 11]),

        // 6. World, Maqams & Ragas
        ScaleDefinition(id: "maqam_hijaz", name: "Maqam Hijaz", category: .world, semitones: [0, 1, 4, 5, 7, 8, 10]),
        ScaleDefinition(id: "maqam_bayati", name: "Maqam Bayati (12TET)", category: .world, semitones: [0, 2, 3, 5, 7, 8, 10]),
        ScaleDefinition(id: "maqam_saba", name: "Maqam Saba", category: .world, semitones: [0, 1, 3, 4, 7, 8, 10]),
        ScaleDefinition(id: "raga_bhairav", name: "Raga Bhairav", category: .world, semitones: [0, 1, 4, 5, 7, 8, 11]),
        ScaleDefinition(id: "raga_todi", name: "Raga Todi", category: .world, semitones: [0, 1, 3, 6, 7, 8, 11]),
        ScaleDefinition(id: "raga_yaman", name: "Raga Yaman (Kalyan)", category: .world, semitones: [0, 2, 4, 6, 7, 9, 11]),
    ]

    public static func contains(note: Int, scaleIndex: Int, tonic: Int) -> Bool {
        let s = max(0, min(scaleIndex, all.count - 1))
        let pc = ((note % 12) + 12) % 12
        let relPc = ((pc - (tonic % 12)) + 12) % 12
        return ((all[s].mask >> relPc) & 1) != 0
    }

    public static func nearest(note: Float, scaleIndex: Int, tonic: Int) -> Float {
        let base = Int(round(note))
        var best = Float(base)
        var minDiff: Float = 1e9

        for delta in -7...7 {
            let candidate = base + delta
            if contains(note: candidate, scaleIndex: scaleIndex, tonic: tonic) {
                let diff = abs(Float(candidate) - note)
                if diff < minDiff {
                    minDiff = diff
                    best = Float(candidate)
                }
            }
        }
        return best
    }

    public static func noteName(for midiNote: Float) -> String {
        let rounded = Int(round(midiNote))
        let clamped = max(0, min(127, rounded))
        let pc = clamped % 12
        let octave = (clamped / 12) - 1
        return "\(tonicNames[pc])\(octave)"
    }

    public static func centsOffset(fromExactMidi midiNote: Float) -> Int {
        let rounded = round(midiNote)
        let cents = Int(round((midiNote - rounded) * 100.0))
        return cents
    }

    public static func scales(for category: ScaleCategory) -> [(index: Int, scale: ScaleDefinition)] {
        all.enumerated().compactMap { index, scale in
            scale.category == category ? (index, scale) : nil
        }
    }
}

public struct PitchRibbon {
    public static let padEdgeMargin: Float = 0.03

    /// Converts normalized horizontal trackpad position (0.0 to 1.0) to raw continuous MIDI pitch.
    public static func xToMidi(x: Float, lowNote: Int, spanOctaves: Int) -> Float {
        let u = max(0.0, min(1.0, (x - padEdgeMargin) / (1.0 - 2.0 * padEdgeMargin)))
        let semitones = u * Float(spanOctaves * 12)
        return Float(lowNote) + semitones
    }
}

/// Tracks touch pitch smoothing, speed calculation, and soft magnetic attraction
public struct PitchTracker: Sendable {
    public var rawNote: Float = 0
    public var smoothedNote: Float = 0
    public var previousSmoothed: Float = 0
    public var slidingSpeed: Float = 0 // semitones per second
    public var attractionOffset: Float = 0
    public var finalPitch: Float = 0
    public var isFresh: Bool = true
    public var lastDiscreteSemitone: Int = -1

    public init() {}

    public mutating func update(
        raw: Float,
        dt: Float,
        snapMode: SnapMode,
        scaleIndex: Int,
        tonic: Int,
        snapSpeedMs: Float
    ) -> Bool {
        rawNote = raw

        var crossedSemitone = false
        let currentSemitone = Int(round(raw))
        if lastDiscreteSemitone != -1 && currentSemitone != lastDiscreteSemitone {
            crossedSemitone = true
        }
        lastDiscreteSemitone = currentSemitone

        if snapMode == .hard {
            finalPitch = Scales.nearest(note: raw, scaleIndex: scaleIndex, tonic: tonic)
            attractionOffset = 0
            return crossedSemitone
        }

        if snapMode == .off {
            finalPitch = raw
            attractionOffset = 0
            return crossedSemitone
        }

        // Soft magnetic attraction mode
        if isFresh {
            smoothedNote = raw
            previousSmoothed = raw
            slidingSpeed = 0
            attractionOffset = Scales.nearest(note: raw, scaleIndex: scaleIndex, tonic: tonic) - raw
            isFresh = false
        } else {
            previousSmoothed = smoothedNote
            let smoothCoeff = 1.0 - exp(-dt / 0.10)
            smoothedNote += (raw - smoothedNote) * smoothCoeff

            let instantSpeed = abs(smoothedNote - previousSmoothed) / max(0.001, dt)
            let speedCoeff = 1.0 - exp(-dt / 0.03)
            slidingSpeed += (instantSpeed - slidingSpeed) * speedCoeff

            let targetOffset: Float
            let tau: Float
            if slidingSpeed > 3.5 {
                // Moving fast: release magnetic lock completely for natural glissando / vibrato
                targetOffset = 0.0
                tau = 0.03
            } else {
                // Moving slowly or resting: gently pull toward nearest in-scale note
                targetOffset = Scales.nearest(note: smoothedNote, scaleIndex: scaleIndex, tonic: tonic) - smoothedNote
                tau = max(0.005, snapSpeedMs * 0.001)
            }

            let attractCoeff = 1.0 - exp(-dt / tau)
            attractionOffset += (targetOffset - attractionOffset) * attractCoeff
        }

        finalPitch = raw + attractionOffset
        return crossedSemitone
    }
}
