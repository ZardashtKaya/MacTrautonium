import XCTest
@testable import TrautoniumKit

final class MIDITests: XCTestCase {
    func testMPEPitchBendCalculation() {
        let midiManager = MIDIManager.shared
        let bendRange = 48

        // Exact note (C4 = 60.0, baseNote = 60) -> Center bend 8192
        let centerBend = midiManager.calculatePitchBend14(soundingMidi: 60.0, baseNote: 60, bendRange: bendRange)
        XCTAssertEqual(centerBend, 8192, "Exact note must yield center pitch bend 8192")

        // 1 semitone sharp (61.0, baseNote = 60) -> (1 / 48) * 8191 + 8192 ≈ 8362..8363
        let sharpBend = midiManager.calculatePitchBend14(soundingMidi: 61.0, baseNote: 60, bendRange: bendRange)
        XCTAssertEqual(sharpBend, 8362, accuracy: 2)

        // 1 semitone flat (59.0, baseNote = 60) -> (-1 / 48) * 8191 + 8192 ≈ 8021..8022
        let flatBend = midiManager.calculatePitchBend14(soundingMidi: 59.0, baseNote: 60, bendRange: bendRange)
        XCTAssertEqual(flatBend, 8021, accuracy: 2)

        // Extreme bounds: +48 semitones -> Max bend 16383
        let maxBend = midiManager.calculatePitchBend14(soundingMidi: 108.0, baseNote: 60, bendRange: bendRange)
        XCTAssertEqual(maxBend, 16383)

        // Extreme bounds: -48 semitones -> Min bend 0
        let minBend = midiManager.calculatePitchBend14(soundingMidi: 12.0, baseNote: 60, bendRange: bendRange)
        XCTAssertEqual(minBend, 0)
    }

    func testMPEVoiceProcessingLifecycle() {
        let midiManager = MIDIManager.shared
        midiManager.panic()
        XCTAssertEqual(midiManager.activeVoiceCount, 0)

        var prefs = TrautoniumPrefs()
        prefs.midiMode = .mpe
        prefs.mpeBendRange = 48
        prefs.sendAftertouch = true
        prefs.sendMPECC74 = true

        // 1. Initial touch on trackpad (C4 = 60.25)
        let touch1 = SynthTouchSnapshot(
            id: 101,
            manual: 0,
            x: 0.25,
            y: 0.30,
            pressureGrams: 45.0,
            normalizedPressure: 0.45,
            rawMidi: 60.25,
            soundingMidi: 60.25,
            isGateOn: true
        )

        midiManager.processSnapshots([touch1], prefs: prefs)
        XCTAssertEqual(midiManager.activeVoiceCount, 1, "Should have 1 active MPE voice")

        // 2. Second polyphonic touch (E4 = 64.0)
        let touch2 = SynthTouchSnapshot(
            id: 102,
            manual: 0,
            x: 0.45,
            y: 0.35,
            pressureGrams: 60.0,
            normalizedPressure: 0.60,
            rawMidi: 64.0,
            soundingMidi: 64.0,
            isGateOn: true
        )

        midiManager.processSnapshots([touch1, touch2], prefs: prefs)
        XCTAssertEqual(midiManager.activeVoiceCount, 2, "Should have 2 active MPE voices")

        // 3. Gliding touch 1 smoothly from 60.25 to 72.0 (+12 semitones, 1 full octave)
        let touch1Glided = SynthTouchSnapshot(
            id: 101,
            manual: 0,
            x: 0.50,
            y: 0.30,
            pressureGrams: 50.0,
            normalizedPressure: 0.50,
            rawMidi: 72.0,
            soundingMidi: 72.0,
            isGateOn: true
        )
        midiManager.processSnapshots([touch1Glided, touch2], prefs: prefs)
        XCTAssertEqual(midiManager.activeVoiceCount, 2, "Voices should remain stable during glide")

        let voice1 = midiManager.getActiveVoiceState(for: 101)
        XCTAssertEqual(voice1?.baseNote, 60, "Base note must remain anchored to original touch note")
        // Expected bend for +12 semitones on 48 bend range: (12/48) * 8191 + 8192 = 10240
        XCTAssertEqual(voice1?.lastPitchBend14, 10240, "Pitch bend must bend by +12 semitones to target note")
        let msb = ((voice1?.lastPitchBend14 ?? 0) >> 7) & 0x7F
        XCTAssertEqual(msb, 80, "Pitch bend MSB must be 80 for +12 semitones (not 63 or 64)")

        // 4. Release touch 1 (finger lifted)
        midiManager.processSnapshots([touch2], prefs: prefs)
        XCTAssertEqual(midiManager.activeVoiceCount, 1, "Should have 1 active voice after releasing touch 1")

        // 5. Release touch 2
        midiManager.processSnapshots([], prefs: prefs)
        XCTAssertEqual(midiManager.activeVoiceCount, 0, "All voices should be released")
    }

    func testStandardMIDIModeProcessing() {
        let midiManager = MIDIManager.shared
        midiManager.panic()

        var prefs = TrautoniumPrefs()
        prefs.midiMode = .standard
        prefs.midiBaseChannel = 1
        prefs.sendAftertouch = true

        let touch = SynthTouchSnapshot(
            id: 201,
            manual: 0,
            x: 0.50,
            y: 0.40,
            pressureGrams: 70.0,
            normalizedPressure: 0.70,
            rawMidi: 69.0,
            soundingMidi: 69.0,
            isGateOn: true
        )

        midiManager.processSnapshots([touch], prefs: prefs)
        XCTAssertEqual(midiManager.activeVoiceCount, 1)

        midiManager.processSnapshots([], prefs: prefs)
        XCTAssertEqual(midiManager.activeVoiceCount, 0)
    }

    func testPanicResetsAllVoices() {
        let midiManager = MIDIManager.shared

        var prefs = TrautoniumPrefs()
        prefs.midiMode = .mpe

        let touches = (1...5).map { id in
            SynthTouchSnapshot(
                id: id,
                manual: 0,
                x: Float(id) * 0.15,
                y: 0.25,
                pressureGrams: 50.0,
                normalizedPressure: 0.50,
                rawMidi: Float(60 + id),
                soundingMidi: Float(60 + id),
                isGateOn: true
            )
        }

        midiManager.processSnapshots(touches, prefs: prefs)
        XCTAssertEqual(midiManager.activeVoiceCount, 5)

        // Panic must silence everything
        midiManager.panic()
        XCTAssertEqual(midiManager.activeVoiceCount, 0)
    }

    func testAvailableDestinationsIncludesVirtualPort() {
        let destinations = MIDIManager.shared.getAvailableDestinations()
        XCTAssertTrue(destinations.contains("Virtual Port (MacTrautonium MPE)"))
    }
}
