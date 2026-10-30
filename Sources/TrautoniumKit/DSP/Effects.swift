import Foundation

public final class StereoDelay: @unchecked Sendable {
    private let maxDelayFrames = 65536 // ~1.36 seconds at 48kHz
    private var bufferL: [Float]
    private var bufferR: [Float]
    private var writePos: Int = 0
    private var filterL: Float = 0
    private var filterR: Float = 0
    private var currentDelaySamples: Float = 0
    private let sampleRate: Float

    public init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
        self.bufferL = [Float](repeating: 0, count: maxDelayFrames)
        self.bufferR = [Float](repeating: 0, count: maxDelayFrames)
        self.currentDelaySamples = 350.0 * sampleRate / 1000.0
    }

    public func reset() {
        bufferL.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }
        bufferR.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }
        writePos = 0
        filterL = 0
        filterR = 0
    }

    @inline(__always)
    private func readBuffer(_ buf: [Float], delay: Float) -> Float {
        var rp = Float(writePos) - delay
        let maxF = Float(maxDelayFrames)
        while rp < 0 { rp += maxF }
        let i0 = Int(rp)
        let fr = rp - Float(i0)
        let mask = maxDelayFrames - 1
        let a = buf[i0 & mask]
        let b = buf[(i0 + 1) & mask]
        return a + (b - a) * fr
    }

    public func process(
        inL: Float,
        inR: Float,
        mix: Float,
        timeMs: Float,
        feedback: Float
    ) -> (outL: Float, outR: Float) {
        if mix <= 0.001 { return (inL, inR) }

        let targetSamples = max(50.0, min(1200.0, timeMs)) * sampleRate / 1000.0
        currentDelaySamples += (targetSamples - currentDelaySamples) * 0.002

        // Ping-pong stereo offset
        let readL = readBuffer(bufferL, delay: currentDelaySamples)
        let readR = readBuffer(bufferR, delay: currentDelaySamples * 1.05)

        // Lowpass damping in feedback loop (warm tape character)
        filterL += (readL - filterL) * 0.35
        filterR += (readR - filterR) * 0.35

        let fbClamped = max(0.0, min(0.88, feedback))
        bufferL[writePos] = inL + filterR * fbClamped // Ping-pong cross feedback
        bufferR[writePos] = inR + filterL * fbClamped

        writePos = (writePos + 1) & (maxDelayFrames - 1)

        let outL = inL + readL * mix
        let outR = inR + readR * mix
        return (outL, outR)
    }
}

public final class StereoReverb: @unchecked Sendable {
    private struct Comb {
        var buffer: [Float]
        var pos: Int = 0
        var store: Float = 0
        var length: Int
    }

    private struct Allpass {
        var buffer: [Float]
        var pos: Int = 0
        var length: Int
    }

    private var combL: [Comb]
    private var combR: [Comb]
    private var allpassL: [Allpass]
    private var allpassR: [Allpass]

    public init(sampleRate: Float = 48000.0) {
        let combLengths = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
        let allpassLengths = [556, 441, 341, 225]
        let scale = sampleRate / 44100.0

        combL = combLengths.map { len in
            let l = Int(Float(len) * scale)
            return Comb(buffer: [Float](repeating: 0, count: l), pos: 0, store: 0, length: l)
        }
        combR = combLengths.map { len in
            let l = Int(Float(len + 23) * scale)
            return Comb(buffer: [Float](repeating: 0, count: l), pos: 0, store: 0, length: l)
        }
        allpassL = allpassLengths.map { len in
            let l = Int(Float(len) * scale)
            return Allpass(buffer: [Float](repeating: 0, count: l), pos: 0, length: l)
        }
        allpassR = allpassLengths.map { len in
            let l = Int(Float(len + 23) * scale)
            return Allpass(buffer: [Float](repeating: 0, count: l), pos: 0, length: l)
        }
    }

    public func reset() {
        for i in 0..<combL.count {
            combL[i].buffer.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }
            combL[i].pos = 0
            combL[i].store = 0
            combR[i].buffer.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }
            combR[i].pos = 0
            combR[i].store = 0
        }
        for i in 0..<allpassL.count {
            allpassL[i].buffer.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }
            allpassL[i].pos = 0
            allpassR[i].buffer.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }
            allpassR[i].pos = 0
        }
    }

    public func process(inL: Float, inR: Float, mix: Float) -> (outL: Float, outR: Float) {
        if mix <= 0.001 { return (inL, inR) }

        let monoIn = (inL + inR) * 0.015
        let feedback: Float = 0.84
        let damping: Float = 0.3

        var outL: Float = 0
        for i in 0..<combL.count {
            let bufVal = combL[i].buffer[combL[i].pos]
            combL[i].store = bufVal * (1.0 - damping) + combL[i].store * damping
            combL[i].buffer[combL[i].pos] = monoIn + combL[i].store * feedback
            combL[i].pos += 1
            if combL[i].pos >= combL[i].length { combL[i].pos = 0 }
            outL += bufVal
        }

        var outR: Float = 0
        for i in 0..<combR.count {
            let bufVal = combR[i].buffer[combR[i].pos]
            combR[i].store = bufVal * (1.0 - damping) + combR[i].store * damping
            combR[i].buffer[combR[i].pos] = monoIn + combR[i].store * feedback
            combR[i].pos += 1
            if combR[i].pos >= combR[i].length { combR[i].pos = 0 }
            outR += bufVal
        }

        for i in 0..<allpassL.count {
            let b = allpassL[i].buffer[allpassL[i].pos]
            let y = -outL + b
            allpassL[i].buffer[allpassL[i].pos] = outL + b * 0.5
            allpassL[i].pos += 1
            if allpassL[i].pos >= allpassL[i].length { allpassL[i].pos = 0 }
            outL = y
        }

        for i in 0..<allpassR.count {
            let b = allpassR[i].buffer[allpassR[i].pos]
            let y = -outR + b
            allpassR[i].buffer[allpassR[i].pos] = outR + b * 0.5
            allpassR[i].pos += 1
            if allpassR[i].pos >= allpassR[i].length { allpassR[i].pos = 0 }
            outR = y
        }

        return (inL + outL * mix, inR + outR * mix)
    }
}

public enum Saturation {
    @inline(__always)
    public static func process(sample: Float, drive: Float) -> Float {
        if drive <= 0.001 { return sample }
        let x = sample * (1.0 + drive * 2.0)
        // Soft-knee tanh approximation
        if x > 3.0 { return 1.0 }
        if x < -3.0 { return -1.0 }
        let x2 = x * x
        return x * (27.0 + x2) / (27.0 + 9.0 * x2)
    }
}
