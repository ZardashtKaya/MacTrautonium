import SwiftUI
import TrautoniumKit

public struct HeaderBarView: View {
    @ObservedObject var state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 12) {
            // App Branding
            HStack(spacing: 8) {
                Image(systemName: "waveform.path")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(TrautoniumTheme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("MacTrautonium")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(TrautoniumTheme.textPrimary)
                    Text("Mixtur-Trautonium · Force Touch")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundColor(TrautoniumTheme.textMuted)
                }
            }

            Spacer()

            // Presets Dropdown
            Menu {
                // Factory Presets Section
                Section("Factory presets") {
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
                    Section("User presets") {
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
                        Label("Save current preset...", systemImage: "square.and.arrow.down")
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
                        Label("Open presets folder in Finder", systemImage: "folder")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10))
                        .foregroundColor(TrautoniumTheme.textMuted)
                    Text(state.patch.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(TrautoniumTheme.textPrimary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                        .foregroundColor(TrautoniumTheme.textMuted)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(TrautoniumTheme.bgRaised)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(TrautoniumTheme.hairline, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)

            // Save Preset Button
            Button(action: {
                state.openSavePresetDialog()
            }) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 11))
                    .foregroundColor(TrautoniumTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(TrautoniumTheme.bgRaised)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(TrautoniumTheme.hairline, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("Save current patch as preset")

            Divider()
                .frame(height: 16)
                .overlay(TrautoniumTheme.hairline)

            // Global Routing Mode (Synth / MIDI / Both)
            routingModeSwitcher

            Divider()
                .frame(height: 16)
                .overlay(TrautoniumTheme.hairline)

            // Play Mode Button
            Button(action: {
                state.togglePlayMode()
            }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(state.isPlayMode ? TrautoniumTheme.playGreen : TrautoniumTheme.textMuted)
                        .frame(width: 6, height: 6)
                    Text(state.isPlayMode ? "Playing" : "Play")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(state.isPlayMode ? TrautoniumTheme.textPrimary : TrautoniumTheme.textSecondary)
                    Text("Space")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(TrautoniumTheme.textMuted)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(TrautoniumTheme.bgDeep)
                        .cornerRadius(3)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(state.isPlayMode ? TrautoniumTheme.playGreen.opacity(0.12) : TrautoniumTheme.bgRaised)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(state.isPlayMode ? TrautoniumTheme.playGreen.opacity(0.3) : TrautoniumTheme.hairline, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Toggle performance mode (decouples cursor for multi-touch performance)")

            Divider()
                .frame(height: 16)
                .overlay(TrautoniumTheme.hairline)

            // Stereo Peak Meter
            vuMeterView(left: state.peakLevels.left, right: state.peakLevels.right)

            Divider()
                .frame(height: 16)
                .overlay(TrautoniumTheme.hairline)

            // WAV Recorder Button
            Button(action: {
                state.toggleRecording()
            }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(state.isRecording ? TrautoniumTheme.recordingRed : TrautoniumTheme.textMuted)
                        .frame(width: 6, height: 6)
                    if state.isRecording {
                        Text(formatDuration(state.recordingDuration))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(TrautoniumTheme.recordingRed)
                    } else {
                        Text("Record")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(state.isRecording ? TrautoniumTheme.recordingRed.opacity(0.12) : TrautoniumTheme.bgRaised)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(state.isRecording ? TrautoniumTheme.recordingRed.opacity(0.3) : TrautoniumTheme.hairline, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if let url = state.lastRecordedURL {
                Button(action: {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                        .foregroundColor(TrautoniumTheme.textMuted)
                }
                .buttonStyle(.plain)
                .help("Show latest recording in Finder")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(TrautoniumTheme.bgDeep)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(TrautoniumTheme.hairline),
            alignment: .bottom
        )
        .sheet(isPresented: $state.isSavePresetSheetPresented) {
            savePresetSheet
        }
    }

    private var routingModeSwitcher: some View {
        HStack(spacing: 2) {
            ForEach(OutputRoutingMode.allCases, id: \.self) { mode in
                let isSelected = state.prefs.routingMode == mode
                Button(action: {
                    state.setRoutingMode(mode)
                }) {
                    Text(mode.shortTitle)
                        .font(.system(size: 10, weight: isSelected ? .medium : .regular))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isSelected ? TrautoniumTheme.bgRaised : Color.clear)
                        .foregroundColor(isSelected ? TrautoniumTheme.textPrimary : TrautoniumTheme.textMuted)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(TrautoniumTheme.bgPage)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(TrautoniumTheme.hairline, lineWidth: 1)
        )
    }

    private var savePresetSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Save preset")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(TrautoniumTheme.textPrimary)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Preset name")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(TrautoniumTheme.textMuted)
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

                Button("Save preset") {
                    state.saveCurrentPreset(named: state.presetNameInput)
                    state.isSavePresetSheetPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 300)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func vuMeterView(left: Float, right: Float) -> some View {
        VStack(spacing: 2) {
            vuBar(level: left)
            vuBar(level: right)
        }
        .frame(width: 36)
    }

    private func vuBar(level: Float) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let fillW = max(0, min(w, CGFloat(level) * w))
            let isClip = level > 0.98

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(TrautoniumTheme.bgPage)

                RoundedRectangle(cornerRadius: 1)
                    .fill(isClip ? TrautoniumTheme.recordingRed : TrautoniumTheme.accent)
                    .frame(width: fillW)
            }
        }
        .frame(height: 3)
    }
}
