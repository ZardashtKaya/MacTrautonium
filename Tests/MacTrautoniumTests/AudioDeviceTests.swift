import XCTest
@testable import TrautoniumKit

final class AudioDeviceTests: XCTestCase {
    func testGetAvailableOutputDevices() {
        let devices = AudioDeviceManager.shared.getAvailableOutputDevices()
        // On any macOS machine with audio capabilities (speakers, headphones, or virtual drivers),
        // there should be at least one output device available.
        XCTAssertFalse(devices.isEmpty, "Expected at least one audio output device to be detected")
        for dev in devices {
            XCTAssertFalse(dev.name.isEmpty, "Audio device name should not be empty")
            XCTAssertFalse(dev.uid.isEmpty, "Audio device UID should not be empty")
            XCTAssertGreaterThan(dev.id, 0, "Audio device ID should be valid")
        }
    }

    func testGetDefaultOutputDevice() {
        let defaultDevice = AudioDeviceManager.shared.getDefaultOutputDevice()
        XCTAssertNotNil(defaultDevice, "Expected default output audio device to be present")
        if let dev = defaultDevice {
            XCTAssertFalse(dev.name.isEmpty)
            XCTAssertFalse(dev.uid.isEmpty)
            let lookedUp = AudioDeviceManager.shared.getDevice(forUID: dev.uid)
            XCTAssertEqual(lookedUp?.id, dev.id)
        }
    }

    func testDeviceLookupByUIDAndID() {
        let devices = AudioDeviceManager.shared.getAvailableOutputDevices()
        guard let first = devices.first else { return }

        let byUID = AudioDeviceManager.shared.getDevice(forUID: first.uid)
        XCTAssertEqual(byUID?.id, first.id)
        XCTAssertEqual(byUID?.name, first.name)

        let byID = AudioDeviceManager.shared.getDevice(forID: first.id)
        XCTAssertEqual(byID?.uid, first.uid)
        XCTAssertEqual(byID?.name, first.name)
    }
}
