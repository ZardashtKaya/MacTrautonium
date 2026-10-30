import Foundation

public final class AudioRecorder: @unchecked Sendable {
    public private(set) var isRecording: Bool = false
    public private(set) var currentFileURL: URL?

    private var fileHandle: FileHandle?
    private var bytesWritten: UInt32 = 0
    private let sampleRate: UInt32 = 48000
    private let channels: UInt16 = 2
    private let bitsPerSample: UInt16 = 16
    private let lock = NSLock()

    public init() {}

    public func startRecording() -> URL? {
        lock.lock()
        defer { lock.unlock() }

        guard !isRecording else { return currentFileURL }

        let fileManager = FileManager.default
        let musicURL = fileManager.urls(for: .musicDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory

        let folder = musicURL.appendingPathComponent("Trautonium Recordings", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "Trautonium_\(formatter.string(from: Date())).wav"
        let fileURL = folder.appendingPathComponent(filename)

        fileManager.createFile(atPath: fileURL.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: fileURL) else { return nil }

        self.fileHandle = handle
        self.currentFileURL = fileURL
        self.bytesWritten = 0

        // Write placeholder 44-byte WAV header
        let emptyHeader = [UInt8](repeating: 0, count: 44)
        handle.write(Data(emptyHeader))

        self.isRecording = true
        return fileURL
    }

    public func append(left: UnsafePointer<Float>, right: UnsafePointer<Float>, count: Int) {
        guard isRecording else { return }
        lock.lock()
        defer { lock.unlock() }
        guard let handle = fileHandle else { return }

        var pcmData = Data(capacity: count * 4) // 2 channels * 2 bytes
        for i in 0..<count {
            let sL = max(-1.0, min(1.0, left[i]))
            let sR = max(-1.0, min(1.0, right[i]))

            var intL = Int16(sL * 32767.0).littleEndian
            var intR = Int16(sR * 32767.0).littleEndian

            withUnsafeBytes(of: &intL) { pcmData.append(contentsOf: $0) }
            withUnsafeBytes(of: &intR) { pcmData.append(contentsOf: $0) }
        }

        handle.write(pcmData)
        bytesWritten += UInt32(pcmData.count)
    }

    public func stopRecording() -> URL? {
        lock.lock()
        defer { lock.unlock() }

        guard isRecording, let handle = fileHandle, let fileURL = currentFileURL else {
            return nil
        }

        // Finalize WAV Header
        var header = Data()
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let totalChunkSize = bytesWritten + 36

        // RIFF chunk
        header.append(contentsOf: "RIFF".utf8)
        var chunkSizeLE = totalChunkSize.littleEndian
        withUnsafeBytes(of: &chunkSizeLE) { header.append(contentsOf: $0) }
        header.append(contentsOf: "WAVE".utf8)

        // fmt sub-chunk
        header.append(contentsOf: "fmt ".utf8)
        var subChunk1Size = UInt32(16).littleEndian
        withUnsafeBytes(of: &subChunk1Size) { header.append(contentsOf: $0) }
        var audioFormat = UInt16(1).littleEndian // PCM
        withUnsafeBytes(of: &audioFormat) { header.append(contentsOf: $0) }
        var numChannels = channels.littleEndian
        withUnsafeBytes(of: &numChannels) { header.append(contentsOf: $0) }
        var sRate = sampleRate.littleEndian
        withUnsafeBytes(of: &sRate) { header.append(contentsOf: $0) }
        var bRate = byteRate.littleEndian
        withUnsafeBytes(of: &bRate) { header.append(contentsOf: $0) }
        var bAlign = blockAlign.littleEndian
        withUnsafeBytes(of: &bAlign) { header.append(contentsOf: $0) }
        var bps = bitsPerSample.littleEndian
        withUnsafeBytes(of: &bps) { header.append(contentsOf: $0) }

        // data sub-chunk
        header.append(contentsOf: "data".utf8)
        var subChunk2Size = bytesWritten.littleEndian
        withUnsafeBytes(of: &subChunk2Size) { header.append(contentsOf: $0) }

        try? handle.seek(toOffset: 0)
        handle.write(header)
        try? handle.close()

        self.fileHandle = nil
        self.isRecording = false
        return fileURL
    }
}
