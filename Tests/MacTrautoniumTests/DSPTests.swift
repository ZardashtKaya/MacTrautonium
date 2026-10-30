import XCTest
@testable import TrautoniumKit

final class DSPTests: XCTestCase {
    func testStateVariableFilterStability() {
        var svf = StateVariableFilter()
        let sampleRate: Float = 48000.0

        // Test at normal and extreme frequencies
        let testCutoffs: [Float] = [20.0, 440.0, 1000.0, 10000.0, 22000.0]
        for fc in testCutoffs {
            let coeffs = StateVariableFilter.Coefficients(cutoffHz: fc, resonance: 0.85, sampleRate: sampleRate)
            svf.reset()

            // Run 1000 samples with an impulse
            var input: Float = 1.0
            for _ in 0..<1000 {
                let (lp, bp) = svf.process(input: input, coefficients: coeffs)
                XCTAssertFalse(lp.isNaN, "SVF produced NaN at fc=\(fc)")
                XCTAssertFalse(lp.isInfinite, "SVF produced Inf at fc=\(fc)")
                XCTAssertFalse(bp.isNaN, "SVF produced NaN at fc=\(fc)")
                XCTAssertFalse(bp.isInfinite, "SVF produced Inf at fc=\(fc)")
                input = 0.0 // Impulse
            }
        }
    }

    func testFormantFilterVowels() {
        let fbank = FormantBank(sampleRate: 48000.0)
        let sample: Float = 0.5

        for reg in 0..<3 {
            for vow in 0..<5 {
                let out = fbank.process(sample: sample, vowel: vow, register: reg)
                XCTAssertFalse(out.isNaN, "Formant bank produced NaN for vowel \(vow), reg \(reg)")
                XCTAssertFalse(out.isInfinite, "Formant bank produced Inf for vowel \(vow), reg \(reg)")
            }
        }

        // Test bypass when vowel is -1 (Off)
        let bypassed = fbank.process(sample: 0.42, vowel: -1, register: 0)
        XCTAssertEqual(bypassed, 0.42, accuracy: 1e-6)
    }

    func testSynthVoiceLifecycle() {
        let voice = SynthVoice()
        XCTAssertFalse(voice.isActive)

        voice.trigger(owner: 101, manual: 0, midiNote: 69.0, pressure: 0.5, touchId: 101, minLevel: 0.1)
        XCTAssertTrue(voice.isActive)
        XCTAssertTrue(voice.isGateOn)

        var buffer = [Float](repeating: 0, count: 256)
        var params = ManualParams()
        params.attackMs = 5.0
        params.sustain = 1.0

        buffer.withUnsafeMutableBufferPointer { ptr in
            voice.render(params: params, buffer: ptr.baseAddress!, frameCount: 256, sampleRate: 48000.0)
        }

        // Voice should produce non-zero audio output
        let energy = buffer.reduce(0) { $0 + abs($1) }
        XCTAssertGreaterThan(energy, 0.0, "Synth voice produced silent output")

        // Release gate
        voice.releaseGate()
        XCTAssertFalse(voice.isGateOn)
    }

    func testSaturationSoftKnee() {
        // Linear region near zero
        let smallOut = Saturation.process(sample: 0.1, drive: 0.2)
        XCTAssertEqual(smallOut, 0.14, accuracy: 0.05)

        // Saturated region clamps cleanly to 1.0
        let bigOut = Saturation.process(sample: 5.0, drive: 0.5)
        XCTAssertEqual(bigOut, 1.0, accuracy: 1e-4)

        let negativeOut = Saturation.process(sample: -5.0, drive: 0.5)
        XCTAssertEqual(negativeOut, -1.0, accuracy: 1e-4)
    }

    func testRapidSwipeAntiCracklingStress() {
        let voiceManager = VoiceManager(sampleRate: 48000.0)
        var patch = TrautoniumPatch()
        patch.manuals[0].lowNote = 36
        patch.manuals[0].span = 4 // 4 octaves = 48 semitones
        patch.manuals[0].cutoff = 4000.0
        patch.manuals[0].resonance = 0.7

        var prefs = TrautoniumPrefs()
        prefs.gateThresholdGrams = 10.0

        var pitchTrackers: [Int: PitchTracker] = [:]
        let frameCount = 256
        var leftBuf = [Float](repeating: 0, count: frameCount)
        var rightBuf = [Float](repeating: 0, count: frameCount)

        var lastSampleL: Float = 0.0
        var maxDelta: Float = 0.0

        // Simulate a rapid swipe across 50 audio blocks (~260ms, sweeping 4 octaves)
        for block in 0..<50 {
            let progress = Float(block) / 50.0
            let touchX = 0.05 + progress * 0.90
            let touchPressure = 35.0 + sin(progress * .pi) * 40.0 // varying pressure 35g -> 75g -> 35g

            let touch = TouchPoint(
                id: 42,
                x: touchX,
                y: 0.25,
                pressureGrams: touchPressure,
                normalizedPressure: touchPressure / 100.0,
                area: 12.0
            )

            voiceManager.updateTouches(
                touches: [touch],
                patch: patch,
                prefs: prefs,
                pitchTrackers: &pitchTrackers,
                dt: Float(frameCount) / 48000.0,
                onCrossedSemitone: { _ in }
            )

            leftBuf.withUnsafeMutableBufferPointer { lPtr in
                rightBuf.withUnsafeMutableBufferPointer { rPtr in
                    voiceManager.render(
                        patch: patch,
                        leftOut: lPtr.baseAddress!,
                        rightOut: rPtr.baseAddress!,
                        frameCount: frameCount,
                        sampleRate: 48000.0
                    )
                }
            }

            // Verify no NaN/Inf and no massive discontinuity spikes
            for i in 0..<frameCount {
                let sampleL = leftBuf[i]
                let sampleR = rightBuf[i]

                XCTAssertFalse(sampleL.isNaN, "Left buffer NaN detected at block \(block), sample \(i)")
                XCTAssertFalse(sampleL.isInfinite, "Left buffer Inf detected at block \(block), sample \(i)")
                XCTAssertFalse(sampleR.isNaN, "Right buffer NaN detected at block \(block), sample \(i)")
                XCTAssertFalse(sampleR.isInfinite, "Right buffer Inf detected at block \(block), sample \(i)")

                XCTAssertLessThanOrEqual(abs(sampleL), 3.0, "Sample value exceeded safe bounds")
                XCTAssertLessThanOrEqual(abs(sampleR), 3.0, "Sample value exceeded safe bounds")

                let delta = abs(sampleL - lastSampleL)
                if delta > maxDelta { maxDelta = delta }
                lastSampleL = sampleL
            }
        }

        // Output should have valid sound without step spikes
        XCTAssertLessThan(maxDelta, 1.8, "Detected harsh discontinuity click during rapid glide: max delta \(maxDelta)")
    }

    func testGateHysteresis() {
        let voiceManager = VoiceManager(sampleRate: 48000.0)
        let patch = TrautoniumPatch()
        var prefs = TrautoniumPrefs()
        prefs.pressSource = .force
        prefs.gateThresholdGrams = 20.0

        var pitchTrackers: [Int: PitchTracker] = [:]
        let dt: Float = 0.005

        func checkGate(grams: Float) -> Bool {
            let touch = TouchPoint(
                id: 99,
                x: 0.5,
                y: 0.25,
                pressureGrams: grams,
                normalizedPressure: grams / 100.0,
                area: 10.0
            )
            voiceManager.updateTouches(
                touches: [touch],
                patch: patch,
                prefs: prefs,
                pitchTrackers: &pitchTrackers,
                dt: dt,
                onCrossedSemitone: { _ in }
            )
            let snapshots = voiceManager.getSnapshots()
            return snapshots.first?.isGateOn ?? false
        }

        // 1. Below threshold (15g < 20g) -> Gate OFF
        XCTAssertFalse(checkGate(grams: 15.0), "Gate should be OFF below threshold")

        // 2. Crosses threshold (22g >= 20g) -> Gate ON
        XCTAssertTrue(checkGate(grams: 22.0), "Gate should turn ON above threshold")

        // 3. Drops into hysteresis band (16g: between 0.6*20=12g and 20g) -> Gate should remain ON
        XCTAssertTrue(checkGate(grams: 16.0), "Gate should stay ON in hysteresis band")
        XCTAssertTrue(checkGate(grams: 13.0), "Gate should stay ON above 60% threshold")

        // 4. Drops below hysteresis band (10g < 12g) -> Gate turns OFF
        XCTAssertFalse(checkGate(grams: 10.0), "Gate should turn OFF below 60% threshold")

        // 5. Rises back into hysteresis band (16g) -> Gate should remain OFF until 20g reached
        XCTAssertFalse(checkGate(grams: 16.0), "Gate should stay OFF until full threshold reached")

        // 6. Crosses 20g again -> Gate turns ON
        XCTAssertTrue(checkGate(grams: 25.0), "Gate should turn ON when crossing full threshold again")
    }
}
