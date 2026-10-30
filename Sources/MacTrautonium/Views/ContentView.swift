import SwiftUI
import TrautoniumKit

public struct ContentView: View {
    @StateObject private var state = AppState()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar (Presets, Recording, Title)
            HeaderBarView(state: state)

            // Play Mode Notification Banner
            if state.isPlayMode {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("PLAY MODE ACTIVE — Mouse cursor decoupled • Free multi-finger trackpad performance")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Spacer()
                    Text("Press SPACE or ESC to Exit")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12))
                .overlay(Rectangle().stroke(Color.green.opacity(0.3), lineWidth: 1))
            }

            // Upper Display: Oscilloscope & Ribbon
            VStack(spacing: 8) {
                // Real-time Waveform Oscilloscope
                OscilloscopeView(waveform: state.scopeWaveform)
                    .frame(height: 70)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                // Interactive Dual-Manual Trackpad Ribbon
                TrackpadRibbonView(state: state)
                    .padding(.horizontal, 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(state.isPlayMode ? Color.green.opacity(0.5) : Color.clear, lineWidth: 2)
                            .padding(.horizontal, 16)
                    )
            }
            .background(Color(white: 0.08))

            // Tab Selector
            HStack(spacing: 0) {
                tabButton(title: "Manual I (Lead)", index: 0, color: Color(red: 0.98, green: 0.45, blue: 0.55))
                if state.patch.isSplit {
                    tabButton(title: "Manual II (Mixtur)", index: 1, color: Color(red: 0.25, green: 0.82, blue: 0.88))
                }
                tabButton(title: "Scales, Calibration & Effects", index: 2, color: .yellow)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .background(Color(white: 0.12))

            Divider()

            // Control Sections
            ZStack {
                Color(white: 0.10).edgesIgnoringSafeArea(.all)

                switch state.selectedTab {
                case 0:
                    ManualControlView(state: state, manualIndex: 0)
                case 1:
                    ManualControlView(state: state, manualIndex: 1)
                default:
                    GlobalSettingsView(state: state)
                }
            }
            .opacity(state.isPlayMode ? 0.45 : 1.0)
            .allowsHitTesting(!state.isPlayMode)

            // Status Bar & Help Tip
            HStack {
                Image(systemName: "hand.tap")
                    .foregroundColor(state.isPlayMode ? .green : .secondary)
                Text(state.isPlayMode
                     ? "Playing Mode Active: Cursor is hidden & decoupled. Press SPACE or ESC to tweak knobs."
                     : "Press SPACE to enter Play Mode (decouples cursor for trackpad playing). Multi-finger chords supported.")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(state.isPlayMode ? .green : .secondary)
                Spacer()
                Text("Sample Rate: 48,000 Hz • PolyBLEP Anti-Aliased")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color(white: 0.07))
        }
        .frame(minWidth: 880, minHeight: 750)
        .preferredColorScheme(.dark)
        .alert("Recording Saved", isPresented: $state.showRecordedAlert) {
            Button("OK") {}
            if let url = state.lastRecordedURL {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
        } message: {
            if let url = state.lastRecordedURL {
                Text("Your performance was saved to:\n\(url.lastPathComponent)")
            } else {
                Text("Performance saved successfully.")
            }
        }
    }

    private func tabButton(title: String, index: Int, color: Color) -> some View {
        let isSelected = state.selectedTab == index
        return Button(action: {
            state.selectedTab = index
        }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color(white: 0.18) : Color.clear)
            .cornerRadius(8, corners: [.topLeft, .topRight])
        }
        .buttonStyle(.plain)
    }
}

// Corner radius extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

public struct RectCorner: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let topLeft = RectCorner(rawValue: 1 << 0)
    public static let topRight = RectCorner(rawValue: 1 << 1)
    public static let bottomLeft = RectCorner(rawValue: 1 << 2)
    public static let bottomRight = RectCorner(rawValue: 1 << 3)
    public static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let p1 = CGPoint(x: rect.minX, y: rect.minY)
        let p2 = CGPoint(x: rect.maxX, y: rect.minY)
        let p3 = CGPoint(x: rect.maxX, y: rect.maxY)
        let p4 = CGPoint(x: rect.minX, y: rect.maxY)

        path.move(to: CGPoint(x: rect.midX, y: rect.minY))

        if corners.contains(.topRight) {
            path.addLine(to: CGPoint(x: p2.x - radius, y: p2.y))
            path.addArc(center: CGPoint(x: p2.x - radius, y: p2.y + radius), radius: radius, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        } else {
            path.addLine(to: p2)
        }

        if corners.contains(.bottomRight) {
            path.addLine(to: CGPoint(x: p3.x, y: p3.y - radius))
            path.addArc(center: CGPoint(x: p3.x - radius, y: p3.y - radius), radius: radius, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        } else {
            path.addLine(to: p3)
        }

        if corners.contains(.bottomLeft) {
            path.addLine(to: CGPoint(x: p4.x + radius, y: p4.y))
            path.addArc(center: CGPoint(x: p4.x + radius, y: p4.y - radius), radius: radius, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        } else {
            path.addLine(to: p4)
        }

        if corners.contains(.topLeft) {
            path.addLine(to: CGPoint(x: p1.x, y: p1.y + radius))
            path.addArc(center: CGPoint(x: p1.x + radius, y: p1.y + radius), radius: radius, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
        } else {
            path.addLine(to: p1)
        }

        path.closeSubpath()
        return path
    }
}
