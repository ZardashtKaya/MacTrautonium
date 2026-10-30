import Foundation

public struct FormantSpec: Sendable {
    public let freq: Float
    public let bandwidth: Float
    public let gainDb: Float

    public init(_ freq: Float, _ bandwidth: Float, _ gainDb: Float) {
        self.freq = freq
        self.bandwidth = bandwidth
        self.gainDb = gainDb
    }
}

public final class FormantBank: @unchecked Sendable {
    public static let vowelNames = ["A", "E", "I", "O", "U"]
    public static let registerNames = ["Bass", "Tenor", "Soprano"]

    public static let vowelPresets: [[[FormantSpec]]] = [
        // Bass
        [
            [FormantSpec(600, 60, 0), FormantSpec(1040, 70, -7), FormantSpec(2250, 110, -9), FormantSpec(2450, 120, -9)],
            [FormantSpec(400, 40, 0), FormantSpec(1620, 80, -12), FormantSpec(2400, 100, -9), FormantSpec(2800, 120, -12)],
            [FormantSpec(250, 60, 0), FormantSpec(1750, 90, -30), FormantSpec(2600, 100, -16), FormantSpec(3050, 120, -22)],
            [FormantSpec(400, 40, 0), FormantSpec(750, 80, -11), FormantSpec(2400, 100, -21), FormantSpec(2600, 120, -20)],
            [FormantSpec(350, 40, 0), FormantSpec(600, 80, -20), FormantSpec(2400, 100, -32), FormantSpec(2675, 120, -28)]
        ],
        // Tenor
        [
            [FormantSpec(650, 80, 0), FormantSpec(1080, 90, -6), FormantSpec(2650, 120, -7), FormantSpec(2900, 130, -8)],
            [FormantSpec(400, 70, 0), FormantSpec(1700, 80, -14), FormantSpec(2600, 100, -12), FormantSpec(3200, 120, -14)],
            [FormantSpec(290, 40, 0), FormantSpec(1870, 90, -15), FormantSpec(2800, 100, -18), FormantSpec(3250, 120, -20)],
            [FormantSpec(400, 40, 0), FormantSpec(800, 80, -10), FormantSpec(2600, 100, -12), FormantSpec(2800, 120, -12)],
            [FormantSpec(350, 40, 0), FormantSpec(600, 80, -20), FormantSpec(2700, 100, -17), FormantSpec(2900, 120, -14)]
        ],
        // Soprano
        [
            [FormantSpec(800, 80, 0), FormantSpec(1150, 90, -6), FormantSpec(2900, 120, -32), FormantSpec(3900, 130, -20)],
            [FormantSpec(350, 60, 0), FormantSpec(2000, 100, -20), FormantSpec(2800, 120, -15), FormantSpec(3600, 150, -40)],
            [FormantSpec(270, 60, 0), FormantSpec(2140, 90, -12), FormantSpec(2950, 100, -26), FormantSpec(3900, 120, -26)],
            [FormantSpec(450, 70, 0), FormantSpec(800, 80, -11), FormantSpec(2830, 100, -22), FormantSpec(3800, 130, -50)],
            [FormantSpec(325, 50, 0), FormantSpec(700, 60, -16), FormantSpec(2700, 170, -35), FormantSpec(3800, 180, -40)]
        ]
    ]

    private var filters: [StateVariableFilter] = (0..<4).map { _ in StateVariableFilter() }
    private var coefficients: [StateVariableFilter.Coefficients] = (0..<4).map { _ in
        StateVariableFilter.Coefficients(cutoffHz: 1000, resonance: 0.5, sampleRate: 48000)
    }
    private var gains: [Float] = [1, 1, 1, 1]

    private var currentVowel: Int = -2
    private var currentRegister: Int = -2
    private let sampleRate: Float

    public init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
    }

    public func update(vowel: Int, register: Int) {
        if vowel == currentVowel && register == currentRegister { return }
        currentVowel = vowel
        currentRegister = register

        guard vowel >= 0 && vowel < Self.vowelNames.count else { return }
        let reg = max(0, min(register, Self.registerNames.count - 1))
        let specs = Self.vowelPresets[reg][vowel]

        for i in 0..<4 {
            let spec = specs[i]
            // k = 1 / Q = bandwidth / centerFreq
            let dampingK = max(0.02, min(2.0, spec.bandwidth / spec.freq))
            coefficients[i] = StateVariableFilter.Coefficients(cutoffHz: spec.freq, dampingK: dampingK, sampleRate: sampleRate)
            // +8 dB makeup gain for vocal resonance
            gains[i] = pow(10.0, (spec.gainDb + 8.0) / 20.0)
        }
    }

    @inline(__always)
    public func process(sample: Float, vowel: Int, register: Int) -> Float {
        if vowel < 0 {
            return sample // Bypass formants when vowel is Off (-1)
        }
        update(vowel: vowel, register: register)

        var output: Float = 0
        for i in 0..<4 {
            let (_, bp) = filters[i].process(input: sample, coefficients: coefficients[i])
            output += bp * gains[i]
        }
        return output
    }
}
