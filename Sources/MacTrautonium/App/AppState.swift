import SwiftUI
import Combine
import AppKit
import CoreGraphics
import TrautoniumKit

@MainActor
public final class AppState: ObservableObject {
    @Published public var patch: TrautoniumPatch
    @Published public var prefs: TrautoniumPrefs
    @Published public var activeTouches: [SynthTouchSnapshot] = []
    @Published public var scopeWaveform: [Float] = [Float](repeating: 0, count: 256)
    @Published public var isRecording: Bool = false
    @Published public var recordingDuration: TimeInterval = 0
    @Published public var lastRecordedURL: URL?
    @Published public var showRecordedAlert: Bool = false
    @Published public var selectedTab: Int = 0 // 0: Manual I, 1: Manual II, 2: Global/FX
    @Published public var userPresets: [TrautoniumPatch] = []
    @Published public var isSavePresetSheetPresented: Bool = false
    @Published public var presetNameInput: String = ""
    @Published public var peakLevels: (left: Float, right: Float) = (0.0, 0.0)
    @Published public var availableMIDIDestinations: [String] = []
    @Published public var availableAudioDevices: [AudioOutputDevice] = []

    @Published public var isPlayMode: Bool = false {
        didSet {
            applyPlayMode(isPlayMode)
        }
    }

    private nonisolated(unsafe) var isCursorHidden: Bool = false
    private nonisolated(unsafe) var eventMonitor: Any?
    private var displayTimer: AnyCancellable?
    private var recordTimer: AnyCancellable?
    private var recordStartTime: Date?
    public let pluginEngine: TrautoniumPluginEngine?
    public var isPluginMode: Bool { pluginEngine != nil }

    public init(pluginEngine: TrautoniumPluginEngine? = nil) {
        self.pluginEngine = pluginEngine
        if let pe = pluginEngine {
            self.patch = pe.patch
            self.prefs = pe.prefs
            TrautoniumPluginEngine.activeInstance = pe
            pe.isTouchInputEnabled = true
        } else {
            let engine = AudioEngineController.shared
            self.patch = engine.patch
            self.prefs = engine.prefs
            startEngine()
        }

        TouchInputManager.shared.start()
        setupKeyMonitor()
        reloadUserPresets()
        refreshMIDIDestinations()
        refreshAudioDevices()
        setupDisplayTimer()
    }

    deinit {
        if isCursorHidden {
            CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
            CGDisplayShowCursor(kCGNullDirectDisplay)
        }
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    public func startEngine() {
        do {
            try AudioEngineController.shared.start()
        } catch {
            print("[AppState] Error starting audio engine: \(error)")
        }
    }

    public func updatePatch() {
        if let pe = pluginEngine {
            pe.patch = patch
        } else {
            AudioEngineController.shared.patch = patch
        }
    }

    public func updatePrefs() {
        if let pe = pluginEngine {
            pe.prefs = prefs
        } else {
            AudioEngineController.shared.prefs = prefs
        }
        if prefs.midiMode == .mpe {
            MIDIManager.shared.sendMPEConfiguration(memberChannels: 15, pitchBendRange: UInt8(max(1, min(96, prefs.mpeBendRange))))
        }
    }

    public func loadPreset(_ preset: TrautoniumPatch) {
        self.patch = preset
        updatePatch()
    }

    // MARK: - Preset Management

    public func reloadUserPresets() {
        self.userPresets = PresetLibrary.loadUserPresets()
    }

    public func openSavePresetDialog() {
        self.presetNameInput = patch.name
        self.isSavePresetSheetPresented = true
    }

    public func saveCurrentPreset(named name: String) {
        var p = patch
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        p.name = trimmed.isEmpty ? "My Custom Preset" : trimmed
        self.patch = p
        updatePatch()

        do {
            _ = try PresetLibrary.saveUserPreset(patch: p)
            reloadUserPresets()
        } catch {
            print("[AppState] Error saving user preset: \(error)")
        }
    }

    public func deleteUserPreset(named name: String) {
        _ = PresetLibrary.deleteUserPreset(named: name)
        reloadUserPresets()
        if patch.name == name {
            loadPreset(PresetLibrary.factoryPresets[0])
        }
    }

    public func openPresetsFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([PresetLibrary.userPresetsDirectory])
    }

    // MARK: - Audio & MIDI Routing

    public func setRoutingMode(_ mode: OutputRoutingMode) {
        prefs.routingMode = mode
        updatePrefs()
    }

    public func refreshMIDIDestinations() {
        self.availableMIDIDestinations = MIDIManager.shared.getAvailableDestinations()
    }

    public func refreshAudioDevices() {
        self.availableAudioDevices = AudioDeviceManager.shared.getAvailableOutputDevices()
    }

    public func selectAudioOutputDevice(uid: String) {
        prefs.selectedAudioOutputDeviceUID = uid
        updatePrefs()
        if !isPluginMode {
            do {
                try AudioEngineController.shared.setOutputDevice(uid: uid)
            } catch {
                print("[AppState] Error switching audio output device: \(error)")
            }
        }
    }

    public func sendMIDIPanic() {
        MIDIManager.shared.panic()
    }

    // MARK: - Play Mode & Mouse Decoupling

    public func togglePlayMode() {
        isPlayMode.toggle()
    }

    public func setPlayMode(_ active: Bool) {
        if isPlayMode != active {
            isPlayMode = active
        }
    }

    private func applyPlayMode(_ active: Bool) {
        if active {
            if !isCursorHidden {
                // Decouple mouse position from hardware movement
                CGAssociateMouseAndMouseCursorPosition(boolean_t(0))
                CGDisplayHideCursor(kCGNullDirectDisplay)
                isCursorHidden = true
            }
        } else {
            if isCursorHidden {
                // Re-associate mouse and show cursor
                CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
                CGDisplayShowCursor(kCGNullDirectDisplay)
                isCursorHidden = false
            }
        }
    }

    private func setupKeyMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            // Spacebar (keyCode 49) toggles play mode
            if event.keyCode == 49 {
                self.togglePlayMode()
                return nil // Consume space event
            }

            // Escape (keyCode 53) exits play mode
            if event.keyCode == 53 && self.isPlayMode {
                self.setPlayMode(false)
                return nil // Consume escape event
            }

            return event
        }

        // Restore cursor when app loses active focus
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.setPlayMode(false)
            }
        }
    }

    // MARK: - Recording

    public func toggleRecording() {
        let engine = AudioEngineController.shared
        if isRecording {
            if let url = engine.audioRecorder.stopRecording() {
                self.lastRecordedURL = url
                self.showRecordedAlert = true
            }
            isRecording = false
            recordTimer?.cancel()
            recordTimer = nil
        } else {
            if let _ = engine.audioRecorder.startRecording() {
                isRecording = true
                recordStartTime = Date()
                recordTimer = Timer.publish(every: 0.2, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in
                        guard let self = self, let start = self.recordStartTime else { return }
                        self.recordingDuration = Date().timeIntervalSince(start)
                    }
            }
        }
    }

    // MARK: - Display Loop

    private func setupDisplayTimer() {
        displayTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }

                if let pe = self.pluginEngine {
                    self.activeTouches = pe.voiceManager.getSnapshots()
                    var samples = [Float](repeating: 0, count: 256)
                    pe.scopeBuffer.snapshot(into: &samples)
                    self.scopeWaveform = samples
                    self.peakLevels = pe.getPeakLevels()
                } else {
                    let engine = AudioEngineController.shared
                    self.activeTouches = engine.voiceManager.getSnapshots()
                    var samples = [Float](repeating: 0, count: 256)
                    engine.scopeBuffer.snapshot(into: &samples)
                    self.scopeWaveform = samples
                    self.peakLevels = engine.getPeakLevels()
                }
            }
    }
}
