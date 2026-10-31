import Foundation
import CoreMIDI

public struct MPEVoiceState: Sendable, Equatable {
    public let touchId: Int
    public let channel: UInt8
    public let baseNote: UInt8
    public var lastPitchBend14: Int
    public var lastPressure7: UInt8
    public var lastCC74: UInt8

    public init(
        touchId: Int,
        channel: UInt8,
        baseNote: UInt8,
        lastPitchBend14: Int,
        lastPressure7: UInt8,
        lastCC74: UInt8
    ) {
        self.touchId = touchId
        self.channel = channel
        self.baseNote = baseNote
        self.lastPitchBend14 = lastPitchBend14
        self.lastPressure7 = lastPressure7
        self.lastCC74 = lastCC74
    }
}

public struct MIDIDestinationInfo: Identifiable, Sendable, Equatable {
    public let id: Int32
    public let name: String

    public init(id: Int32, name: String) {
        self.id = id
        self.name = name
    }
}

public final class MIDIManager: @unchecked Sendable {
    public static let shared = MIDIManager()

    public static let virtualPortName = "Virtual Port (MacTrautonium MPE)"

    private var client = MIDIClientRef()
    private var virtualSource = MIDIEndpointRef()
    private var outputPort = MIDIPortRef()

    private let lock = NSLock()
    private var isInitialized: Bool = false

    private var freeMPEChannels: [UInt8] = Array(2...16) // Member channels 2..16 for Lower Zone
    private var activeVoices: [Int: MPEVoiceState] = [:]

    private var packetBuffer = [UInt8](repeating: 0, count: 2048)

    public private(set) var activeVoiceCount: Int = 0

    private init() {
        setupCoreMIDI()
    }

    deinit {
        tearDownCoreMIDI()
    }

    private func setupCoreMIDI() {
        guard !isInitialized else { return }

        let clientName = "MacTrautonium" as CFString
        let status = MIDIClientCreateWithBlock(clientName, &client) { [weak self] _ in
            // Handle destination changes (USB plug/unplug)
            self?.lock.lock()
            // Reset any cached destination references if needed
            self?.lock.unlock()
        }

        if status != noErr {
            print("[MIDIManager] Failed to create MIDIClient: \(status)")
            return
        }

        let portName = "MacTrautonium MPE" as CFString
        let srcStatus = MIDISourceCreate(client, portName, &virtualSource)
        if srcStatus != noErr {
            print("[MIDIManager] Failed to create Virtual MIDISource: \(srcStatus)")
        }

        let outPortName = "MacTrautonium Out Port" as CFString
        let outStatus = MIDIOutputPortCreate(client, outPortName, &outputPort)
        if outStatus != noErr {
            print("[MIDIManager] Failed to create MIDIOutputPort: \(outStatus)")
        }

        isInitialized = (status == noErr && srcStatus == noErr)
        print("[MIDIManager] CoreMIDI initialized successfully. Virtual Port: '\(portName)'")

        // Broadcast initial MPE Configuration Message
        sendMPEConfiguration(memberChannels: 15, pitchBendRange: 48)
    }

    private func tearDownCoreMIDI() {
        if virtualSource != 0 {
            MIDIEndpointDispose(virtualSource)
            virtualSource = 0
        }
        if outputPort != 0 {
            MIDIPortDispose(outputPort)
            outputPort = 0
        }
        if client != 0 {
            MIDIClientDispose(client)
            client = 0
        }
        isInitialized = false
    }

    // MARK: - Destination Enumeration

    public func getAvailableDestinations() -> [String] {
        var results = [Self.virtualPortName]
        let count = MIDIGetNumberOfDestinations()
        for i in 0..<count {
            let dest = MIDIGetDestination(i)
            if dest == 0 { continue }
            var nameRef: Unmanaged<CFString>?
            var displayName = "MIDI Destination \(i + 1)"
            if MIDIObjectGetStringProperty(dest, kMIDIPropertyDisplayName, &nameRef) == noErr, let n = nameRef {
                displayName = n.takeRetainedValue() as String
            } else if MIDIObjectGetStringProperty(dest, kMIDIPropertyName, &nameRef) == noErr, let n = nameRef {
                displayName = n.takeRetainedValue() as String
            }
            results.append(displayName)
        }
        return results
    }

    private func findDestinationEndpoint(named name: String) -> MIDIEndpointRef? {
        if name == Self.virtualPortName { return nil }
        let count = MIDIGetNumberOfDestinations()
        for i in 0..<count {
            let dest = MIDIGetDestination(i)
            if dest == 0 { continue }
            var nameRef: Unmanaged<CFString>?
            var displayName = "MIDI Destination \(i + 1)"
            if MIDIObjectGetStringProperty(dest, kMIDIPropertyDisplayName, &nameRef) == noErr, let n = nameRef {
                displayName = n.takeRetainedValue() as String
            } else if MIDIObjectGetStringProperty(dest, kMIDIPropertyName, &nameRef) == noErr, let n = nameRef {
                displayName = n.takeRetainedValue() as String
            }
            if displayName == name {
                return dest
            }
        }
        return nil
    }

    // MARK: - MPE Setup & Pitch Bend Configuration

    public func sendMPEConfiguration(memberChannels: UInt8 = 15, pitchBendRange: UInt8 = 48) {
        lock.lock()
        defer { lock.unlock() }

        var messages: [[UInt8]] = []

        // MPE Lower Zone Configuration:
        // Transmit on Global Channel 1 (0xB0)
        // RPN 00 06 = memberChannels (15)
        messages.append([0xB0, 101, 0])     // RPN MSB = 0
        messages.append([0xB0, 100, 6])     // RPN LSB = 6 (MPE Zone)
        messages.append([0xB0, 6, memberChannels]) // Number of member channels (15)
        messages.append([0xB0, 101, 127])   // Reset RPN MSB
        messages.append([0xB0, 100, 127])   // Reset RPN LSB

        // Set Pitch Bend Sensitivity (RPN 00 00) for all 16 channels
        for ch in 0..<16 {
            let status = UInt8(0xB0 | ch)
            messages.append([status, 101, 0])             // RPN MSB = 0
            messages.append([status, 100, 0])             // RPN LSB = 0 (Pitch Bend Range)
            messages.append([status, 6, pitchBendRange])  // Semitones (e.g. 48)
            messages.append([status, 38, 0])              // Cents = 0
            messages.append([status, 101, 127])           // Reset RPN MSB
            messages.append([status, 100, 127])           // Reset RPN LSB
        }

        dispatchMessages(messages, destinationName: Self.virtualPortName)
    }

    // MARK: - Real-Time Touch Processing

    public func processSnapshots(_ snapshots: [SynthTouchSnapshot], prefs: TrautoniumPrefs) {
        lock.lock()
        defer { lock.unlock() }

        guard isInitialized else { return }

        var messages: [[UInt8]] = []
        let bendRange = max(1, prefs.mpeBendRange)
        let isMPE = (prefs.midiMode == .mpe)
        let baseChannel = UInt8(max(1, min(16, prefs.midiBaseChannel)))

        var currentActiveIds = Set<Int>()

        for snapshot in snapshots {
            guard snapshot.isGateOn else { continue }
            currentActiveIds.insert(snapshot.id)

            let sounding = snapshot.soundingMidi
            let baseNote = UInt8(max(0, min(127, Int(round(sounding)))))
            let bend14 = calculatePitchBend14(soundingMidi: sounding, baseNote: baseNote, bendRange: bendRange)
            let pressure7 = UInt8(max(0, min(127, Int(snapshot.normalizedPressure * 127.0))))
            let cc74 = UInt8(max(0, min(127, Int((1.0 - snapshot.y) * 127.0))))

            if var voice = activeVoices[snapshot.id] {
                // UPDATE EXISTING VOICE
                let ch = voice.channel

                // Continuous Pitch Bend
                if bend14 != voice.lastPitchBend14 {
                    messages.append([0xE0 | (ch - 1), UInt8(bend14 & 0x7F), UInt8((bend14 >> 7) & 0x7F)])
                    voice.lastPitchBend14 = bend14
                }

                // Continuous Pressure (Force Touch)
                if prefs.sendAftertouch && pressure7 != voice.lastPressure7 {
                    if isMPE {
                        messages.append([0xD0 | (ch - 1), pressure7]) // Channel Pressure
                    } else {
                        messages.append([0xA0 | (ch - 1), voice.baseNote, pressure7]) // Poly Key Pressure
                    }
                    voice.lastPressure7 = pressure7
                }

                // Continuous Slide / Timbre (Y Axis)
                if prefs.sendMPECC74 && cc74 != voice.lastCC74 {
                    messages.append([0xB0 | (ch - 1), 74, cc74])
                    voice.lastCC74 = cc74
                }

                activeVoices[snapshot.id] = voice
            } else {
                // NOTE ON (NEW VOICE)
                let ch: UInt8
                if isMPE {
                    if !freeMPEChannels.isEmpty {
                        ch = freeMPEChannels.removeFirst()
                    } else if let oldestKey = activeVoices.keys.first, let stolen = activeVoices.removeValue(forKey: oldestKey) {
                        // Steal channel if 15 voices exceeded
                        messages.append([0x80 | (stolen.channel - 1), stolen.baseNote, 0])
                        ch = stolen.channel
                    } else {
                        ch = 2
                    }
                } else {
                    ch = baseChannel
                }

                let velocity = UInt8(max(20, min(127, Int(snapshot.normalizedPressure * 127.0))))

                if isMPE {
                    // MPE Specification: Pitch Bend & Expression MUST be sent BEFORE Note On
                    messages.append([0xE0 | (ch - 1), UInt8(bend14 & 0x7F), UInt8((bend14 >> 7) & 0x7F)])
                    if prefs.sendMPECC74 {
                        messages.append([0xB0 | (ch - 1), 74, cc74])
                    }
                    if prefs.sendAftertouch {
                        messages.append([0xD0 | (ch - 1), pressure7])
                    }
                    messages.append([0x90 | (ch - 1), baseNote, velocity])
                } else {
                    messages.append([0x90 | (ch - 1), baseNote, velocity])
                    if prefs.sendAftertouch {
                        messages.append([0xA0 | (ch - 1), baseNote, pressure7])
                    }
                }

                activeVoices[snapshot.id] = MPEVoiceState(
                    touchId: snapshot.id,
                    channel: ch,
                    baseNote: baseNote,
                    lastPitchBend14: bend14,
                    lastPressure7: pressure7,
                    lastCC74: cc74
                )
            }
        }

        // NOTE OFF FOR RELEASED TOUCHES
        let releasedIds = activeVoices.keys.filter { !currentActiveIds.contains($0) }
        for id in releasedIds {
            if let voice = activeVoices.removeValue(forKey: id) {
                let ch = voice.channel
                messages.append([0x80 | (ch - 1), voice.baseNote, 0])

                if isMPE {
                    // Reset Pitch Bend and Pressure to neutral on channel release
                    messages.append([0xE0 | (ch - 1), 0x00, 0x40]) // 8192 (Center)
                    messages.append([0xD0 | (ch - 1), 0x00])        // 0 Pressure
                    if !freeMPEChannels.contains(ch) {
                        freeMPEChannels.append(ch)
                        freeMPEChannels.sort()
                    }
                }
            }
        }

        self.activeVoiceCount = activeVoices.count

        if !messages.isEmpty {
            dispatchMessages(messages, destinationName: prefs.selectedMIDIDestinationName)
        }
    }

    public func calculatePitchBend14(soundingMidi: Float, baseNote: UInt8, bendRange: Int) -> Int {
        let delta = soundingMidi - Float(baseNote)
        let normalized = max(-1.0, min(1.0, delta / Float(bendRange)))
        let bend14: Int
        if normalized >= 0 {
            bend14 = 8192 + Int(round(normalized * 8191.0))
        } else {
            bend14 = 8192 + Int(round(normalized * 8192.0))
        }
        return max(0, min(16383, bend14))
    }

    // MARK: - Silence & Panic

    public func silenceAllVoices() {
        lock.lock()
        defer { lock.unlock() }

        guard !activeVoices.isEmpty else { return }
        var messages: [[UInt8]] = []

        for (_, voice) in activeVoices {
            let ch = voice.channel
            messages.append([0x80 | (ch - 1), voice.baseNote, 0])
            messages.append([0xE0 | (ch - 1), 0x00, 0x40]) // Center pitch bend
            messages.append([0xD0 | (ch - 1), 0x00])        // Zero pressure
        }

        activeVoices.removeAll()
        freeMPEChannels = Array(2...16)
        activeVoiceCount = 0

        dispatchMessages(messages, destinationName: Self.virtualPortName)
    }

    public func panic() {
        lock.lock()
        defer { lock.unlock() }

        var messages: [[UInt8]] = []

        // All Sound Off (CC 120), All Notes Off (CC 123), Reset Controllers (CC 121) on channels 1..16
        for ch in 0..<16 {
            let status = UInt8(0xB0 | ch)
            messages.append([status, 120, 0]) // All Sound Off
            messages.append([status, 123, 0]) // All Notes Off
            messages.append([status, 121, 0]) // Reset All Controllers
            messages.append([0xE0 | UInt8(ch), 0x00, 0x40]) // Pitch Bend Center
            messages.append([0xD0 | UInt8(ch), 0x00])        // Aftertouch 0
        }

        activeVoices.removeAll()
        freeMPEChannels = Array(2...16)
        activeVoiceCount = 0

        dispatchMessages(messages, destinationName: Self.virtualPortName)
    }

    // MARK: - CoreMIDI Packet Dispatch

    private func dispatchMessages(_ messages: [[UInt8]], destinationName: String) {
        guard isInitialized, !messages.isEmpty else { return }

        packetBuffer.withUnsafeMutableBytes { rawBuf in
            let packetList = rawBuf.bindMemory(to: MIDIPacketList.self).baseAddress!
            var curPacket = MIDIPacketListInit(packetList)
            let capacity = rawBuf.count

            for msg in messages {
                curPacket = MIDIPacketListAdd(
                    packetList,
                    capacity,
                    curPacket,
                    0,
                    msg.count,
                    msg
                )
            }

            // Always broadcast to Virtual Source endpoint
            if virtualSource != 0 {
                _ = MIDIReceived(virtualSource, packetList)
            }

            // Also send to external hardware/system destination if selected
            if destinationName != Self.virtualPortName,
               let destEndpoint = findDestinationEndpoint(named: destinationName),
               outputPort != 0 {
                _ = MIDISend(outputPort, destEndpoint, packetList)
            }
        }
    }
}
