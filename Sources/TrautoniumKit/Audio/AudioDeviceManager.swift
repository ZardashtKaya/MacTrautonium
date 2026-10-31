import Foundation
import CoreAudio
import AudioToolbox

public struct AudioOutputDevice: Identifiable, Hashable, Sendable {
    public let id: AudioDeviceID
    public let name: String
    public let uid: String

    public init(id: AudioDeviceID, name: String, uid: String) {
        self.id = id
        self.name = name
        self.uid = uid
    }
}

public final class AudioDeviceManager: @unchecked Sendable {
    public static let shared = AudioDeviceManager()

    private init() {}

    /// Enumerates all currently available CoreAudio devices with at least one output stream.
    public func getAvailableOutputDevices() -> [AudioOutputDevice] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr else {
            return []
        }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var devIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &devIDs) == noErr else {
            return []
        }

        var result: [AudioOutputDevice] = []
        for devID in devIDs {
            // Verify device has output streams
            var streamAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(devID, &streamAddr, 0, nil, &streamSize) == noErr && streamSize > 0 else {
                continue
            }

            // Query Name
            var nameAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var nameCF: CFString = "" as CFString
            var nSize = UInt32(MemoryLayout<CFString>.size)
            let nameStatus = withUnsafeMutablePointer(to: &nameCF) { ptr in
                AudioObjectGetPropertyData(devID, &nameAddr, 0, nil, &nSize, ptr)
            }
            let name = (nameStatus == noErr) ? (nameCF as String) : "Unknown Device (\(devID))"

            // Query UID
            var uidAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var uidCF: CFString = "" as CFString
            var uSize = UInt32(MemoryLayout<CFString>.size)
            let uidStatus = withUnsafeMutablePointer(to: &uidCF) { ptr in
                AudioObjectGetPropertyData(devID, &uidAddr, 0, nil, &uSize, ptr)
            }
            let uid = (uidStatus == noErr) ? (uidCF as String) : String(devID)

            result.append(AudioOutputDevice(id: devID, name: name, uid: uid))
        }

        return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Retrieves the system's default output audio device.
    public func getDefaultOutputDevice() -> AudioOutputDevice? {
        var defaultAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var defaultDeviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultAddr, 0, nil, &size, &defaultDeviceID) == noErr else {
            return nil
        }
        return getDevice(forID: defaultDeviceID)
    }

    /// Finds an output device matching the given persistent UID string.
    public func getDevice(forUID uid: String) -> AudioOutputDevice? {
        guard !uid.isEmpty else { return nil }
        return getAvailableOutputDevices().first { $0.uid == uid }
    }

    /// Finds an output device matching the given runtime CoreAudio device ID.
    public func getDevice(forID id: AudioDeviceID) -> AudioOutputDevice? {
        var nameAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var nameCF: CFString = "" as CFString
        var nSize = UInt32(MemoryLayout<CFString>.size)
        let nameStatus = withUnsafeMutablePointer(to: &nameCF) { ptr in
            AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &nSize, ptr)
        }
        guard nameStatus == noErr else { return nil }

        var uidAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uidCF: CFString = "" as CFString
        var uSize = UInt32(MemoryLayout<CFString>.size)
        let uidStatus = withUnsafeMutablePointer(to: &uidCF) { ptr in
            AudioObjectGetPropertyData(id, &uidAddr, 0, nil, &uSize, ptr)
        }
        let uid = (uidStatus == noErr) ? (uidCF as String) : String(id)

        return AudioOutputDevice(id: id, name: nameCF as String, uid: uid)
    }
}
