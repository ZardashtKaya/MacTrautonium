import Foundation
import AVFoundation

public final class AudioEngineController: @unchecked Sendable {
    public static let shared = AudioEngineController()

    public let sampleRate: Float = 48000.0
    private var audioEngine: AVAudioEngine
    private var sourceNode: AVAudioSourceNode?

    public let voiceManager: VoiceManager
    public let delayEffect: StereoDelay
    public let reverbEffect: StereoReverb
    public let scopeBuffer: ScopeRingBuffer
    public let audioRecorder: AudioRecorder

    private var pitchTrackers: [Int: PitchTracker] = [:]
    private var tempLeftBuffer: [Float]
    private var tempRightBuffer: [Float]

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
    public private(set) var isRunning: Bool = false

    private var currentPeakL: Float = 0
    private var currentPeakR: Float = 0

    public func getPeakLevels() -> (left: Float, right: Float) {
        stateLock.lock()
        defer { stateLock.unlock() }
        return (currentPeakL, currentPeakR)
    }

    private init() {
        self.audioEngine = AVAudioEngine()
        self.voiceManager = VoiceManager(sampleRate: sampleRate)
        self.delayEffect = StereoDelay(sampleRate: sampleRate)
        self.reverbEffect = StereoReverb(sampleRate: sampleRate)
        self.scopeBuffer = ScopeRingBuffer(capacity: 2048)
        self.audioRecorder = AudioRecorder()

        let p = TrautoniumPatch()
        let pf = TrautoniumPrefs()
        self.patch = p
        self.prefs = pf
        self.cachedPatch = p
        self.cachedPrefs = pf

        self.tempLeftBuffer = [Float](repeating: 0, count: 4096)
        self.tempRightBuffer = [Float](repeating: 0, count: 4096)

        setupAudioEngine()
    }

    private func setupAudioEngine() {
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 2)!

        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            self.processAudioBlock(audioBufferList: audioBufferList, frameCount: Int(frameCount))
            return noErr
        }

        self.sourceNode = node
        audioEngine.attach(node)
        audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)
    }

    public func start() throws {
        guard !isRunning else { return }
        try audioEngine.start()
        isRunning = true
        TouchInputManager.shared.start()
        print("[AudioEngineController] Started AVAudioEngine at \(sampleRate) Hz")
    }

    public func stop() {
        guard isRunning else { return }
        audioEngine.stop()
        TouchInputManager.shared.stop()
        MIDIManager.shared.silenceAllVoices()
        isRunning = false
    }

    private func processAudioBlock(audioBufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: Int) {
        stateLock.lock()
        let activePatch = cachedPatch
        let activePrefs = cachedPrefs
        stateLock.unlock()

        // Ensure temp working buffers are adequate
        if tempLeftBuffer.count < frameCount {
            tempLeftBuffer = [Float](repeating: 0, count: frameCount)
            tempRightBuffer = [Float](repeating: 0, count: frameCount)
        }

        let dt = Float(frameCount) / sampleRate

        // Fetch active touches from Multitouch / Fallbacks
        let touches = TouchInputManager.shared.getActiveTouches(prefs: activePrefs)

        // Update voice allocation and magnetic scale attraction
        voiceManager.updateTouches(
            touches: touches,
            patch: activePatch,
            prefs: activePrefs,
            pitchTrackers: &pitchTrackers,
            dt: dt,
            onCrossedSemitone: { _ in
                if activePrefs.enableHaptics {
                    MultitouchBridge.shared.triggerHaptic(strength: 2)
                }
            }
        )

        // Clean up pitch trackers for removed touches
        let activeTouchIds = Set(touches.map { $0.id })
        pitchTrackers = pitchTrackers.filter { activeTouchIds.contains($0.key) }

        // Process MIDI Out / MPE
        let routing = activePrefs.routingMode
        let snapshots = voiceManager.getSnapshots()
        if routing == .midiOut || routing == .both {
            MIDIManager.shared.processSnapshots(snapshots, prefs: activePrefs)
        } else {
            MIDIManager.shared.silenceAllVoices()
        }

        let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
        guard let mDataL = abl[0].mData, let mDataR = abl[1].mData else { return }
        let outL = mDataL.assumingMemoryBound(to: Float.self)
        let outR = mDataR.assumingMemoryBound(to: Float.self)

        // In MIDI Out mode, mute internal synth synthesis and output silence
        if routing == .midiOut {
            outL.initialize(repeating: 0, count: frameCount)
            outR.initialize(repeating: 0, count: frameCount)

            stateLock.lock()
            currentPeakL = currentPeakL * 0.85
            currentPeakR = currentPeakR * 0.85
            stateLock.unlock()

            scopeBuffer.write(samples: outL, count: frameCount)
            return
        }

        // Render synth voices into temporary left and right buffers
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

        // Apply Master Effects (Saturation, Tape Delay, Stereo Reverb, Master Volume)
        let masterVol = activePrefs.masterVolume
        let satDrive = activePatch.saturation
        let delayMix = activePatch.echoMix
        let delayTime = activePatch.echoTimeMs
        let delayFb = activePatch.echoFeedback
        let revMix = activePatch.reverbMix

        var maxL: Float = 0
        var maxR: Float = 0

        for i in 0..<frameCount {
            // Warm analog saturation
            var sL = Saturation.process(sample: tempLeftBuffer[i], drive: satDrive)
            var sR = Saturation.process(sample: tempRightBuffer[i], drive: satDrive)

            // Stereo tape delay
            let (dL, dR) = delayEffect.process(
                inL: sL,
                inR: sR,
                mix: delayMix,
                timeMs: delayTime,
                feedback: delayFb
            )
            sL = dL
            sR = dR

            // Stereo Reverb
            let (rL, rR) = reverbEffect.process(inL: sL, inR: sR, mix: revMix)
            sL = rL
            sR = rR

            // Master Volume
            sL *= masterVol
            sR *= masterVol

            // Soft clamp to prevent DAC digital clipping
            let clampedL = max(-1.0, min(1.0, sL))
            let clampedR = max(-1.0, min(1.0, sR))
            outL[i] = clampedL
            outR[i] = clampedR

            let absL = abs(clampedL)
            let absR = abs(clampedR)
            if absL > maxL { maxL = absL }
            if absR > maxR { maxR = absR }
        }

        // Smoothly decay peak meters
        stateLock.lock()
        currentPeakL = max(maxL, currentPeakL * 0.85)
        currentPeakR = max(maxR, currentPeakR * 0.85)
        stateLock.unlock()

        // Write snapshot to oscilloscope visualizer
        scopeBuffer.write(samples: outL, count: frameCount)

        // Write to WAV recorder if active
        if audioRecorder.isRecording {
            audioRecorder.append(left: outL, right: outR, count: frameCount)
        }
    }
}
