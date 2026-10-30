import Foundation

/// Topology-Preserving Transform (TPT) State Variable Filter
/// Produces clean, artifact-free lowpass, bandpass, and highpass responses
/// with unconditional numerical stability.
public struct StateVariableFilter: Sendable {
    public struct Coefficients: Sendable {
        public var a1: Float = 0
        public var a2: Float = 0
        public var a3: Float = 0
        public var k: Float = 0

        public init(cutoffHz: Float, resonance: Float, sampleRate: Float) {
            let clampedFc = max(10.0, min(cutoffHz, 0.48 * sampleRate))
            let g = tan(Float.pi * clampedFc / sampleRate)
            // Resonance 0..1 maps to damping factor k
            let damping = max(0.04, 2.0 * (1.0 - min(0.98, resonance)) * 0.7071)
            self.k = damping
            self.a1 = 1.0 / (1.0 + g * (g + damping))
            self.a2 = g * a1
            self.a3 = g * a2
        }

        public init(cutoffHz: Float, dampingK: Float, sampleRate: Float) {
            let clampedFc = max(10.0, min(cutoffHz, 0.48 * sampleRate))
            let g = tan(Float.pi * clampedFc / sampleRate)
            self.k = dampingK
            self.a1 = 1.0 / (1.0 + g * (g + dampingK))
            self.a2 = g * a1
            self.a3 = g * a2
        }
    }

    private var ic1: Float = 0
    private var ic2: Float = 0

    public init() {}

    public mutating func reset() {
        ic1 = 0
        ic2 = 0
    }

    @inline(__always)
    public mutating func process(input: Float, coefficients c: Coefficients) -> (lowpass: Float, bandpass: Float) {
        let v3 = input - ic2
        let v1 = c.a1 * ic1 + c.a2 * v3
        let v2 = ic2 + c.a2 * ic1 + c.a3 * v3
        ic1 = 2.0 * v1 - ic1
        ic2 = 2.0 * v2 - ic2
        return (lowpass: v2, bandpass: v1)
    }
}
