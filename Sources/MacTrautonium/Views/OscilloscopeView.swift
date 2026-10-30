import SwiftUI

public struct OscilloscopeView: View {
    let waveform: [Float]

    public init(waveform: [Float]) {
        self.waveform = waveform
    }

    public var body: some View {
        Canvas { context, size in
            // Background Grid Lines
            let midY = size.height * 0.5
            let gridColor = Color.green.opacity(0.12)

            for i in 1..<4 {
                let y = size.height * CGFloat(i) / 4.0
                var hLine = Path()
                hLine.move(to: CGPoint(x: 0, y: y))
                hLine.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(hLine, with: .color(gridColor), lineWidth: 0.8)
            }

            for i in 1..<8 {
                let x = size.width * CGFloat(i) / 8.0
                var vLine = Path()
                vLine.move(to: CGPoint(x: x, y: 0))
                vLine.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(vLine, with: .color(gridColor), lineWidth: 0.8)
            }

            // Waveform Path
            guard waveform.count > 1 else { return }
            var wavePath = Path()
            let stepX = size.width / CGFloat(waveform.count - 1)

            let firstY = midY - CGFloat(waveform[0]) * midY * 0.85
            wavePath.move(to: CGPoint(x: 0, y: firstY))

            for i in 1..<waveform.count {
                let x = CGFloat(i) * stepX
                let y = midY - CGFloat(waveform[i]) * midY * 0.85
                wavePath.addLine(to: CGPoint(x: x, y: y))
            }

            // Glow Stroke
            context.stroke(
                wavePath,
                with: .color(Color(red: 0.3, green: 1.0, blue: 0.5).opacity(0.4)),
                lineWidth: 4
            )
            // Crisp Core Stroke
            context.stroke(
                wavePath,
                with: .color(Color(red: 0.5, green: 1.0, blue: 0.6)),
                lineWidth: 1.5
            )
        }
        .background(Color(red: 0.04, green: 0.08, blue: 0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.15, green: 0.35, blue: 0.2), lineWidth: 1.5)
        )
    }
}
