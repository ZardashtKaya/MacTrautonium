import Foundation

public struct SynthTouchSnapshot: Identifiable, Sendable {
    public let id: Int
    public let manual: Int
    public let x: Float
    public let y: Float
    public let pressureGrams: Float
    public let normalizedPressure: Float
    public let rawMidi: Float
    public let soundingMidi: Float
    public let isGateOn: Bool

    public init(
        id: Int,
        manual: Int,
        x: Float,
        y: Float,
        pressureGrams: Float,
        normalizedPressure: Float,
        rawMidi: Float,
        soundingMidi: Float,
        isGateOn: Bool
    ) {
        self.id = id
        self.manual = manual
        self.x = x
        self.y = y
        self.pressureGrams = pressureGrams
        self.normalizedPressure = normalizedPressure
        self.rawMidi = rawMidi
        self.soundingMidi = soundingMidi
        self.isGateOn = isGateOn
    }
}

public final class VoiceManager: @unchecked Sendable {
    public static let maxVoices = 16
    public static let monoOwnerBase = 8000

    public let voices: [SynthVoice]
    private var formantBanks: [FormantBank]
    private var manualBuffers: [[Float]]

    private let lock = NSLock()
    private var touchSnapshots: [SynthTouchSnapshot] = []
    private var touchGateStates: [Int: Bool] = [:]

    public init(sampleRate: Float = 48000.0) {
        self.voices = (0..<Self.maxVoices).map { _ in SynthVoice() }
        self.formantBanks = [FormantBank(sampleRate: sampleRate), FormantBank(sampleRate: sampleRate)]
        self.manualBuffers = [
            [Float](repeating: 0, count: 4096),
            [Float](repeating: 0, count: 4096)
        ]
    }

    public func setSampleRate(_ newRate: Float) {
        lock.lock()
        defer { lock.unlock() }
        for fb in formantBanks {
            fb.setSampleRate(newRate)
        }
    }

    public func findVoice(owner: Int) -> SynthVoice? {
        for v in voices where v.isActive && v.ownerId == owner {
            return v
        }
        return nil
    }

    public func allocateVoice() -> SynthVoice {
        for v in voices where !v.isActive {
            return v
        }
        // Steal the quietest voice currently releasing
        var bestReleasing: SynthVoice?
        for v in voices where !v.isGateOn {
            if bestReleasing == nil || v.envelope < bestReleasing!.envelope {
                bestReleasing = v
            }
        }
        if let stolen = bestReleasing { return stolen }

        // Otherwise steal the voice with lowest overall level * envelope
        var quietest = voices[0]
        for v in voices.dropFirst() {
            if (v.currentLevel * v.envelope) < (quietest.currentLevel * quietest.envelope) {
                quietest = v
            }
        }
        return quietest
    }

    public func noteOn(owner: Int, manual: Int, midiNote: Float, velocity: Float, minLevel: Float = 0.0) {
        lock.lock()
        defer { lock.unlock() }

        let voice: SynthVoice
        if let existing = findVoice(owner: owner) {
            voice = existing
        } else {
            voice = allocateVoice()
        }

        voice.trigger(
            owner: owner,
            manual: manual,
            midiNote: midiNote,
            pressure: velocity,
            touchId: owner,
            minLevel: minLevel
        )
    }

    public func noteOff(owner: Int) {
        lock.lock()
        defer { lock.unlock() }

        if let v = findVoice(owner: owner) {
            v.releaseGate()
        }
    }

    public func updatePitch(owner: Int, newMidiNote: Float) {
        lock.lock()
        defer { lock.unlock() }

        if let v = findVoice(owner: owner) {
            v.targetLogHz = SynthVoice.noteToLog2Hz(newMidiNote)
        }
    }

    public func updatePressure(owner: Int, pressure: Float) {
        lock.lock()
        defer { lock.unlock() }

        if let v = findVoice(owner: owner) {
            v.normalizedPressure += (pressure - v.normalizedPressure) * 0.35
            v.targetLevel = max(0.0, min(1.0, pressure))
        }
    }

    public func allNotesOff() {
        lock.lock()
        defer { lock.unlock() }

        for v in voices {
            v.releaseGate()
        }
    }

    public func panic() {
        lock.lock()
        defer { lock.unlock() }

        for v in voices {
            v.reset()
        }
        for fb in formantBanks {
            fb.reset()
        }
    }

    public func updateTouches(
        touches: [TouchPoint],
        patch: TrautoniumPatch,
        prefs: TrautoniumPrefs,
        pitchTrackers: inout [Int: PitchTracker],
        dt: Float,
        onCrossedSemitone: @escaping (Float) -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }

        // Clear claim flags
        for v in voices { v.isClaimed = false }

        var newSnapshots: [SynthTouchSnapshot] = []

        for touch in touches {
            let manual = patch.isSplit ? (touch.y < 0.5 ? 0 : 1) : 0
            let manualParams = patch.manuals[manual]

            // Calculate continuous pitch
            let rawNote = PitchRibbon.xToMidi(
                x: touch.x,
                lowNote: manualParams.lowNote,
                spanOctaves: manualParams.span
            )

            // Update pitch tracker with soft attraction
            var tracker = pitchTrackers[touch.id] ?? PitchTracker()
            let crossed = tracker.update(
                raw: rawNote,
                dt: dt,
                snapMode: manualParams.snapMode,
                scaleIndex: patch.scaleIndex,
                tonic: patch.tonic,
                snapSpeedMs: prefs.snapSpeedMs
            )
            pitchTrackers[touch.id] = tracker

            if crossed && prefs.enableHaptics {
                onCrossedSemitone(tracker.finalPitch)
            }

            // Pressure Gate with Schmitt-trigger hysteresis: wire touching rail
            var gate = true
            let threshold = prefs.gateThresholdGrams
            if prefs.pressSource == .force && threshold > 0 {
                let wasGateOn = touchGateStates[touch.id] ?? false
                if wasGateOn {
                    // Release hysteresis: must drop below 60% of threshold to close gate
                    gate = touch.pressureGrams >= (threshold * 0.6)
                } else {
                    // Attack threshold: must reach 100% of threshold to open gate
                    gate = touch.pressureGrams >= threshold
                }
            }
            touchGateStates[touch.id] = gate

            if gate {
                let owner = manualParams.isMono ? (Self.monoOwnerBase + manual) : touch.id
                let voice: SynthVoice
                if let existing = findVoice(owner: owner) {
                    voice = existing
                } else {
                    voice = allocateVoice()
                }

                voice.trigger(
                    owner: owner,
                    manual: manual,
                    midiNote: tracker.finalPitch,
                    pressure: touch.normalizedPressure,
                    touchId: touch.id,
                    minLevel: prefs.minLevel
                )
            }

            newSnapshots.append(SynthTouchSnapshot(
                id: touch.id,
                manual: manual,
                x: touch.x,
                y: touch.y,
                pressureGrams: touch.pressureGrams,
                normalizedPressure: touch.normalizedPressure,
                rawMidi: tracker.rawNote,
                soundingMidi: tracker.finalPitch,
                isGateOn: gate
            ))
        }

        // Release voices that were not claimed by any active touch
        for v in voices where v.isActive && !v.isClaimed {
            v.releaseGate()
        }

        // Clean up hysteresis states for removed touches
        let activeTouchIds = Set(touches.map { $0.id })
        touchGateStates = touchGateStates.filter { activeTouchIds.contains($0.key) }

        self.touchSnapshots = newSnapshots
    }

    public func getSnapshots() -> [SynthTouchSnapshot] {
        lock.lock()
        defer { lock.unlock() }
        return touchSnapshots
    }

    /// Render all polyphonic voices for both manuals, process formants, and write stereo mix
    public func render(
        patch: TrautoniumPatch,
        leftOut: UnsafeMutablePointer<Float>,
        rightOut: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sampleRate: Float
    ) {
        lock.lock()
        defer { lock.unlock() }

        // Ensure manual accumulation buffers are large enough
        if manualBuffers[0].count < frameCount {
            manualBuffers[0] = [Float](repeating: 0, count: frameCount)
            manualBuffers[1] = [Float](repeating: 0, count: frameCount)
        }

        // Clear manual buffers
        manualBuffers[0].withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }
        manualBuffers[1].withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }

        // Render each active voice into its corresponding manual buffer
        for v in voices where v.isActive {
            let m = max(0, min(1, v.manualIndex))
            let params = patch.manuals[m]
            manualBuffers[m].withUnsafeMutableBufferPointer { ptr in
                v.render(params: params, buffer: ptr.baseAddress!, frameCount: frameCount, sampleRate: sampleRate)
            }
        }

        // Apply manual volume and Formant Filter bank
        for i in 0..<frameCount {
            var m0Sample = manualBuffers[0][i] * patch.manuals[0].volume
            var m1Sample = manualBuffers[1][i] * patch.manuals[1].volume

            // Formants for Manual I
            m0Sample = formantBanks[0].process(
                sample: m0Sample,
                vowel: patch.manuals[0].vowel,
                register: patch.manuals[0].register
            )

            // Formants for Manual II
            m1Sample = formantBanks[1].process(
                sample: m1Sample,
                vowel: patch.manuals[1].vowel,
                register: patch.manuals[1].register
            )

            // Stereo staging: Manual I slightly left-panned, Manual II slightly right-panned
            let outL = m0Sample * 0.85 + m1Sample * 0.45
            let outR = m0Sample * 0.45 + m1Sample * 0.85

            leftOut[i] = outL
            rightOut[i] = outR
        }
    }
}
