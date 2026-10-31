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
            VStack(spacing: 20) {
                // Musical Scale & Magnetic Attraction
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
        GroupBox(label: sectionHeader("Musical Scales & Magnetic Attraction (Snap)", icon: "music.note.list")) {
            VStack(alignment: .leading, spacing: 14) {
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
                                // If currently selected scale is not in this category, select the first in this category
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

                HStack(spacing: 20) {
                    // Scale Picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SCALE (\(filteredScaleIndices.count) AVAILABLE)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
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
                        Text("KEY / TONIC")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Picker("", selection: patchBinding.tonic) {
                            ForEach(0..<12, id: \.self) { pc in
                                Text(Scales.tonicNames[pc]).tag(pc)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 90)
                    }

                    // Snap Mode for Manual I
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MANUAL I SNAP")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Picker("", selection: patchBinding.manuals[0].snapMode) {
                            ForEach(SnapMode.allCases, id: \.self) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Snap Mode for Manual II
                    if state.patch.isSplit {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MANUAL II SNAP")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
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
                    Text("Magnetic Attraction Time: \(Int(prefsBinding.wrappedValue.snapSpeedMs)) ms")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    Slider(value: prefsBinding.snapSpeedMs, in: 20...300)
                        .frame(width: 200)
                    Spacer()
                    Toggle("Split Trackpad (Upper / Lower Manuals)", isOn: patchBinding.isSplit)
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .padding(.top, 8)
        }
    }

    private var filteredScaleIndices: [Int] {
        if let cat = selectedCategory {
            return Scales.all.indices.filter { Scales.all[$0].category == cat }
        }
        return Array(Scales.all.indices)
    }

    private var midiAndMPESection: some View {
        GroupBox(label: sectionHeader("Audio Routing & MIDI / MPE Output", icon: "pianokeys")) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 20) {
                    // Global Output Routing Mode
                    VStack(alignment: .leading, spacing: 4) {
                        Text("GLOBAL ROUTING")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Picker("", selection: prefsBinding.routingMode) {
                            ForEach(OutputRoutingMode.allCases, id: \.self) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(minWidth: 260)
                    }

                    // MIDI Protocol (MPE vs Standard)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MIDI PROTOCOL")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
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
                            Text("MPE BEND RANGE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Picker("", selection: prefsBinding.mpeBendRange) {
                                Text("±12 Semis").tag(12)
                                Text("±24 Semis").tag(24)
                                Text("±48 Semis (MPE Std)").tag(48)
                                Text("±96 Semis").tag(96)
                            }
                            .frame(width: 170)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BASE MIDI CHANNEL")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Picker("", selection: prefsBinding.midiBaseChannel) {
                                ForEach(1...16, id: \.self) { ch in
                                    Text("Channel \(ch)").tag(ch)
                                }
                            }
                            .frame(width: 130)
                        }
                    }
                }

                HStack(spacing: 24) {
                    // Destination Selector
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("MIDI DESTINATION")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: {
                                state.refreshMIDIDestinations()
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Refresh MIDI destinations")
                        }

                        Picker("", selection: prefsBinding.selectedMIDIDestinationName) {
                            ForEach(state.availableMIDIDestinations, id: \.self) { dest in
                                Text(dest).tag(dest)
                            }
                        }
                        .frame(minWidth: 260)
                    }

                    // Toggles for Aftertouch and CC74 Slide
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Transmit Force Touch as Aftertouch", isOn: prefsBinding.sendAftertouch)
                            .font(.system(size: 11, weight: .medium))
                        Toggle("Transmit Y-Axis as CC 74 Slide", isOn: prefsBinding.sendMPECC74)
                            .font(.system(size: 11, weight: .medium))
                    }

                    Spacer()

                    // Panic Button
                    Button(action: {
                        state.sendMIDIPanic()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .foregroundColor(.red)
                            Text("PANIC (ALL NOTES OFF)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.18))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.red.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Sends All Notes Off, All Sound Off, and resets all controllers across all 16 MIDI channels")
                }

                // Status Banner
                HStack(spacing: 8) {
                    Circle()
                        .fill(prefsBinding.wrappedValue.routingMode == .internalSynth ? Color.secondary : Color.cyan)
                        .frame(width: 8, height: 8)
                    Text("Virtual MIDI Source: 'MacTrautonium MPE' active in system. Ready for DAWs (Logic, Ableton, Bitwig, Reaper).")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    if prefsBinding.wrappedValue.midiMode == .mpe {
                        Text("MPE Lower Zone: Ch 2-16")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.15))
                            .foregroundColor(.cyan)
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(white: 0.12))
                .cornerRadius(6)
            }
            .padding(.top, 8)
        }
    }

    private var scaleNotesBanner: some View {
        let currentScaleIndex = min(state.patch.scaleIndex, Scales.all.count - 1)
        let activeScale = Scales.all[currentScaleIndex]
        let tonicName = Scales.tonicNames[state.patch.tonic % 12]
        let notesList = activeScale.notesSummary(tonic: state.patch.tonic)

        return HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "music.quarternote.3")
                    .foregroundColor(.yellow)
                Text(activeScale.name)
                    .font(.system(size: 12, weight: .bold))
                Text("in \(tonicName)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.yellow)
            }

            Text("•")
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Text("Notes:")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(notesList)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.98, green: 0.45, blue: 0.55))
            }

            Spacer()

            Text(activeScale.category.rawValue)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .cornerRadius(4)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(white: 0.12))
        .cornerRadius(8)
    }

    private func categoryPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor : Color(white: 0.18))
                .foregroundColor(isSelected ? .white : .secondary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private var hardwareCalibrationSection: some View {
        GroupBox(label: sectionHeader("Trackpad & Force Touch Sensor Calibration", icon: "hand.tap")) {
            VStack(spacing: 14) {
                HStack(spacing: 20) {
                    // Input Source
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PRESSURE SENSOR")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Picker("", selection: prefsBinding.pressSource) {
                            ForEach(PressSource.allCases, id: \.self) { src in
                                Text(src.title).tag(src)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Pressure Curve
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RESPONSE CURVE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Picker("", selection: prefsBinding.pressCurve) {
                            ForEach(PressCurve.allCases, id: \.self) { curve in
                                Text(curve.title).tag(curve)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Haptics Toggle
                    VStack(alignment: .leading, spacing: 8) {
                        Text("HAPTIC CLICKS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Toggle("Force Touch Clicks at Semitones", isOn: prefsBinding.enableHaptics)
                            .font(.system(size: 11, weight: .medium))
                    }
                }

                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PRESSURE FLOOR: \(Int(prefsBinding.wrappedValue.forceFloorGrams)) g")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Slider(value: prefsBinding.forceFloorGrams, in: 0...100)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("PRESSURE MAX: \(Int(prefsBinding.wrappedValue.forceMaxGrams)) g")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Slider(value: prefsBinding.forceMaxGrams, in: 100...600)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("MIN VOLUME LEVEL: \(Int(prefsBinding.wrappedValue.minLevel * 100))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Slider(value: prefsBinding.minLevel, in: 0.02...0.4)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("WIRE GATE: \(Int(prefsBinding.wrappedValue.gateThresholdGrams)) g")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Slider(value: prefsBinding.gateThresholdGrams, in: 0...50)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private var effectsSection: some View {
        GroupBox(label: sectionHeader("Master Audio Effects, Tape Echo & Stereo Reverb", icon: "dial.medium")) {
            VStack(spacing: 14) {
                HStack(spacing: 20) {
                    // Tube Saturation
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TUBE WARMTH: \(Int(patchBinding.wrappedValue.saturation * 100))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Slider(value: patchBinding.saturation, in: 0...0.8)
                    }

                    // Stereo Reverb
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CATHEDRAL REVERB: \(Int(patchBinding.wrappedValue.reverbMix * 100))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Slider(value: patchBinding.reverbMix, in: 0...0.9)
                    }

                    // Tape Delay Mix
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TAPE ECHO MIX: \(Int(patchBinding.wrappedValue.echoMix * 100))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Slider(value: patchBinding.echoMix, in: 0...0.8)
                    }

                    // Tape Delay Time
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ECHO TIME: \(Int(patchBinding.wrappedValue.echoTimeMs)) ms")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Slider(value: patchBinding.echoTimeMs, in: 80...1000)
                    }

                    // Master Volume
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MASTER: \(Int(prefsBinding.wrappedValue.masterVolume * 100))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Slider(value: prefsBinding.masterVolume, in: 0...1)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(.yellow)
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
    }
}
