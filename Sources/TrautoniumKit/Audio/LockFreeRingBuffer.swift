import Foundation

public final class ScopeRingBuffer: @unchecked Sendable {
    public let capacity: Int
    private var buffer: [Float]
    private var writeHead: Int = 0
    private let lock = NSLock()

    public init(capacity: Int = 2048) {
        self.capacity = capacity
        self.buffer = [Float](repeating: 0, count: capacity)
    }

    public func write(samples: UnsafePointer<Float>, count: Int) {
        lock.lock()
        for i in 0..<count {
            buffer[writeHead] = samples[i]
            writeHead = (writeHead + 1) % capacity
        }
        lock.unlock()
    }

    public func snapshot(into destination: inout [Float]) {
        lock.lock()
        let count = min(destination.count, capacity)
        var readIdx = (writeHead - count + capacity) % capacity
        for i in 0..<count {
            destination[i] = buffer[readIdx]
            readIdx = (readIdx + 1) % capacity
        }
        lock.unlock()
    }
}
