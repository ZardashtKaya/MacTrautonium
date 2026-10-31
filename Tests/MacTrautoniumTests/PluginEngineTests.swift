import XCTest
@testable import TrautoniumKit

final class PluginEngineTests: XCTestCase {
    func testPluginEngineLifecycleAndRendering() {
        let engine = TrautoniumPluginEngine(sampleRate: 48000.0)

        var left = [Float](repeating: 0, count: 512)
        var right = [Float](repeating: 0, count: 512)

        // Initial silence
        engine.render(left: &left, right: &right, frameCount: 512)
        let initialMaxL = left.map { abs($0) }.max() ?? 0
        XCTAssertEqual(initialMaxL, 0.0, accuracy: 1e-6)

        // Note on: MIDI note 69 (A4, 440 Hz), velocity 0.8 on channel 2 (MPE)
        engine.noteOn(channel: 2, note: 69, velocity: 0.8)

        // Render audio
        engine.render(left: &left, right: &right, frameCount: 512)
        let noteMaxL = left.map { abs($0) }.max() ?? 0
        XCTAssertGreaterThan(noteMaxL, 0.01, "Expected audible output after noteOn")

        // Pitch bend +12 semitones
        engine.pitchBend(channel: 2, bend14: 12288) // 8192 + 4096 = +0.5 * 48 = +24 semitones
        engine.render(left: &left, right: &right, frameCount: 512)

        // Pressure aftertouch
        engine.pressure(channel: 2, note: 69, pressure: 0.95)
        engine.render(left: &left, right: &right, frameCount: 512)

        // Note off
        engine.noteOff(channel: 2, note: 69)

        // Render release tail
        for _ in 0..<20 {
            engine.render(left: &left, right: &right, frameCount: 512)
        }

        // Panic / reset
        engine.panic()
        engine.render(left: &left, right: &right, frameCount: 512)
        let silentMax = left.map { abs($0) }.max() ?? 0
        XCTAssertEqual(silentMax, 0.0, accuracy: 1e-5)
    }

    func testSampleRateSwitching() {
        let engine = TrautoniumPluginEngine(sampleRate: 44100.0)
        engine.setSampleRate(96000.0)
        XCTAssertEqual(engine.sampleRate, 96000.0)

        var left = [Float](repeating: 0, count: 256)
        var right = [Float](repeating: 0, count: 256)
        engine.noteOn(channel: 1, note: 60, velocity: 0.7)
        engine.render(left: &left, right: &right, frameCount: 256)
        let maxL = left.map { abs($0) }.max() ?? 0
        XCTAssertGreaterThan(maxL, 0.001)
    }
}
