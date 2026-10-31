import SwiftUI
import TrautoniumKit

public struct HeaderBarView: View {
    @ObservedObject var state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 16) {
            // App Branding
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(red: 0.98, green: 0.45, blue: 0.55))
                VStack(alignment: .leading, spacing: 1) {
                    Text("MacTrautonium")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                    Text("Mixtur-Trautonium • Force Touch")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Presets Dropdown
            Menu {
                // Factory Presets Section
                Section("Factory Presets") {
                    ForEach(PresetLibrary.factoryPresets, id: \.name) { preset in
                        Button(action: {
                            state.loadPreset(preset)
                        }) {
                            if state.patch.name == preset.name {
                                Label(preset.name, systemImage: "checkmark")
                            } else {
                                Text(preset.name)
                            }
                        }
                    }
                }

                // User Presets Section
                if !state.userPresets.isEmpty {
                    Section("User Presets") {
                        ForEach(state.userPresets, id: \.name) { preset in
                            Button(action: {
                                state.loadPreset(preset)
                            }) {
                                if state.patch.name == preset.name {
                                    Label(preset.name, systemImage: "checkmark")
                                } else {
                                    Text(preset.name)
                                }
                            }
                        }
                    }
                }

                // Management Actions
                Section {
                    Button(action: {
                        state.openSavePresetDialog()
                    }) {
                        Label("Save Current Preset...", systemImage: "square.and.arrow.down")
                    }

                    if !PresetLibrary.isFactoryPreset(named: state.patch.name) {
                        Button(role: .destructive, action: {
                            state.deleteUserPreset(named: state.patch.name)
                        }) {
                            Label("Delete '\(state.patch.name)'", systemImage: "trash")
                        }
                    }

                    Button(action: {
                        state.openPresetsFolder()
                    }) {
                        Label("Open Presets Folder in Finder", systemImage: "folder")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "music.quarternote.3")
                    Text(state.patch.name)
                        .font(.system(size: 12, weight: .bold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(white: 0.18))
                .cornerRadius(8)
            }
            .menuStyle(.borderlessButton)

            // Quick Save Button
            Button(action: {
                state.openSavePresetDialog()
            }) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(white: 0.18))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .help("Save current patch as a preset")

            Divider().frame(height: 22)

            // Global Routing Mode (Internal Synth vs MIDI Out vs Both)
            routingModeSwitcher

            Divider().frame(height: 22)

            // Play Mode Toggle Button
            Button(action: {
                state.togglePlayMode()
            }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(state.isPlayMode ? Color.green : Color.orange.opacity(0.8))
                        .frame(width: 8, height: 8)
                    Text(state.isPlayMode ? "PLAYING [SPACE]" : "PLAY [SPACE]")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(state.isPlayMode ? .green : .white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(state.isPlayMode ? Color.green.opacity(0.18) : Color(white: 0.18))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(state.isPlayMode ? Color.green : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Press SPACE to toggle Play Mode (decouples mouse cursor for free trackpad performance)")

            Divider().frame(height: 22)

            // Stereo Peak VU Meter
            vuMeterView(left: state.peakLevels.left, right: state.peakLevels.right)

            Divider().frame(height: 22)

            // WAV Recorder Button
            Button(action: {
                state.toggleRecording()
            }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(state.isRecording ? Color.red : Color.gray)
                        .frame(width: 10, height: 10)
                    if state.isRecording {
                        Text(formatDuration(state.recordingDuration))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                    } else {
                        Text("REC WAV")
                            .font(.system(size: 11, weight: .bold))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(state.isRecording ? Color.red.opacity(0.18) : Color(white: 0.18))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(state.isRecording ? Color.red : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Recorded Alert Button (if recently saved)
            if let url = state.lastRecordedURL {
                Button(action: {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Show latest recording in Finder")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(white: 0.12))
        .sheet(isPresented: $state.isSavePresetSheetPresented) {
            VStack(spacing: 18) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(red: 0.98, green: 0.45, blue: 0.55))
                    Text("Save Preset")
                        .font(.headline)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Preset Name:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Preset name", text: $state.presetNameInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            state.saveCurrentPreset(named: state.presetNameInput)
                            state.isSavePresetSheetPresented = false
                        }
                }

                HStack(spacing: 12) {
                    Spacer()
                    Button("Cancel") {
                        state.isSavePresetSheetPresented = false
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Save Preset") {
                        state.saveCurrentPreset(named: state.presetNameInput)
                        state.isSavePresetSheetPresented = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(22)
            .frame(width: 320)
        }
    }

    private var routingModeSwitcher: some View {
        HStack(spacing: 2) {
            ForEach(OutputRoutingMode.allCases, id: \.self) { mode in
                Button(action: {
                    state.setRoutingMode(mode)
                }) {
                    HStack(spacing: 4) {
                        if mode == .internalSynth {
                            Image(systemName: "waveform")
                                .font(.system(size: 9))
                        } else if mode == .midiOut {
                            Image(systemName: "pianokeys")
                                .font(.system(size: 9))
                        } else {
                            Image(systemName: "waveform.badge.plus")
                                .font(.system(size: 9))
                        }
                        Text(mode.shortTitle)
                            .font(.system(size: 10, weight: state.prefs.routingMode == mode ? .bold : .medium))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        state.prefs.routingMode == mode
                            ? (mode == .midiOut ? Color.cyan.opacity(0.35) : (mode == .both ? Color.purple.opacity(0.35) : Color(red: 0.98, green: 0.45, blue: 0.55).opacity(0.35)))
                            : Color.clear
                    )
                    .foregroundColor(
                        state.prefs.routingMode == mode
                            ? (mode == .midiOut ? Color.cyan : (mode == .both ? Color(red: 0.8, green: 0.6, blue: 1.0) : Color(red: 0.98, green: 0.45, blue: 0.55)))
                            : Color.secondary
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color(white: 0.16))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(white: 0.25), lineWidth: 0.5)
        )
        .help("Global Output Routing: Internal Synth Only, MIDI Out / MPE Only, or Both")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func vuMeterView(left: Float, right: Float) -> some View {
        VStack(spacing: 3) {
            vuBar(level: left, label: "L")
            vuBar(level: right, label: "R")
        }
        .frame(width: 48)
        .padding(.horizontal, 4)
        .help("Audio output peak VU meters")
    }

    private func vuBar(level: Float, label: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 8)

            GeometryReader { geo in
                let w = geo.size.width
                let fillW = max(0, min(w, CGFloat(level) * w))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(white: 0.18))

                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(
                            LinearGradient(
                                colors: level > 0.95 ? [Color.green, Color.yellow, Color.red] : (level > 0.7 ? [Color.green, Color.yellow] : [Color.green]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillW)
                }
            }
            .frame(height: 5)
        }
    }
}
