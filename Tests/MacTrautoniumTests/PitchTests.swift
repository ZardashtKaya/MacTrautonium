import XCTest
@testable import TrautoniumKit

final class PitchTests: XCTestCase {
    func testPitchRibbonConversion() {
        // Left margin (0.03) should yield exact lowNote
        let leftMidi = PitchRibbon.xToMidi(x: 0.03, lowNote: 48, spanOctaves: 2)
        XCTAssertEqual(leftMidi, 48.0, accuracy: 0.01)

        // Right margin (0.97) should yield lowNote + 24 semitones
        let rightMidi = PitchRibbon.xToMidi(x: 0.97, lowNote: 48, spanOctaves: 2)
        XCTAssertEqual(rightMidi, 72.0, accuracy: 0.01)

        // Center (0.50) should yield lowNote + 12 semitones (one octave up)
        let centerMidi = PitchRibbon.xToMidi(x: 0.50, lowNote: 48, spanOctaves: 2)
        XCTAssertEqual(centerMidi, 60.0, accuracy: 0.05)
    }

    func testScaleMembership() {
        // Major Scale with tonic C (0) -> C(0), D(2), E(4), F(5), G(7), A(9), B(11)
        XCTAssertTrue(Scales.contains(note: 60, scaleIndex: 1, tonic: 0)) // C4
        XCTAssertTrue(Scales.contains(note: 62, scaleIndex: 1, tonic: 0)) // D4
        XCTAssertTrue(Scales.contains(note: 64, scaleIndex: 1, tonic: 0)) // E4
        XCTAssertFalse(Scales.contains(note: 61, scaleIndex: 1, tonic: 0)) // C#4 not in C Major

        // Nearest note calculation
        let nearestToCSharp = Scales.nearest(note: 61.2, scaleIndex: 1, tonic: 0)
        XCTAssertEqual(nearestToCSharp, 62.0) // 61.2 is closer to D (62) than C (60)
    }

    func testPitchTrackerMagneticAttraction() {
        var tracker = PitchTracker()
        let dt: Float = 0.005

        // Initial touch at microtonal pitch 60.4
        _ = tracker.update(
            raw: 60.4,
            dt: dt,
            snapMode: .soft,
            scaleIndex: 1, // Major
            tonic: 0,      // C
            snapSpeedMs: 50.0
        )

        // Initially touches near 60.4
        XCTAssertEqual(tracker.finalPitch, 60.0, accuracy: 0.1)

        // Simulate resting stationary finger over 500ms: should converge toward 60.0 (C4)
        for _ in 0..<100 {
            _ = tracker.update(
                raw: 60.08,
                dt: dt,
                snapMode: .soft,
                scaleIndex: 1,
                tonic: 0,
                snapSpeedMs: 50.0
            )
        }

        XCTAssertEqual(tracker.finalPitch, 60.0, accuracy: 0.05, "Resting pitch did not magnetically attract to nearest scale note")
    }

    func testAllScalesIntegrity() {
        XCTAssertEqual(Scales.all.count, 42, "Expected 42 comprehensive scales")

        for (idx, scale) in Scales.all.enumerated() {
            XCTAssertFalse(scale.name.isEmpty, "Scale at index \(idx) has empty name")
            XCTAssertNotEqual(scale.mask, 0, "Scale \(scale.name) has empty bitmask")
            // Bit 0 (tonic) must always be set
            XCTAssertTrue(scale.contains(semitoneFromTonic: 0), "Scale \(scale.name) must contain root note")

            // Test notes summary generation for tonic C (0) and G (7)
            let summaryC = scale.notesSummary(tonic: 0)
            XCTAssertTrue(summaryC.starts(with: "C"), "Summary in C must start with C: \(summaryC)")

            let summaryG = scale.notesSummary(tonic: 7)
            XCTAssertTrue(summaryG.starts(with: "G"), "Summary in G must start with G: \(summaryG)")
        }

        // Test category distribution
        for category in ScaleCategory.allCases {
            let count = Scales.all.filter { $0.category == category }.count
            XCTAssertGreaterThan(count, 0, "Category \(category.rawValue) has no scales")
        }
    }
}
