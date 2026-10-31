import SwiftUI

public struct OscilloscopeView: View {
    let waveform: [Float]

    public init(waveform: [Float]) {
        self.waveform = waveform
    }

    public var body: some View {
        Canvas { context, size in
            let midY = size.height * 0.5

            // Graticule Divisions
            for i in 1..<4 {
                let y = size.height * CGFloat(i) / 4.0
                var hLine = Path()
                hLine.move(to: CGPoint(x: 0, y: y))
                hLine.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(hLine, with: .color(TrautoniumTheme.crtGraticule), lineWidth: 0.5)
            }

            for i in 1..<8 {
                let x = size.width * CGFloat(i) / 8.0
                var vLine = Path()
                vLine.move(to: CGPoint(x: x, y: 0))
                vLine.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(vLine, with: .color(TrautoniumTheme.crtGraticule), lineWidth: 0.5)
            }

            // Center Reference Axis
            var centerLine = Path()
            centerLine.move(to: CGPoint(x: 0, y: midY))
            centerLine.addLine(to: CGPoint(x: size.width, y: midY))
            context.stroke(centerLine, with: .color(TrautoniumTheme.crtGraticule.opacity(1.5)), lineWidth: 0.75)

            // Waveform Trace
            guard waveform.count > 1 else { return }
            var wavePath = Path()
            let stepX = size.width / CGFloat(waveform.count - 1)

            let firstY = midY - CGFloat(waveform[0]) * midY * 0.82
            wavePath.move(to: CGPoint(x: 0, y: firstY))

            for i in 1..<waveform.count {
                let x = CGFloat(i) * stepX
                let y = midY - CGFloat(waveform[i]) * midY * 0.82
                wavePath.addLine(to: CGPoint(x: x, y: y))
            }

            // Single crisp phosphor beam trace
            context.stroke(
                wavePath,
                with: .color(TrautoniumTheme.crtTrace),
                lineWidth: 1.2
            )
        }
        .background(TrautoniumTheme.crtBg)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(TrautoniumTheme.hairline, lineWidth: 1)
        )
    }
}
