import Foundation
import CoreFoundation
import AppKit

public struct TouchPoint: Identifiable, Sendable {
    public let id: Int
    public let x: Float                 // 0.0 to 1.0 (left to right pitch ribbon)
    public let y: Float                 // 0.0 to 1.0 (top to bottom; <0.5 Manual I, >=0.5 Manual II)
    public let pressureGrams: Float      // Raw Force Touch pressure in grams
    public let normalizedPressure: Float // Normalized 0.0 to 1.0 expression
    public let area: Float               // Capacitance contact area
    public let isFromTrackpad: Bool

    public init(
        id: Int,
        x: Float,
        y: Float,
        pressureGrams: Float,
        normalizedPressure: Float,
        area: Float,
        isFromTrackpad: Bool = true
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.pressureGrams = pressureGrams
        self.normalizedPressure = normalizedPressure
        self.area = area
        self.isFromTrackpad = isFromTrackpad
    }
}

public final class TouchInputManager: @unchecked Sendable {
    public static let shared = TouchInputManager()

    private var runLoop: CFRunLoop?
    private var isListening: Bool = false
    private let lock = NSLock()

    private var rawTouches: [TouchPoint] = []
    private var fallbackTouches: [Int: TouchPoint] = [:]
    private var lastFrameTime: Double = 0
    private var autoMaxArea: Float = 0.3

    private init() {
        setupWakeObserver()
    }

    private func setupWakeObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restartListener()
        }
    }

    public func start() {
        guard !isListening else { return }
        isListening = true

        let thread = Thread { [weak self] in
            guard let self = self else { return }
            self.runLoop = CFRunLoopGetCurrent()

            let bridge = MultitouchBridge.shared
            let started = bridge.start(callback: touchCallback, context: Unmanaged.passUnretained(self).toOpaque())

            if started {
                print("[TouchInputManager] Multitouch background listener started.")
            } else {
                print("[TouchInputManager] Multitouch hardware not started, using fallback input.")
            }

            // Keep CFRunLoop alive
            let timer = CFRunLoopTimerCreate(nil, CFAbsoluteTimeGetCurrent() + 1e9, 1e9, 0, 0, { _, _ in }, nil)
            CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, .defaultMode)
            CFRunLoopRun()
        }
        thread.name = "org.trautonium.multitouch"
        thread.qualityOfService = QualityOfService.userInteractive
        thread.start()
    }

    public func stop() {
        MultitouchBridge.shared.stop()
        if let rl = runLoop {
            CFRunLoopStop(rl)
            runLoop = nil
        }
        isListening = false
    }

    public func restartListener() {
        stop()
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.start()
        }
    }

    fileprivate func handleRawFrame(touches: UnsafePointer<MTTouchRaw>, count: Int) {
        lock.lock()
        defer { lock.unlock() }

        var list: [TouchPoint] = []
        for i in 0..<count {
            let t = touches[i]
            // state 3 = touch began, 4 = touching/moving
            if t.state != 3 && t.state != 4 { continue }

            if t.total > autoMaxArea { autoMaxArea = t.total }

            let x = max(0.0, min(1.0, t.normalized.pos.x))
            let y = max(0.0, min(1.0, 1.0 - t.normalized.pos.y)) // Invert Y so top is 0.0

            list.append(TouchPoint(
                id: Int(t.identifier),
                x: x,
                y: y,
                pressureGrams: t.pressure,
                normalizedPressure: 0, // Computed later with active prefs
                area: t.total,
                isFromTrackpad: true
            ))
        }

        self.rawTouches = list
        self.lastFrameTime = CFAbsoluteTimeGetCurrent()
    }

    public func getActiveTouches(prefs: TrautoniumPrefs) -> [TouchPoint] {
        lock.lock()
        defer { lock.unlock() }

        var result: [TouchPoint] = []
        let now = CFAbsoluteTimeGetCurrent()

        // Include hardware trackpad touches if received within last 1.0s
        if (now - lastFrameTime) < 1.0 {
            for t in rawTouches {
                let normP = normalizePressure(
                    pressureGrams: t.pressureGrams,
                    area: t.area,
                    prefs: prefs
                )
                result.append(TouchPoint(
                    id: t.id,
                    x: t.x,
                    y: t.y,
                    pressureGrams: t.pressureGrams,
                    normalizedPressure: normP,
                    area: t.area,
                    isFromTrackpad: true
                ))
            }
        }

        // Include fallback touches (mouse/keyboard)
        for (_, fb) in fallbackTouches {
            result.append(fb)
        }

        return result
    }

    private func normalizePressure(pressureGrams: Float, area: Float, prefs: TrautoniumPrefs) -> Float {
        var u: Float = 0
        switch prefs.pressSource {
        case .force:
            let lo = prefs.forceFloorGrams
            let hi = max(lo + 5.0, prefs.forceMaxGrams)
            u = (pressureGrams - lo) / (hi - lo)
        case .area:
            let lo = prefs.areaFloor
            let hi = prefs.areaMax > 0 ? prefs.areaMax : autoMaxArea
            let denom = max(0.01, hi - lo)
            u = (area - lo) / denom
        case .fixed:
            return 0.75
        }

        u = max(0.0, min(1.0, u))
        switch prefs.pressCurve {
        case .soft:
            return pow(u, 0.55)
        case .hard:
            return pow(u, 1.4)
        case .linear:
            return pow(u, 0.8)
        }
    }

    // MARK: - Mouse / Keyboard Fallbacks

    public func setFallbackTouch(id: Int, x: Float, y: Float, pressure: Float) {
        lock.lock()
        defer { lock.unlock() }
        fallbackTouches[id] = TouchPoint(
            id: id,
            x: max(0.0, min(1.0, x)),
            y: max(0.0, min(1.0, y)),
            pressureGrams: pressure * 300.0,
            normalizedPressure: max(0.0, min(1.0, pressure)),
            area: 0.5,
            isFromTrackpad: false
        )
    }

    public func removeFallbackTouch(id: Int) {
        lock.lock()
        defer { lock.unlock() }
        fallbackTouches.removeValue(forKey: id)
    }

    public func clearFallbackTouches() {
        lock.lock()
        defer { lock.unlock() }
        fallbackTouches.removeAll()
    }
}

// C-convention callback for MultitouchSupport frame events
private func touchCallback(
    device: MTDeviceRef?,
    touchesPtr: UnsafeMutableRawPointer?,
    count: Int32,
    timestamp: Double,
    frame: Int32,
    refcon: UnsafeMutableRawPointer?
) {
    guard let refcon = refcon, let touchesPtr = touchesPtr else { return }
    let manager = Unmanaged<TouchInputManager>.fromOpaque(refcon).takeUnretainedValue()
    let touches = touchesPtr.assumingMemoryBound(to: MTTouchRaw.self)
    manager.handleRawFrame(touches: touches, count: Int(count))
}
