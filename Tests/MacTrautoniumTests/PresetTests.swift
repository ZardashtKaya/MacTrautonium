import XCTest
@testable import TrautoniumKit

final class PresetTests: XCTestCase {
    func testFactoryPresetsExist() {
        XCTAssertGreaterThanOrEqual(PresetLibrary.factoryPresets.count, 7)
        XCTAssertEqual(PresetLibrary.factoryPresets.first?.name, "live")
        XCTAssertTrue(PresetLibrary.isFactoryPreset(named: "live"))
        XCTAssertTrue(PresetLibrary.isFactoryPreset(named: "Mixtur Classic (Sala)"))
        XCTAssertTrue(PresetLibrary.isFactoryPreset(named: "The Birds (Hitchcock)"))
        XCTAssertFalse(PresetLibrary.isFactoryPreset(named: "NonExistentPreset12345"))
    }

    func testLivePresetIsDefault() {
        let defaultPatch = PresetLibrary.defaultPatch
        XCTAssertEqual(defaultPatch.name.lowercased(), "live")
        XCTAssertEqual(defaultPatch.scaleIndex, 15) // Harmonic Minor
        XCTAssertEqual(defaultPatch.tonic, 7)       // G
        XCTAssertEqual(defaultPatch.reverbMix, 0.90, accuracy: 1e-4)
        XCTAssertEqual(defaultPatch.saturation, 0.80, accuracy: 1e-4)
        XCTAssertEqual(defaultPatch.manuals[0].snapMode, .hard)
        XCTAssertEqual(defaultPatch.manuals[1].snapMode, .hard)
    }

    func testSaveLoadDeleteUserPreset() throws {
        let testName = "UnitTest_CustomPreset_\(UUID().uuidString.prefix(6))"
        var patch = TrautoniumPatch()
        patch.name = testName
        patch.reverbMix = 0.77
        patch.manuals[0].cutoff = 3456.0
        patch.manuals[0].subDividers = [3, 5, 7, 9]

        // 1. Save preset
        let fileURL = try PresetLibrary.saveUserPreset(patch: patch)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        // 2. Load presets
        let loadedPresets = PresetLibrary.loadUserPresets()
        guard let found = loadedPresets.first(where: { $0.name == testName }) else {
            XCTFail("Saved user preset was not found in loaded presets")
            return
        }
        XCTAssertEqual(found.reverbMix, Float(0.77), accuracy: Float(1e-4))
        XCTAssertEqual(found.manuals[0].cutoff, Float(3456.0), accuracy: Float(1e-4))
        XCTAssertEqual(found.manuals[0].subDividers, [3, 5, 7, 9])

        // 3. Delete preset
        let deleted = PresetLibrary.deleteUserPreset(named: testName)
        XCTAssertTrue(deleted, "Failed to delete user preset")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path), "Preset file was not removed")

        // 4. Verify no longer in list
        let afterDelete = PresetLibrary.loadUserPresets()
        XCTAssertFalse(afterDelete.contains { $0.name == testName })
    }
}
