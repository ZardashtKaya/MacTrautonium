import SwiftUI
import TrautoniumKit

public struct TrackpadRibbonView: View {
    @ObservedObject var state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background Trackpad Surface
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.12), Color(white: 0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(white: 0.22), lineWidth: 1.5)
                    )

                // Note Grid and Markers
                noteGridView(width: geo.size.width, height: geo.size.height)

                // Manual Split Line
                if state.patch.isSplit {
                    Path { path in
                        path.move(to: CGPoint(x: 16, y: geo.size.height * 0.5))
                        path.addLine(to: CGPoint(x: geo.size.width - 16, y: geo.size.height * 0.5))
                    }
                    .stroke(
                        Color(white: 0.28),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
                }

                // Active Touch Indicators (Fingers)
                ForEach(state.activeTouches) { touch in
                    touchOrbView(touch: touch, bounds: geo.size)
                }

                // Manual Section Watermarks
                VStack {
                    HStack {
                        manualLabel(
                            title: "MANUAL I (Lead)",
                            color: Color(red: 0.98, green: 0.45, blue: 0.55),
                            span: state.patch.manuals[0].span
                        )
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.leading, 18)

                    Spacer()

                    if state.patch.isSplit {
                        HStack {
                            manualLabel(
                                title: "MANUAL II (Mixtur)",
                                color: Color(red: 0.25, green: 0.82, blue: 0.88),
                                span: state.patch.manuals[1].span
                            )
                            Spacer()
                        }
                        .padding(.bottom, 10)
                        .padding(.leading, 18)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let nx = Float(max(0, min(1, value.location.x / geo.size.width)))
                        let ny = Float(max(0, min(1, value.location.y / geo.size.height)))
                        TouchInputManager.shared.setFallbackTouch(id: 9999, x: nx, y: ny, pressure: 0.75)
                    }
                    .onEnded { _ in
                        TouchInputManager.shared.removeFallbackTouch(id: 9999)
                    }
            )
        }
        .frame(height: 260)
    }

    private func manualLabel(title: String, color: Color, span: Int) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(title) • \(span) Octaves")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color.opacity(0.85))
        }
    }

    private func noteGridView(width: CGFloat, height: CGFloat) -> some View {
        Canvas { context, size in
            let edge = CGFloat(PitchRibbon.padEdgeMargin)
            let usableW = size.width * (1.0 - 2.0 * edge)
            let startX = size.width * edge

            // Render Manual I markers (top half or full)
            let m0 = state.patch.manuals[0]
            let totalSemis0 = m0.span * 12

            for s in 0...totalSemis0 {
                let u = CGFloat(s) / CGFloat(totalSemis0)
                let x = startX + u * usableW
                let midi = m0.lowNote + s
                let isInScale = Scales.contains(note: midi, scaleIndex: state.patch.scaleIndex, tonic: state.patch.tonic)
                let isTonic = (midi % 12) == (state.patch.tonic % 12)

                let yBottom = state.patch.isSplit ? size.height * 0.5 : size.height

                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: yBottom))

                let strokeColor = isTonic ? Color.yellow.opacity(0.4) : (isInScale ? Color.white.opacity(0.16) : Color.white.opacity(0.05))
                let lineWidth: CGFloat = isTonic ? 1.5 : (isInScale ? 1.0 : 0.5)
                context.stroke(path, with: .color(strokeColor), lineWidth: lineWidth)

                // Label at top
                if isTonic || (isInScale && s % 2 == 0) {
                    let noteStr = Scales.noteName(for: Float(midi))
                    let text = Text(noteStr)
                        .font(.system(size: 9, weight: isTonic ? .bold : .medium, design: .monospaced))
                        .foregroundColor(isTonic ? .yellow : .white.opacity(0.6))
                    context.draw(text, at: CGPoint(x: x, y: 14))
                }
            }

            // Render Manual II markers (bottom half)
            if state.patch.isSplit {
                let m1 = state.patch.manuals[1]
                let totalSemis1 = m1.span * 12

                for s in 0...totalSemis1 {
                    let u = CGFloat(s) / CGFloat(totalSemis1)
                    let x = startX + u * usableW
                    let midi = m1.lowNote + s
                    let isInScale = Scales.contains(note: midi, scaleIndex: state.patch.scaleIndex, tonic: state.patch.tonic)
                    let isTonic = (midi % 12) == (state.patch.tonic % 12)

                    var path = Path()
                    path.move(to: CGPoint(x: x, y: size.height * 0.5))
                    path.addLine(to: CGPoint(x: x, y: size.height))

                    let strokeColor = isTonic ? Color.yellow.opacity(0.4) : (isInScale ? Color.white.opacity(0.16) : Color.white.opacity(0.05))
                    let lineWidth: CGFloat = isTonic ? 1.5 : (isInScale ? 1.0 : 0.5)
                    context.stroke(path, with: .color(strokeColor), lineWidth: lineWidth)

                    if isTonic || (isInScale && s % 2 == 0) {
                        let noteStr = Scales.noteName(for: Float(midi))
                        let text = Text(noteStr)
                            .font(.system(size: 9, weight: isTonic ? .bold : .medium, design: .monospaced))
                            .foregroundColor(isTonic ? .yellow : .white.opacity(0.6))
                        context.draw(text, at: CGPoint(x: x, y: size.height - 14))
                    }
                }
            }
        }
    }

    private func touchOrbView(touch: SynthTouchSnapshot, bounds: CGSize) -> some View {
        let x = CGFloat(touch.x) * bounds.width
        let y = CGFloat(touch.y) * bounds.height
        let color = touch.manual == 0 ? Color(red: 0.98, green: 0.45, blue: 0.55) : Color(red: 0.25, green: 0.82, blue: 0.88)
        let haloRadius = 24.0 + CGFloat(touch.normalizedPressure) * 36.0

        let noteName = Scales.noteName(for: touch.soundingMidi)
        let cents = Scales.centsOffset(fromExactMidi: touch.soundingMidi)
        let centsStr = cents >= 0 ? "+\(cents)¢" : "\(cents)¢"

        return ZStack {
            // Pressure Halo (Force Touch expression)
            Circle()
                .stroke(color.opacity(0.45), lineWidth: 2)
                .frame(width: haloRadius * 2, height: haloRadius * 2)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.6), color.opacity(0.0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: haloRadius
                    )
                )
                .frame(width: haloRadius * 2, height: haloRadius * 2)

            // Center Touch Core
            Circle()
                .fill(Color.white)
                .frame(width: 12, height: 12)
                .shadow(color: color, radius: 8)

            // Floating Note & Pressure Badge
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text(noteName)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(centsStr)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(abs(cents) <= 5 ? .green : .white.opacity(0.8))
                }

                if touch.pressureGrams > 0 {
                    Text("\(Int(touch.pressureGrams))g")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(color.opacity(0.9))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.85))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 1))
            .offset(y: -42)
        }
        .position(x: x, y: y)
    }
}
