import Foundation
import AppKit

public final class TrautoniumPluginEngine: @unchecked Sendable {
    public private(set) var sampleRate: Float = 48000.0
    public let voiceManager: VoiceManager
    public let delayEffect: StereoDelay
    public let reverbEffect: StereoReverb
    public let scopeBuffer: ScopeRingBuffer

    private let stateLock = NSLock()
    public var patch: TrautoniumPatch {
        didSet {
            stateLock.lock()
            cachedPatch = patch
            stateLock.unlock()
        }
    }
    public var prefs: TrautoniumPrefs {
        didSet {
            stateLock.lock()
            cachedPrefs = prefs
            stateLock.unlock()
        }
    }

    private var cachedPatch: TrautoniumPatch
    private var cachedPrefs: TrautoniumPrefs

    private var tempLeftBuffer: [Float]
    private var tempRightBuffer: [Float]

    // MIDI & MPE state
    private struct ActiveNote {
        let channel: Int
        let note: Int
        let manual: Int
        let baseMidi: Float
    }
    private var activeNotes: [Int: ActiveNote] = [:] // key: owner
    private var channelBends: [Int: Float] = [:]     // key: channel (1..16), value: semitones
    private var channelPressures: [Int: Float] = [:] // key: channel (1..16)

    public var mpeBendRange: Float = 48.0
    public var standardBendRange: Float = 2.0

    private var currentPeakL: Float = 0
    private var currentPeakR: Float = 0

    public init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
        self.voiceManager = VoiceManager(sampleRate: sampleRate)
        self.delayEffect = StereoDelay(sampleRate: sampleRate)
        self.reverbEffect = StereoReverb(sampleRate: sampleRate)
        self.scopeBuffer = ScopeRingBuffer(capacity: 2048)

        let p = TrautoniumPatch()
        let pf = TrautoniumPrefs()
        self.patch = p
        self.prefs = pf
        self.cachedPatch = p
        self.cachedPrefs = pf

        self.tempLeftBuffer = [Float](repeating: 0, count: 4096)
        self.tempRightBuffer = [Float](repeating: 0, count: 4096)
    }

    public func setSampleRate(_ newRate: Float) {
        guard newRate > 0 else { return }
        stateLock.lock()
        sampleRate = newRate
        voiceManager.setSampleRate(newRate)
        delayEffect.setSampleRate(newRate)
        reverbEffect.setSampleRate(newRate)
        stateLock.unlock()
    }

    public func getPeakLevels() -> (left: Float, right: Float) {
        stateLock.lock()
        defer { stateLock.unlock() }
        return (currentPeakL, currentPeakR)
    }

    // MARK: - MIDI / MPE Handling

    public func noteOn(channel: Int, note: Int, velocity: Float) {
        stateLock.lock()
        let patch = cachedPatch
        let isMPE = channel >= 2 && channel <= 16
        let owner = isMPE ? (10000 + channel) : (20000 + (channel * 128 + note))

        let manual: Int
        if patch.isSplit {
            manual = note < 60 ? 0 : 1
        } else {
            manual = 0
        }

        let bendOffset = channelBends[channel] ?? 0.0
        let baseMidi = Float(note)
        let soundingMidi = baseMidi + bendOffset

        activeNotes[owner] = ActiveNote(channel: channel, note: note, manual: manual, baseMidi: baseMidi)
        stateLock.unlock()

        voiceManager.noteOn(
            owner: owner,
            manual: manual,
            midiNote: soundingMidi,
            velocity: max(0.01, min(1.0, velocity)),
            minLevel: 0.0
        )
    }

    public func noteOff(channel: Int, note: Int) {
        stateLock.lock()
        let isMPE = channel >= 2 && channel <= 16
        let owner = isMPE ? (10000 + channel) : (20000 + (channel * 128 + note))
        activeNotes.removeValue(forKey: owner)
        stateLock.unlock()

        voiceManager.noteOff(owner: owner)
    }

    public func pitchBend(channel: Int, bend14: Int) {
        let isMPE = channel >= 2 && channel <= 16
        let range = isMPE ? mpeBendRange : standardBendRange
        let norm: Float = bend14 >= 8192 ? Float(bend14 - 8192) / 8191.0 : Float(bend14 - 8192) / 8192.0
        let semitones = norm * range

        stateLock.lock()
        channelBends[channel] = semitones

        var updates: [(owner: Int, pitch: Float)] = []
        for (owner, info) in activeNotes where info.channel == channel {
            updates.append((owner, info.baseMidi + semitones))
        }
        stateLock.unlock()

        for u in updates {
            voiceManager.updatePitch(owner: u.owner, newMidiNote: u.pitch)
        }
    }

    public func pressure(channel: Int, note: Int?, pressure: Float) {
        let p = max(0.0, min(1.0, pressure))
        stateLock.lock()
        channelPressures[channel] = p

        var ownersToUpdate: [Int] = []
        let isMPE = channel >= 2 && channel <= 16
        if isMPE {
            ownersToUpdate.append(10000 + channel)
        } else if let n = note {
            ownersToUpdate.append(20000 + (channel * 128 + n))
        } else {
            for (owner, info) in activeNotes where info.channel == channel {
                ownersToUpdate.append(owner)
            }
        }
        stateLock.unlock()

        for owner in ownersToUpdate {
            voiceManager.updatePressure(owner: owner, pressure: p)
        }
    }

    public func cc(channel: Int, cc: Int, value: Int) {
        let valNorm = Float(max(0, min(127, value))) / 127.0
        switch cc {
        case 74: // MPE Slide / Timbre -> Modulates manual filter cutoff
            stateLock.lock()
            var p = cachedPatch
            p.manuals[0].cutoff = 400.0 + valNorm * 4600.0
            if p.isSplit {
                p.manuals[1].cutoff = 400.0 + valNorm * 4600.0
            }
            cachedPatch = p
            stateLock.unlock()
        case 7: // Master Volume
            stateLock.lock()
            var pf = cachedPrefs
            pf.masterVolume = valNorm
            cachedPrefs = pf
            stateLock.unlock()
        case 120, 123: // All Sound Off / All Notes Off
            allNotesOff()
        default:
            break
        }
    }

    public func allNotesOff() {
        stateLock.lock()
        activeNotes.removeAll()
        stateLock.unlock()
        voiceManager.allNotesOff()
    }

    public func panic() {
        stateLock.lock()
        activeNotes.removeAll()
        channelBends.removeAll()
        channelPressures.removeAll()
        stateLock.unlock()
        voiceManager.panic()
        delayEffect.reset()
        reverbEffect.reset()
    }

    // MARK: - Audio Rendering

    public func render(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frameCount: Int) {
        stateLock.lock()
        let activePatch = cachedPatch
        let activePrefs = cachedPrefs
        stateLock.unlock()

        if tempLeftBuffer.count < frameCount {
            tempLeftBuffer = [Float](repeating: 0, count: frameCount)
            tempRightBuffer = [Float](repeating: 0, count: frameCount)
        }

        tempLeftBuffer.withUnsafeMutableBufferPointer { leftPtr in
            tempRightBuffer.withUnsafeMutableBufferPointer { rightPtr in
                voiceManager.render(
                    patch: activePatch,
                    leftOut: leftPtr.baseAddress!,
                    rightOut: rightPtr.baseAddress!,
                    frameCount: frameCount,
                    sampleRate: sampleRate
                )
            }
        }

        let masterVol = activePrefs.masterVolume
        let satDrive = activePatch.saturation
        let delayMix = activePatch.echoMix
        let delayTime = activePatch.echoTimeMs
        let delayFb = activePatch.echoFeedback
        let revMix = activePatch.reverbMix

        var maxL: Float = 0
        var maxR: Float = 0

        for i in 0..<frameCount {
            var sL = Saturation.process(sample: tempLeftBuffer[i], drive: satDrive)
            var sR = Saturation.process(sample: tempRightBuffer[i], drive: satDrive)

            let (dL, dR) = delayEffect.process(
                inL: sL,
                inR: sR,
                mix: delayMix,
                timeMs: delayTime,
                feedback: delayFb
            )
            sL = dL
            sR = dR

            let (rL, rR) = reverbEffect.process(inL: sL, inR: sR, mix: revMix)
            sL = rL
            sR = rR

            sL *= masterVol
            sR *= masterVol

            if sL > 1.0 { sL = 1.0 } else if sL < -1.0 { sL = -1.0 }
            if sR > 1.0 { sR = 1.0 } else if sR < -1.0 { sR = -1.0 }

            left[i] = sL
            right[i] = sR

            let absL = abs(sL)
            let absR = abs(sR)
            if absL > maxL { maxL = absL }
            if absR > maxR { maxR = absR }
        }

        stateLock.lock()
        currentPeakL = max(maxL, currentPeakL * 0.88)
        currentPeakR = max(maxR, currentPeakR * 0.88)
        stateLock.unlock()

        scopeBuffer.write(samples: left, count: frameCount)
    }
}
