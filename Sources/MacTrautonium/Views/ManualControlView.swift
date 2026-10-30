import SwiftUI
import TrautoniumKit

public struct ManualControlView: View {
    @ObservedObject var state: AppState
    let manualIndex: Int

    public init(state: AppState, manualIndex: Int) {
        self.state = state
        self.manualIndex = manualIndex
    }

    private var paramsBinding: Binding<ManualParams> {
        Binding(
            get: { state.patch.manuals[manualIndex] },
            set: {
                state.patch.manuals[manualIndex] = $0
                state.updatePatch()
            }
        )
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // Section 1: Oscillator & Pitch Span
                oscillatorSection

                // Section 2: Subharmonic Mixture Matrix (Mixtur-Trautonium)
                subharmonicMixturSection

                // Section 3: Vowel Formants & Tone Filter
                formantFilterSection

                // Section 4: Dynamic ADSR Envelope
                envelopeSection
            }
            .padding(16)
        }
    }

    private var oscillatorSection: some View {
        GroupBox(label: sectionHeader("1. Master Relaxation Oscillator & Pitch", icon: "waveform.path")) {
            VStack(spacing: 14) {
                HStack(spacing: 20) {
                    // Waveform Picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("WAVEFORM")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Picker("", selection: paramsBinding.waveform) {
                            ForEach(WaveformType.allCases, id: \.self) { wave in
                                Text(wave.title).tag(wave)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Octave Span
                    VStack(alignment: .leading, spacing: 6) {
                        Text("RIBBON SPAN: \(paramsBinding.wrappedValue.span) OCTAVES")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Stepper("", value: paramsBinding.span, in: 1...4)
                            .labelsHidden()
                    }

                    // Low Note (Left Edge)
                    VStack(alignment: .leading, spacing: 6) {
                        let noteName = Scales.noteName(for: Float(paramsBinding.wrappedValue.lowNote))
                        Text("LOW NOTE: \(noteName) (MIDI \(paramsBinding.wrappedValue.lowNote))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Stepper("", value: paramsBinding.lowNote, in: 24...84)
                            .labelsHidden()
                    }

                    // Portamento Glide
                    VStack(alignment: .leading, spacing: 6) {
                        Text("GLIDE: \(Int(paramsBinding.wrappedValue.glideMs)) ms")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Slider(value: paramsBinding.glideMs, in: 5...100)
                    }
                }

                HStack {
                    Toggle("Monophonic Legato (Wire Takeover)", isOn: paramsBinding.isMono)
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text("Analog Drift: \(Int(paramsBinding.wrappedValue.analogDrift * 100))%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Slider(value: paramsBinding.analogDrift, in: 0...1)
                        .frame(width: 120)
                }
            }
            .padding(.top, 8)
        }
    }

    private var subharmonicMixturSection: some View {
        GroupBox(label: sectionHeader("2. Subharmonic Mixture (Mixtur Dividers f/N)", icon: "slider.vertical.3")) {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    // Fundamental Level
                    VStack(spacing: 6) {
                        Text("MAIN f₀")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)
                        Slider(value: paramsBinding.mainLevel, in: 0...1)
                        Text("\(Int(paramsBinding.wrappedValue.mainLevel * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 60)

                    // 4 Subharmonic Columns
                    ForEach(0..<4, id: \.self) { idx in
                        subharmonicColumn(index: idx)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private func subharmonicColumn(index: Int) -> some View {
        let div = paramsBinding.wrappedValue.subDividers[index]
        let lvl = paramsBinding.wrappedValue.subLevels[index]

        return VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text("SUB \(index + 1)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                Text("f/\(div)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(manualIndex == 0 ? Color(red: 0.98, green: 0.45, blue: 0.55) : Color(red: 0.25, green: 0.82, blue: 0.88))
            }

            Stepper("", value: Binding(
                get: { paramsBinding.wrappedValue.subDividers[index] },
                set: {
                    paramsBinding.wrappedValue.subDividers[index] = $0
                    state.updatePatch()
                }
            ), in: 1...24)
            .labelsHidden()

            Slider(value: Binding(
                get: { lvl },
                set: {
                    paramsBinding.wrappedValue.subLevels[index] = $0
                    state.updatePatch()
                }
            ), in: 0...1)

            Text("\(Int(lvl * 100))%")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var formantFilterSection: some View {
        GroupBox(label: sectionHeader("3. Acoustic Vowel Formant Filters & Tone Cutoff", icon: "waveform")) {
            VStack(spacing: 14) {
                HStack(spacing: 24) {
                    // Vowel Selector
                    VStack(alignment: .leading, spacing: 6) {
                        Text("VOWEL FORMANT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        HStack(spacing: 6) {
                            vowelButton(title: "OFF", value: -1)
                            vowelButton(title: "A", value: 0)
                            vowelButton(title: "E", value: 1)
                            vowelButton(title: "I", value: 2)
                            vowelButton(title: "O", value: 3)
                            vowelButton(title: "U", value: 4)
                        }
                    }

                    // Register Selector
                    VStack(alignment: .leading, spacing: 6) {
                        Text("REGISTER")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Picker("", selection: paramsBinding.register) {
                            Text("Bass").tag(0)
                            Text("Tenor").tag(1)
                            Text("Soprano").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                }

                HStack(spacing: 20) {
                    // Cutoff
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CUTOFF: \(Int(paramsBinding.wrappedValue.cutoff)) Hz")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Slider(value: paramsBinding.cutoff, in: 100...8000)
                    }

                    // Resonance
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RESONANCE: \(Int(paramsBinding.wrappedValue.resonance * 100))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Slider(value: paramsBinding.resonance, in: 0...0.92)
                    }

                    // Pressure to Brightness
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PRESSURE BRIGHTNESS: +\(Int(paramsBinding.wrappedValue.pressureBrightness * 300))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Slider(value: paramsBinding.pressureBrightness, in: 0...1)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private func vowelButton(title: String, value: Int) -> some View {
        let isSelected = paramsBinding.wrappedValue.vowel == value
        let accentColor = manualIndex == 0 ? Color(red: 0.98, green: 0.45, blue: 0.55) : Color(red: 0.25, green: 0.82, blue: 0.88)

        return Button(action: {
            paramsBinding.wrappedValue.vowel = value
            state.updatePatch()
        }) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .black : .white)
                .frame(width: 38, height: 26)
                .background(isSelected ? accentColor : Color(white: 0.2))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private var envelopeSection: some View {
        GroupBox(label: sectionHeader("4. Dynamic Envelope & Volume", icon: "timer")) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ATTACK: \(Int(paramsBinding.wrappedValue.attackMs)) ms")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Slider(value: paramsBinding.attackMs, in: 1...500)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("DECAY: \(Int(paramsBinding.wrappedValue.decayMs)) ms")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Slider(value: paramsBinding.decayMs, in: 10...2000)
                }

                VStack(alignment: .leading, spacing: 4) {
                    let sus = paramsBinding.wrappedValue.sustain
                    Text("SUSTAIN: \(Int(sus * 100))%\(sus == 0 ? " (Pluck)" : "")")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Slider(value: paramsBinding.sustain, in: 0...1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("RELEASE: \(Int(paramsBinding.wrappedValue.releaseMs)) ms")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Slider(value: paramsBinding.releaseMs, in: 10...3000)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("VOLUME: \(Int(paramsBinding.wrappedValue.volume * 100))%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Slider(value: paramsBinding.volume, in: 0...1)
                }
            }
            .padding(.top, 8)
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(manualIndex == 0 ? Color(red: 0.98, green: 0.45, blue: 0.55) : Color(red: 0.25, green: 0.82, blue: 0.88))
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
    }
}
