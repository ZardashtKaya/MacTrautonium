import Foundation

public final class SynthVoice: @unchecked Sendable {
    public static let neonTableSize = 512
    public static let neonTable: [Float] = {
        let k: Float = 2.6
        var table = [Float](repeating: 0, count: neonTableSize + 1)
        var mean: Double = 0
        let denom = 1.0 - exp(-k)
        for i in 0...neonTableSize {
            let t = Float(i) / Float(neonTableSize)
            let val = 2.0 * (1.0 - exp(-k * t)) / denom - 1.0
            table[i] = val
            if i < neonTableSize { mean += Double(val) }
        }
        mean /= Double(neonTableSize)
        for i in 0...neonTableSize {
            table[i] -= Float(mean)
        }
        return table
    }()

    public enum EnvStage {
        case attack
        case decay
        case release
    }

    // Voice lifecycle & tracking
    public var isActive: Bool = false
    public var isGateOn: Bool = false
    public var isClaimed: Bool = false
    public var ownerId: Int = -1        // Touch ID or monophonic manual owner
    public var manualIndex: Int = 0     // Manual 0 (Upper) or 1 (Lower)
    public var sourceTouchId: Int = -1  // Finger that currently guides the voice

    // Pitch & Phase
    public var currentLogHz: Float = 0
    public var targetLogHz: Float = 0
    public var phase: Float = 0
    public var subCounters: [Int] = [0, 0, 0, 0]

    // Pressure & Level
    public var currentLevel: Float = 0
    public var targetLevel: Float = 0
    public var normalizedPressure: Float = 0

    // Envelope
    public var envelope: Float = 0
    public var stage: EnvStage = .attack

    // Analog Drift & RNG
    private var rngState: UInt32 = 0x9E3779B9
    private var driftCurrent: Float = 0
    private var driftTarget: Float = 0
    private var driftTimer: Float = 0

    // Filter
    private var toneFilter = StateVariableFilter()
    public var smoothedCutoffHz: Float = 1800.0

    public init() {}

    public func reset() {
        isActive = false
        isGateOn = false
        isClaimed = false
        ownerId = -1
        manualIndex = 0
        sourceTouchId = -1
        currentLogHz = 0
        targetLogHz = 0
        phase = 0
        subCounters = [0, 0, 0, 0]
        currentLevel = 0
        targetLevel = 0
        normalizedPressure = 0
        smoothedCutoffHz = 1800.0
        envelope = 0
        stage = .attack
        driftCurrent = 0
        driftTarget = 0
        driftTimer = 0
        toneFilter.reset()
    }

    private func randomFloat() -> Float {
        rngState ^= rngState << 13
        rngState ^= rngState >> 17
        rngState ^= rngState << 5
        return Float(Int32(bitPattern: rngState)) * (1.0 / 2147483648.0)
    }

    @inline(__always)
    private static func polyBLEP(t: Float, dt: Float) -> Float {
        if t < dt {
            let n = t / dt
            return n + n - n * n - 1.0
        } else if t > 1.0 - dt {
            let n = (t - 1.0) / dt
            return n * n + n + n + 1.0
        }
        return 0.0
    }

    @inline(__always)
    private static func waveShape(type: WaveformType, t: Float) -> Float {
        if type == .sawtooth {
            return 2.0 * t - 1.0
        }
        // Neon relaxation oscillator table lookup
        let f = t * Float(neonTableSize)
        let i = min(neonTableSize - 1, max(0, Int(f)))
        let fr = f - Float(i)
        return neonTable[i] + (neonTable[i + 1] - neonTable[i]) * fr
    }

    public static func noteToLog2Hz(_ midiNote: Float) -> Float {
        return log2(440.0) + (midiNote - 69.0) / 12.0
    }

    public func trigger(owner: Int, manual: Int, midiNote: Float, pressure: Float, touchId: Int, minLevel: Float) {
        let tl = Self.noteToLog2Hz(midiNote)
        let lvl = minLevel + (1.0 - minLevel) * max(0.0, min(1.0, pressure))

        if !isActive {
            reset()
            isActive = true
            ownerId = owner
            currentLogHz = tl
            normalizedPressure = pressure
            currentLevel = lvl
            stage = .attack
            rngState = UInt32(truncatingIfNeeded: owner) &* 2654435761 &+ 0x9E3779B9
            sourceTouchId = touchId
        } else if !isGateOn {
            currentLogHz = tl
            stage = .attack
        }

        sourceTouchId = touchId
        manualIndex = manual
        isGateOn = true
        isClaimed = true
        targetLogHz = tl
        normalizedPressure += (pressure - normalizedPressure) * 0.35
        targetLevel = lvl
    }

    public func releaseGate() {
        isGateOn = false
        stage = .release
    }

    /// Render voice samples directly into the manual summation buffer
    public func render(params: ManualParams, buffer: UnsafeMutablePointer<Float>, frameCount: Int, sampleRate: Float) {
        guard isActive else { return }

        let dtBlock = Float(frameCount) / sampleRate

        // Subharmonic dividers and levels
        var subDiv = [Int](repeating: 1, count: 4)
        var subLv = [Float](repeating: 0, count: 4)
        var sumLevels = params.mainLevel

        for k in 0..<4 {
            let div = max(1, min(24, k < params.subDividers.count ? params.subDividers[k] : (k + 2)))
            let lvl = k < params.subLevels.count ? params.subLevels[k] : 0.0
            subDiv[k] = div
            subLv[k] = lvl
            sumLevels += lvl
            if subCounters[k] >= div { subCounters[k] %= div }
        }
        let normalization = 1.0 / (0.5 + 0.5 * max(0.01, sumLevels))

        // Analog oscillator frequency drift
        driftTimer -= dtBlock
        if driftTimer <= 0.0 {
            driftTarget = randomFloat()
            driftTimer = 0.15 + 0.35 * (0.5 + 0.5 * randomFloat())
        }
        driftCurrent += (driftTarget - driftCurrent) * (1.0 - exp(-dtBlock / 0.35))
        let driftOctaves = params.analogDrift * driftCurrent * (10.0 / 1200.0)

        // Portamento pitch smoothing
        let tauPortamento = max(0.006, params.glideMs * 0.001)
        let pitchCoeff = 1.0 - exp(-1.0 / (tauPortamento * sampleRate))

        // Pressure level smoothing
        let tauLevel = targetLevel > currentLevel ? 0.004 : 0.012
        let levelCoeff = 1.0 - exp(-1.0 / (Float(tauLevel) * sampleRate))

        // Envelope coefficients
        let attackInc = 1.0 / (max(1.0, params.attackMs) * 0.001 * sampleRate)
        let decayCoeff = 1.0 - exp(-1.0 / (max(5.0, params.decayMs) * 0.001 * sampleRate))
        let releaseCoeff = 1.0 - exp(-1.0 / (max(5.0, params.releaseMs) * 0.001 * sampleRate))
        let sustainLevel = max(0.0, min(1.0, params.sustain))

        // Dynamic Cutoff modulation by pressure with per-sample smoothing
        let targetCutoffHz = max(80.0, min(18000.0, params.cutoff * exp2(params.pressureBrightness * normalizedPressure * 3.0)))
        let tauCutoff: Float = 0.012 // 12ms filter cutoff smoothing
        let cutoffCoeff = 1.0 - exp(-1.0 / (tauCutoff * sampleRate))

        var filterCoeffs = StateVariableFilter.Coefficients(
            cutoffHz: smoothedCutoffHz,
            resonance: params.resonance,
            sampleRate: sampleRate
        )

        let noiseLevel = params.noiseLevel * 0.7
        let waveType = params.waveform

        for i in 0..<frameCount {
            // Smooth cutoff and update SVF coefficients in sub-blocks to prevent filter stepping clicks
            smoothedCutoffHz += (targetCutoffHz - smoothedCutoffHz) * cutoffCoeff
            if (i & 15) == 0 {
                filterCoeffs = StateVariableFilter.Coefficients(
                    cutoffHz: smoothedCutoffHz,
                    resonance: params.resonance,
                    sampleRate: sampleRate
                )
            }

            currentLogHz += (targetLogHz - currentLogHz) * pitchCoeff
            var dt = exp2(currentLogHz + driftOctaves) / sampleRate
            if dt > 0.45 { dt = 0.45 }

            phase += dt
            if phase >= 1.0 {
                phase -= 1.0
                for s in 0..<4 {
                    subCounters[s] += 1
                    if subCounters[s] >= subDiv[s] {
                        subCounters[s] = 0
                    }
                }
            }

            let t = phase
            var s = params.mainLevel * (Self.waveShape(type: waveType, t: t) - Self.polyBLEP(t: t, dt: dt))

            // Subharmonic f/N division synthesis with PolyBLEP
            for subIdx in 0..<4 {
                let lvl = subLv[subIdx]
                if lvl <= 0.0 { continue }
                let n = Float(subDiv[subIdx])
                let subPhase = (Float(subCounters[subIdx]) + t) / n
                s += lvl * (Self.waveShape(type: waveType, t: subPhase) - Self.polyBLEP(t: subPhase, dt: dt / n))
            }
            s *= normalization

            if noiseLevel > 0.0 {
                s += noiseLevel * randomFloat()
            }

            // Lowpass tone filtering
            let (lp, _) = toneFilter.process(input: s, coefficients: filterCoeffs)

            // Envelope progression
            if isGateOn {
                if stage == .attack {
                    envelope += attackInc
                    if envelope >= 1.0 {
                        envelope = 1.0
                        stage = .decay
                    }
                } else {
                    envelope += (sustainLevel - envelope) * decayCoeff
                }
            } else {
                envelope -= envelope * releaseCoeff
            }

            currentLevel += (targetLevel - currentLevel) * levelCoeff

            // Add voice output to manual bus
            buffer[i] += lp * currentLevel * envelope
        }

        // Deactivate dead voice
        if !isGateOn && envelope < 1e-4 {
            isActive = false
        }
    }
}
