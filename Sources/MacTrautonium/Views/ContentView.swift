import SwiftUI
import TrautoniumKit

public struct ContentView: View {
    @StateObject private var state = AppState()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HeaderBarView(state: state)

            // Performance Mode Banner (when decoupled)
            if state.isPlayMode {
                HStack(spacing: 8) {
                    Circle()
                        .fill(TrautoniumTheme.playGreen)
                        .frame(width: 6, height: 6)
                    Text("Performance mode active · Trackpad dedicated to instrument")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(TrautoniumTheme.textSecondary)
                    Spacer()
                    Text("Space or Esc to exit")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(TrautoniumTheme.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(TrautoniumTheme.bgDeep)
                        .cornerRadius(4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(TrautoniumTheme.bgRaised)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(TrautoniumTheme.hairline),
                    alignment: .bottom
                )
            }

            // Instrument Workspace: Oscilloscope & Trackpad Ribbon
            VStack(spacing: 12) {
                // Waveform CRT Monitor
                OscilloscopeView(waveform: state.scopeWaveform)
                    .frame(height: 64)

                // Precision Ribbon
                TrackpadRibbonView(state: state)
            }
            .padding(16)
            .background(TrautoniumTheme.bgDeep)

            // Tab Navigation
            HStack(spacing: 4) {
                tabButton(title: "Manual 1", index: 0)
                if state.patch.isSplit {
                    tabButton(title: "Manual 2", index: 1)
                }
                tabButton(title: "Scales & routing", index: 2)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .background(TrautoniumTheme.bgDeep)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(TrautoniumTheme.hairline),
                alignment: .bottom
            )

            // Parameter Console
            ZStack {
                TrautoniumTheme.bgPage.edgesIgnoringSafeArea(.all)

                switch state.selectedTab {
                case 0:
                    ManualControlView(state: state, manualIndex: 0)
                case 1:
                    ManualControlView(state: state, manualIndex: 1)
                default:
                    GlobalSettingsView(state: state)
                }
            }
            .opacity(state.isPlayMode ? 0.35 : 1.0)
            .allowsHitTesting(!state.isPlayMode)

            // Status Bar
            HStack {
                Image(systemName: "hand.point.up")
                    .font(.system(size: 10))
                    .foregroundColor(TrautoniumTheme.textMuted)
                Text(state.isPlayMode
                     ? "Performance mode active. Press Space to restore cursor."
                     : "Press Space to enter performance mode. Multi-finger chords supported.")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(TrautoniumTheme.textMuted)
                Spacer()
                Text("48 kHz · Polyphonic · MPE ready")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(TrautoniumTheme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(TrautoniumTheme.bgDeep)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(TrautoniumTheme.hairline),
                alignment: .top
            )
        }
        .frame(minWidth: 880, minHeight: 740)
        .preferredColorScheme(.dark)
        .alert("Recording saved", isPresented: $state.showRecordedAlert) {
            Button("OK") {}
            if let url = state.lastRecordedURL {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
        } message: {
            if let url = state.lastRecordedURL {
                Text("Saved to:\n\(url.lastPathComponent)")
            } else {
                Text("Performance saved successfully.")
            }
        }
    }

    private func tabButton(title: String, index: Int) -> some View {
        let isSelected = state.selectedTab == index
        return Button(action: {
            state.selectedTab = index
        }) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? TrautoniumTheme.textPrimary : TrautoniumTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 6)

                // Subtle bottom indicator line for active tab
                Rectangle()
                    .fill(isSelected ? TrautoniumTheme.accent : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }
}
