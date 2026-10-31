import SwiftUI
import TrautoniumKit

public struct GlobalSettingsView: View {
    @ObservedObject var state: AppState
    @State private var selectedCategory: ScaleCategory? = nil

    public init(state: AppState) {
        self.state = state
    }

    private var patchBinding: Binding<TrautoniumPatch> {
        Binding(
            get: { state.patch },
            set: {
                state.patch = $0
                state.updatePatch()
            }
        )
    }

    private var prefsBinding: Binding<TrautoniumPrefs> {
        Binding(
            get: { state.prefs },
            set: {
                state.prefs = $0
                state.updatePrefs()
            }
        )
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                // Musical Scales & Magnetic Attraction
                scaleAndSnapSection

                // Audio Routing & MIDI / MPE Output
                midiAndMPESection

                // Trackpad & Force Touch Hardware Settings
                hardwareCalibrationSection

                // Master Effects & Saturation
                effectsSection
            }
            .padding(16)
        }
    }

    private var scaleAndSnapSection: some View {
        cardContainer(title: "Musical scales & attraction") {
            VStack(alignment: .leading, spacing: 12) {
                // Category Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        categoryPill(title: "All (\(Scales.all.count))", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(ScaleCategory.allCases, id: \.self) { cat in
                            let count = Scales.all.filter { $0.category == cat }.count
                            categoryPill(title: "\(cat.rawValue) (\(count))", isSelected: selectedCategory == cat) {
                                selectedCategory = cat
                                let current = (state.patch.scaleIndex < Scales.all.count) ? Scales.all[state.patch.scaleIndex] : Scales.all[0]
                                if current.category != cat {
                                    if let firstIdx = Scales.all.firstIndex(where: { $0.category == cat }) {
                                        state.patch.scaleIndex = firstIdx
                                        state.updatePatch()
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                HStack(spacing: 16) {
                    // Scale Picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scale (\(filteredScaleIndices.count) available)")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Picker("", selection: patchBinding.scaleIndex) {
                            if let cat = selectedCategory {
                                ForEach(Scales.all.indices.filter { Scales.all[$0].category == cat }, id: \.self) { idx in
                                    Text(Scales.all[idx].name).tag(idx)
                                }
                            } else {
                                ForEach(ScaleCategory.allCases, id: \.self) { cat in
                                    Section(cat.rawValue) {
                                        ForEach(Scales.all.indices.filter { Scales.all[$0].category == cat }, id: \.self) { idx in
                                            Text(Scales.all[idx].name).tag(idx)
                                        }
                                    }
                                }
                            }
                        }
                        .labelsHidden()
                        .frame(minWidth: 200)
                    }

                    // Key / Tonic
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Root note")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Picker("", selection: patchBinding.tonic) {
                            ForEach(0..<12, id: \.self) { pc in
                                Text(Scales.tonicNames[pc]).tag(pc)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 80)
                    }

                    // Snap Mode for Manual 1
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Manual 1 snap")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Picker("", selection: patchBinding.manuals[0].snapMode) {
                            ForEach(SnapMode.allCases, id: \.self) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Snap Mode for Manual 2
                    if state.patch.isSplit {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Manual 2 snap")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(TrautoniumTheme.textSecondary)
                            Picker("", selection: patchBinding.manuals[1].snapMode) {
                                ForEach(SnapMode.allCases, id: \.self) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }

                // Live Scale Notes Preview Banner
                scaleNotesBanner

                HStack {
                    Text("Attraction time: \(Int(prefsBinding.wrappedValue.snapSpeedMs)) ms")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(TrautoniumTheme.textSecondary)
                    Slider(value: prefsBinding.snapSpeedMs, in: 20...300)
                        .frame(width: 160)
                    Spacer()
                    Toggle("Split trackpad (Upper / lower manuals)", isOn: patchBinding.isSplit)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(TrautoniumTheme.textSecondary)
                }
            }
        }
    }

    private var filteredScaleIndices: [Int] {
        if let cat = selectedCategory {
            return Scales.all.indices.filter { Scales.all[$0].category == cat }
        }
        return Array(Scales.all.indices)
    }

    private var midiAndMPESection: some View {
        cardContainer(title: "Audio & MIDI routing") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    // Global Output Routing Mode
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Routing mode")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Picker("", selection: prefsBinding.routingMode) {
                            ForEach(OutputRoutingMode.allCases, id: \.self) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(minWidth: 240)
                    }

                    // MIDI Protocol (MPE vs Standard)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Protocol")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Picker("", selection: prefsBinding.midiMode) {
                            ForEach(MIDIMode.allCases, id: \.self) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // MPE Pitch Bend Range or Base Channel
                    if prefsBinding.wrappedValue.midiMode == .mpe {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MPE bend range")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(TrautoniumTheme.textSecondary)
                            Picker("", selection: prefsBinding.mpeBendRange) {
                                Text("±12 semis").tag(12)
                                Text("±24 semis").tag(24)
                                Text("±48 semis (MPE std)").tag(48)
                                Text("±96 semis").tag(96)
                            }
                            .frame(width: 160)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Base channel")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(TrautoniumTheme.textSecondary)
                            Picker("", selection: prefsBinding.midiBaseChannel) {
                                ForEach(1...16, id: \.self) { ch in
                                    Text("Channel \(ch)").tag(ch)
                                }
                            }
                            .frame(width: 120)
                        }
                    }
                }

                // Audio Output Device (Standalone)
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Audio output device")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(TrautoniumTheme.textSecondary)
                            Spacer()
                            if !state.isPluginMode {
                                Button(action: {
                                    state.refreshAudioDevices()
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 9))
                                        .foregroundColor(TrautoniumTheme.textMuted)
                                }
                                .buttonStyle(.plain)
                                .help("Refresh audio output devices")
                            }
                        }

                        if state.isPluginMode {
                            Text("Host DAW Output (Managed by AUv2 / VST3)")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(TrautoniumTheme.textMuted)
                        } else {
                            Picker("", selection: Binding(
                                get: { state.prefs.selectedAudioOutputDeviceUID },
                                set: { state.selectAudioOutputDevice(uid: $0) }
                            )) {
                                Text("System Default Output").tag("")
                                ForEach(state.availableAudioDevices) { dev in
                                    Text(dev.name).tag(dev.uid)
                                }
                            }
                            .frame(minWidth: 240)
                        }
                    }

                    Spacer()
                }

                HStack(spacing: 20) {
                    // Destination Selector
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("MIDI destination")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(TrautoniumTheme.textSecondary)
                            Spacer()
                            Button(action: {
                                state.refreshMIDIDestinations()
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 9))
                                    .foregroundColor(TrautoniumTheme.textMuted)
                            }
                            .buttonStyle(.plain)
                            .help("Refresh MIDI destinations")
                        }

                        Picker("", selection: prefsBinding.selectedMIDIDestinationName) {
                            ForEach(state.availableMIDIDestinations, id: \.self) { dest in
                                Text(dest).tag(dest)
                            }
                        }
                        .frame(minWidth: 240)
                    }

                    // Toggles
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Force Touch as aftertouch", isOn: prefsBinding.sendAftertouch)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Toggle("Y-axis as CC 74 slide", isOn: prefsBinding.sendMPECC74)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                    }

                    Spacer()

                    // Panic Button
                    Button(action: {
                        state.sendMIDIPanic()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "exclamationmark.octagon")
                                .font(.system(size: 11))
                            Text("Panic")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(TrautoniumTheme.bgRaised)
                        .foregroundColor(TrautoniumTheme.recordingRed)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(TrautoniumTheme.recordingRed.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Sends All Notes Off across channels 1–16")
                }

                // Quiet status line
                HStack(spacing: 6) {
                    Circle()
                        .fill(prefsBinding.wrappedValue.routingMode == .internalSynth ? TrautoniumTheme.textMuted : TrautoniumTheme.accent)
                        .frame(width: 5, height: 5)
                    Text("Virtual MIDI port: 'MacTrautonium MPE' active in system")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(TrautoniumTheme.textMuted)
                    Spacer()
                    if prefsBinding.wrappedValue.midiMode == .mpe {
                        Text("Lower zone ch 2–16")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(TrautoniumTheme.textMuted)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var hardwareCalibrationSection: some View {
        cardContainer(title: "Trackpad & sensor calibration") {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    // Input Source
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pressure sensor")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Picker("", selection: prefsBinding.pressSource) {
                            ForEach(PressSource.allCases, id: \.self) { src in
                                Text(src.title).tag(src)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Pressure Curve
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Response curve")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Picker("", selection: prefsBinding.pressCurve) {
                            ForEach(PressCurve.allCases, id: \.self) { curve in
                                Text(curve.title).tag(curve)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Haptics Toggle
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Haptic clicks")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Toggle("Click at semitones", isOn: prefsBinding.enableHaptics)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                    }
                }

                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pressure floor: \(Int(prefsBinding.wrappedValue.forceFloorGrams)) g")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Slider(value: prefsBinding.forceFloorGrams, in: 0...100)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pressure max: \(Int(prefsBinding.wrappedValue.forceMaxGrams)) g")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Slider(value: prefsBinding.forceMaxGrams, in: 100...600)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Min level: \(Int(prefsBinding.wrappedValue.minLevel * 100))%")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Slider(value: prefsBinding.minLevel, in: 0.02...0.4)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gate threshold: \(Int(prefsBinding.wrappedValue.gateThresholdGrams)) g")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Slider(value: prefsBinding.gateThresholdGrams, in: 0...50)
                    }
                }
            }
        }
    }

    private var effectsSection: some View {
        cardContainer(title: "Master effects") {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    // Tube Saturation
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Drive: \(Int(patchBinding.wrappedValue.saturation * 100))%")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Slider(value: patchBinding.saturation, in: 0...0.8)
                    }

                    // Stereo Reverb
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reverb: \(Int(patchBinding.wrappedValue.reverbMix * 100))%")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Slider(value: patchBinding.reverbMix, in: 0...0.9)
                    }

                    // Tape Delay Mix
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Echo mix: \(Int(patchBinding.wrappedValue.echoMix * 100))%")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Slider(value: patchBinding.echoMix, in: 0...0.8)
                    }

                    // Tape Delay Time
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Echo time: \(Int(patchBinding.wrappedValue.echoTimeMs)) ms")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Slider(value: patchBinding.echoTimeMs, in: 80...1000)
                    }

                    // Master Volume
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Master volume: \(Int(prefsBinding.wrappedValue.masterVolume * 100))%")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Slider(value: prefsBinding.masterVolume, in: 0...1)
                    }
                }
            }
        }
    }

    private var scaleNotesBanner: some View {
        let currentScaleIndex = min(state.patch.scaleIndex, Scales.all.count - 1)
        let activeScale = Scales.all[currentScaleIndex]
        let tonicName = Scales.tonicNames[state.patch.tonic % 12]
        let notesList = activeScale.notesSummary(tonic: state.patch.tonic)

        return HStack(spacing: 8) {
            Text("\(activeScale.name) in \(tonicName)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(TrautoniumTheme.textPrimary)

            Text("·")
                .foregroundColor(TrautoniumTheme.textMuted)

            Text("Notes: \(notesList)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(TrautoniumTheme.textSecondary)

            Spacer()

            Text(activeScale.category.rawValue)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(TrautoniumTheme.textMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(TrautoniumTheme.bgRaised)
        .cornerRadius(6)
    }

    private func categoryPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .medium : .regular))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? TrautoniumTheme.bgRaised : Color.clear)
                .foregroundColor(isSelected ? TrautoniumTheme.textPrimary : TrautoniumTheme.textMuted)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? TrautoniumTheme.hairlineStrong : TrautoniumTheme.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func cardContainer<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(TrautoniumTheme.textPrimary)

            content()
        }
        .padding(14)
        .background(TrautoniumTheme.bgCard)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(TrautoniumTheme.hairline, lineWidth: 1)
        )
    }
}
