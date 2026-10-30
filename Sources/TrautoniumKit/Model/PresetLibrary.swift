import Foundation

public struct PresetLibrary {
    public static let factoryPresets: [TrautoniumPatch] = [
        createMixturClassic(),
        createHitchcockBirds(),
        createDeepChurchOrgan(),
        createVocalChoir(),
        createCelloAndBass(),
        createSubharmonicBells()
    ]

    public static func createMixturClassic() -> TrautoniumPatch {
        var p = TrautoniumPatch()
        p.name = "Mixtur Classic (Sala)"
        p.isSplit = true
        p.reverbMix = 0.28
        p.echoMix = 0.0
        p.saturation = 0.15

        // Manual I
        p.manuals[0].lowNote = 57 // A3
        p.manuals[0].span = 2
        p.manuals[0].waveform = .sawtooth
        p.manuals[0].mainLevel = 0.8
        p.manuals[0].subDividers = [2, 3, 4, 5]
        p.manuals[0].subLevels = [0.55, 0.40, 0.30, 0.20]
        p.manuals[0].cutoff = 2400.0
        p.manuals[0].resonance = 0.15
        p.manuals[0].vowel = -1 // Raw subharmonics

        // Manual II
        p.manuals[1].lowNote = 45 // A2
        p.manuals[1].span = 2
        p.manuals[1].waveform = .neon
        p.manuals[1].mainLevel = 0.8
        p.manuals[1].subDividers = [2, 4, 6, 8]
        p.manuals[1].subLevels = [0.50, 0.50, 0.25, 0.25]
        p.manuals[1].vowel = 0 // "A" Formant
        p.manuals[1].register = 0 // Bass
        p.manuals[1].cutoff = 1500.0

        return p
    }

    public static func createHitchcockBirds() -> TrautoniumPatch {
        var p = TrautoniumPatch()
        p.name = "The Birds (Hitchcock)"
        p.isSplit = false // Single wide manual
        p.reverbMix = 0.45
        p.echoMix = 0.25
        p.echoTimeMs = 280.0
        p.echoFeedback = 0.45
        p.saturation = 0.35

        p.manuals[0].lowNote = 69 // A4
        p.manuals[0].span = 3 // 3 Octaves wide
        p.manuals[0].waveform = .neon
        p.manuals[0].mainLevel = 0.9
        p.manuals[0].subDividers = [2, 3, 7, 11]
        p.manuals[0].subLevels = [0.70, 0.60, 0.50, 0.40]
        p.manuals[0].cutoff = 3800.0
        p.manuals[0].resonance = 0.55
        p.manuals[0].pressureBrightness = 0.85
        p.manuals[0].noiseLevel = 0.12
        p.manuals[0].analogDrift = 0.45
        p.manuals[0].glideMs = 35.0

        return p
    }

    public static func createDeepChurchOrgan() -> TrautoniumPatch {
        var p = TrautoniumPatch()
        p.name = "Deep Cathedral Organ"
        p.isSplit = true
        p.reverbMix = 0.60
        p.echoMix = 0.0
        p.saturation = 0.20

        // Manual I: Reed Organ
        p.manuals[0].lowNote = 48 // C3
        p.manuals[0].span = 3
        p.manuals[0].waveform = .sawtooth
        p.manuals[0].subDividers = [2, 3, 4, 6]
        p.manuals[0].subLevels = [0.6, 0.5, 0.4, 0.3]
        p.manuals[0].cutoff = 1600.0
        p.manuals[0].attackMs = 25.0
        p.manuals[0].releaseMs = 350.0

        // Manual II: Sub-bass 32' Pedal
        p.manuals[1].lowNote = 24 // C1
        p.manuals[1].span = 2
        p.manuals[1].waveform = .neon
        p.manuals[1].subDividers = [2, 4, 8, 16]
        p.manuals[1].subLevels = [0.8, 0.7, 0.6, 0.5]
        p.manuals[1].cutoff = 800.0
        p.manuals[1].attackMs = 35.0
        p.manuals[1].releaseMs = 450.0

        return p
    }

    public static func createVocalChoir() -> TrautoniumPatch {
        var p = TrautoniumPatch()
        p.name = "Vocal Formant Choir"
        p.isSplit = true
        p.reverbMix = 0.40
        p.echoMix = 0.15
        p.echoTimeMs = 400.0
        p.echoFeedback = 0.30

        p.manuals[0].lowNote = 60 // C4
        p.manuals[0].span = 2
        p.manuals[0].waveform = .neon
        p.manuals[0].subDividers = [2, 3, 4, 5]
        p.manuals[0].subLevels = [0.5, 0.4, 0.3, 0.2]
        p.manuals[0].vowel = 1 // Vowel "E"
        p.manuals[0].register = 2 // Soprano
        p.manuals[0].cutoff = 2500.0
        p.manuals[0].attackMs = 40.0
        p.manuals[0].releaseMs = 200.0

        p.manuals[1].lowNote = 48 // C3
        p.manuals[1].span = 2
        p.manuals[1].waveform = .neon
        p.manuals[1].subDividers = [2, 4, 6, 8]
        p.manuals[1].subLevels = [0.6, 0.5, 0.3, 0.2]
        p.manuals[1].vowel = 3 // Vowel "O"
        p.manuals[1].register = 1 // Tenor
        p.manuals[1].cutoff = 2000.0
        p.manuals[1].attackMs = 45.0
        p.manuals[1].releaseMs = 220.0

        return p
    }

    public static func createCelloAndBass() -> TrautoniumPatch {
        var p = TrautoniumPatch()
        p.name = "Bowed Cello & Bass"
        p.isSplit = true
        p.reverbMix = 0.30
        p.echoMix = 0.0

        p.manuals[0].lowNote = 48 // C3
        p.manuals[0].span = 2
        p.manuals[0].waveform = .sawtooth
        p.manuals[0].subDividers = [2, 3, 4, 6]
        p.manuals[0].subLevels = [0.6, 0.3, 0.4, 0.2]
        p.manuals[0].cutoff = 1800.0
        p.manuals[0].pressureBrightness = 0.75
        p.manuals[0].attackMs = 15.0
        p.manuals[0].releaseMs = 150.0

        p.manuals[1].lowNote = 36 // C2
        p.manuals[1].span = 2
        p.manuals[1].waveform = .neon
        p.manuals[1].subDividers = [2, 4, 6, 8]
        p.manuals[1].subLevels = [0.7, 0.5, 0.3, 0.2]
        p.manuals[1].cutoff = 1200.0
        p.manuals[1].pressureBrightness = 0.80
        p.manuals[1].attackMs = 20.0
        p.manuals[1].releaseMs = 180.0

        return p
    }

    public static func createSubharmonicBells() -> TrautoniumPatch {
        var p = TrautoniumPatch()
        p.name = "Subharmonic Chimes & Bells"
        p.isSplit = false
        p.reverbMix = 0.55
        p.echoMix = 0.30
        p.echoTimeMs = 320.0
        p.echoFeedback = 0.45

        p.manuals[0].lowNote = 60 // C4
        p.manuals[0].span = 3
        p.manuals[0].waveform = .neon
        p.manuals[0].mainLevel = 0.7
        p.manuals[0].subDividers = [3, 5, 7, 9] // Inharmonic overtone simulation
        p.manuals[0].subLevels = [0.8, 0.6, 0.5, 0.4]
        p.manuals[0].cutoff = 3500.0
        p.manuals[0].resonance = 0.45
        p.manuals[0].attackMs = 2.0
        p.manuals[0].decayMs = 600.0
        p.manuals[0].sustain = 0.0 // Percussive strike!
        p.manuals[0].releaseMs = 800.0

        return p
    }

    // MARK: - User Presets Persistence

    public static var userPresetsDirectory: URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let dir = appSupport.appendingPathComponent("MacTrautonium/Presets", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func sanitizeFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let cleaned = name.components(separatedBy: invalidChars).joined(separator: "_")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func saveUserPreset(patch: TrautoniumPatch) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(patch)

        let safeName = sanitizeFilename(patch.name)
        let finalName = safeName.isEmpty ? "Untitled Preset" : safeName
        let fileURL = userPresetsDirectory.appendingPathComponent("\(finalName).json")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    public static func loadUserPresets() -> [TrautoniumPatch] {
        let dir = userPresetsDirectory
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }

        let decoder = JSONDecoder()
        var patches: [TrautoniumPatch] = []

        for fileURL in files where fileURL.pathExtension.lowercased() == "json" {
            if let data = try? Data(contentsOf: fileURL),
               let patch = try? decoder.decode(TrautoniumPatch.self, from: data) {
                patches.append(patch)
            }
        }

        return patches.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public static func deleteUserPreset(named name: String) -> Bool {
        let safeName = sanitizeFilename(name)
        let fileURL = userPresetsDirectory.appendingPathComponent("\(safeName).json")
        let fm = FileManager.default
        if fm.fileExists(atPath: fileURL.path) {
            do {
                try fm.removeItem(at: fileURL)
                return true
            } catch {
                return false
            }
        }
        return false
    }

    public static func isFactoryPreset(named name: String) -> Bool {
        return factoryPresets.contains { $0.name == name }
    }
}
