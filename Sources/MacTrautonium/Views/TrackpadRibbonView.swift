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
                RoundedRectangle(cornerRadius: 12)
                    .fill(TrautoniumTheme.bgCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(TrautoniumTheme.hairline, lineWidth: 1)
                    )

                // Note Grid and Resistance Ribbon Markers
                noteGridView(width: geo.size.width, height: geo.size.height)

                // Manual Split Line
                if state.patch.isSplit {
                    Path { path in
                        path.move(to: CGPoint(x: 16, y: geo.size.height * 0.5))
                        path.addLine(to: CGPoint(x: geo.size.width - 16, y: geo.size.height * 0.5))
                    }
                    .stroke(
                        TrautoniumTheme.hairlineStrong,
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
                }

                // Active Touch Contact Indicators (Fingers)
                ForEach(state.activeTouches) { touch in
                    touchOrbView(touch: touch, bounds: geo.size)
                }

                // Subtle Manual Identifiers
                VStack {
                    HStack {
                        manualLabel(
                            title: "Manual 1",
                            span: state.patch.manuals[0].span
                        )
                        Spacer()
                    }
                    .padding(.top, 8)
                    .padding(.leading, 14)

                    Spacer()

                    if state.patch.isSplit {
                        HStack {
                            manualLabel(
                                title: "Manual 2",
                                span: state.patch.manuals[1].span
                            )
                            Spacer()
                        }
                        .padding(.bottom, 8)
                        .padding(.leading, 14)
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
        .frame(height: 240)
    }

    private func manualLabel(title: String, span: Int) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(TrautoniumTheme.textMuted)
                .frame(width: 4, height: 4)
            Text("\(title)  ·  \(span) octaves")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(TrautoniumTheme.textMuted)
        }
    }

    private func noteGridView(width: CGFloat, height: CGFloat) -> some View {
        Canvas { context, size in
            let edge = CGFloat(PitchRibbon.padEdgeMargin)
            let usableW = size.width * (1.0 - 2.0 * edge)
            let startX = size.width * edge

            // Manual 1 markers
            let m0 = state.patch.manuals[0]
            let totalSemis0 = m0.span * 12
            let yBottom0 = state.patch.isSplit ? size.height * 0.5 : size.height

            for s in 0...totalSemis0 {
                let u = CGFloat(s) / CGFloat(totalSemis0)
                let x = startX + u * usableW
                let midi = m0.lowNote + s
                let isInScale = Scales.contains(note: midi, scaleIndex: state.patch.scaleIndex, tonic: state.patch.tonic)
                let isTonic = (midi % 12) == (state.patch.tonic % 12)

                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: yBottom0))

                let strokeColor = isTonic
                    ? TrautoniumTheme.accent.opacity(0.35)
                    : (isInScale ? Color.white.opacity(0.10) : Color.white.opacity(0.03))
                let lineWidth: CGFloat = isTonic ? 1.0 : 0.5
                context.stroke(path, with: .color(strokeColor), lineWidth: lineWidth)

                // Labels at top
                if isTonic || (isInScale && s % 2 == 0) {
                    let noteStr = Scales.noteName(for: Float(midi))
                    let text = Text(noteStr)
                        .font(.system(size: 9, weight: isTonic ? .medium : .regular, design: .monospaced))
                        .foregroundColor(isTonic ? TrautoniumTheme.accent : TrautoniumTheme.textMuted)
                    context.draw(text, at: CGPoint(x: x, y: 12))
                }
            }

            // Manual 2 markers
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

                    let strokeColor = isTonic
                        ? TrautoniumTheme.accent.opacity(0.35)
                        : (isInScale ? Color.white.opacity(0.10) : Color.white.opacity(0.03))
                    let lineWidth: CGFloat = isTonic ? 1.0 : 0.5
                    context.stroke(path, with: .color(strokeColor), lineWidth: lineWidth)

                    if isTonic || (isInScale && s % 2 == 0) {
                        let noteStr = Scales.noteName(for: Float(midi))
                        let text = Text(noteStr)
                            .font(.system(size: 9, weight: isTonic ? .medium : .regular, design: .monospaced))
                            .foregroundColor(isTonic ? TrautoniumTheme.accent : TrautoniumTheme.textMuted)
                        context.draw(text, at: CGPoint(x: x, y: size.height - 12))
                    }
                }
            }
        }
    }

    private func touchOrbView(touch: SynthTouchSnapshot, bounds: CGSize) -> some View {
        let x = CGFloat(touch.x) * bounds.width
        let y = CGFloat(touch.y) * bounds.height
        let haloRadius = 18.0 + CGFloat(touch.normalizedPressure) * 24.0

        let noteName = Scales.noteName(for: touch.soundingMidi)
        let cents = Scales.centsOffset(fromExactMidi: touch.soundingMidi)
        let centsStr = cents >= 0 ? "+\(cents)¢" : "\(cents)¢"

        return ZStack {
            // Mechanical Contact Ring (Expands with force)
            Circle()
                .stroke(TrautoniumTheme.accent.opacity(0.35), lineWidth: 1)
                .frame(width: haloRadius * 2, height: haloRadius * 2)

            Circle()
                .fill(TrautoniumTheme.accent.opacity(0.06))
                .frame(width: haloRadius * 2, height: haloRadius * 2)

            // Contact Center Bead
            Circle()
                .fill(TrautoniumTheme.textPrimary)
                .frame(width: 8, height: 8)

            // Readout Badge
            HStack(spacing: 5) {
                Text(noteName)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(TrautoniumTheme.textPrimary)
                Text(centsStr)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(abs(cents) <= 5 ? TrautoniumTheme.accent : TrautoniumTheme.textMuted)
                if touch.pressureGrams > 0 {
                    Text("·")
                        .foregroundColor(TrautoniumTheme.textMuted)
                    Text("\(Int(touch.pressureGrams))g")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(TrautoniumTheme.textSecondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(TrautoniumTheme.bgRaised)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(TrautoniumTheme.hairlineStrong, lineWidth: 1)
            )
            .offset(y: -32)
        }
        .position(x: x, y: y)
    }
}
