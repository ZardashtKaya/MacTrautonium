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
            VStack(spacing: 16) {
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
        cardContainer(title: "Oscillator & pitch") {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    // Waveform Picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Waveform")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Picker("", selection: paramsBinding.waveform) {
                            ForEach(WaveformType.allCases, id: \.self) { wave in
                                Text(wave.title).tag(wave)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Octave Span
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Span: \(paramsBinding.wrappedValue.span) octaves")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Stepper("", value: paramsBinding.span, in: 1...4)
                            .labelsHidden()
                    }

                    // Low Note (Left Edge)
                    VStack(alignment: .leading, spacing: 4) {
                        let noteName = Scales.noteName(for: Float(paramsBinding.wrappedValue.lowNote))
                        Text("Low note: \(noteName)")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Stepper("", value: paramsBinding.lowNote, in: 24...84)
                            .labelsHidden()
                    }

                    // Portamento Glide
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Glide: \(Int(paramsBinding.wrappedValue.glideMs)) ms")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Slider(value: paramsBinding.glideMs, in: 5...100)
                    }
                }

                HStack {
                    Toggle("Monophonic legato", isOn: paramsBinding.isMono)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(TrautoniumTheme.textSecondary)
                    Spacer()
                    Text("Drift: \(Int(paramsBinding.wrappedValue.analogDrift * 100))%")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(TrautoniumTheme.textMuted)
                    Slider(value: paramsBinding.analogDrift, in: 0...1)
                        .frame(width: 100)
                }
            }
        }
    }

    private var subharmonicMixturSection: some View {
        cardContainer(title: "Subharmonic mixture") {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    // Fundamental Level
                    VStack(spacing: 6) {
                        Text("Fundamental f₀")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(TrautoniumTheme.accent)
                        Slider(value: paramsBinding.mainLevel, in: 0...1)
                        Text("\(Int(paramsBinding.wrappedValue.mainLevel * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(TrautoniumTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity)

                    Divider()
                        .frame(height: 56)
                        .overlay(TrautoniumTheme.hairline)

                    // 4 Subharmonic Columns
                    ForEach(0..<4, id: \.self) { idx in
                        subharmonicColumn(index: idx)
                    }
                }
            }
        }
    }

    private func subharmonicColumn(index: Int) -> some View {
        let div = paramsBinding.wrappedValue.subDividers[index]
        let lvl = paramsBinding.wrappedValue.subLevels[index]

        return VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text("Sub \(index + 1)")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(TrautoniumTheme.textMuted)
                Text("f/\(div)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(TrautoniumTheme.textPrimary)
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
                .foregroundColor(TrautoniumTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var formantFilterSection: some View {
        cardContainer(title: "Formant filters & tone") {
            VStack(spacing: 12) {
                HStack(spacing: 24) {
                    // Vowel Selector
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vowel formant")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        HStack(spacing: 4) {
                            vowelButton(title: "Off", value: -1)
                            vowelButton(title: "A", value: 0)
                            vowelButton(title: "E", value: 1)
                            vowelButton(title: "I", value: 2)
                            vowelButton(title: "O", value: 3)
                            vowelButton(title: "U", value: 4)
                        }
                    }

                    // Register Selector
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Register")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Picker("", selection: paramsBinding.register) {
                            Text("Bass").tag(0)
                            Text("Tenor").tag(1)
                            Text("Soprano").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                }

                HStack(spacing: 16) {
                    // Cutoff
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cutoff: \(Int(paramsBinding.wrappedValue.cutoff)) Hz")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Slider(value: paramsBinding.cutoff, in: 100...8000)
                    }

                    // Resonance
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Resonance: \(Int(paramsBinding.wrappedValue.resonance * 100))%")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Slider(value: paramsBinding.resonance, in: 0...0.92)
                    }

                    // Pressure to Brightness
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pressure brightness: +\(Int(paramsBinding.wrappedValue.pressureBrightness * 300))%")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Slider(value: paramsBinding.pressureBrightness, in: 0...1)
                    }
                }
            }
        }
    }

    private func vowelButton(title: String, value: Int) -> some View {
        let isSelected = paramsBinding.wrappedValue.vowel == value

        return Button(action: {
            paramsBinding.wrappedValue.vowel = value
            state.updatePatch()
        }) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? TrautoniumTheme.textPrimary : TrautoniumTheme.textSecondary)
                .frame(width: 34, height: 24)
                .background(isSelected ? TrautoniumTheme.bgRaised : TrautoniumTheme.bgDeep)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? TrautoniumTheme.hairlineStrong : TrautoniumTheme.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var envelopeSection: some View {
        cardContainer(title: "Envelope & volume") {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    // Attack
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Attack: \(Int(paramsBinding.wrappedValue.attackMs)) ms")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Slider(value: paramsBinding.attackMs, in: 1...500)
                    }

                    // Decay
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Decay: \(Int(paramsBinding.wrappedValue.decayMs)) ms")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Slider(value: paramsBinding.decayMs, in: 20...1500)
                    }

                    // Sustain
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sustain: \(Int(paramsBinding.wrappedValue.sustain * 100))%")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Slider(value: paramsBinding.sustain, in: 0...1)
                    }

                    // Release
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Release: \(Int(paramsBinding.wrappedValue.releaseMs)) ms")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Slider(value: paramsBinding.releaseMs, in: 10...2000)
                    }

                    // Volume
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Volume: \(Int(paramsBinding.wrappedValue.volume * 100))%")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(TrautoniumTheme.textSecondary)
                        Slider(value: paramsBinding.volume, in: 0...1)
                    }
                }
            }
        }
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
