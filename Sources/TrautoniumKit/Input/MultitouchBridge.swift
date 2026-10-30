import Foundation
import CoreFoundation
import AppKit

public typealias MTDeviceRef = UnsafeMutableRawPointer

public struct MTPointRaw {
    public var x: Float = 0
    public var y: Float = 0
    public init(x: Float = 0, y: Float = 0) {
        self.x = x
        self.y = y
    }
}

public struct MTVectorRaw {
    public var pos: MTPointRaw = MTPointRaw()
    public var vel: MTPointRaw = MTPointRaw()
    public init() {}
}

public struct MTTouchRaw {
    public var frame: Int32 = 0
    public var timestamp: Double = 0
    public var identifier: Int32 = 0
    public var state: Int32 = 0          // 3: touch began, 4: active contact on surface
    public var fingerId: Int32 = 0
    public var handId: Int32 = 0
    public var normalized: MTVectorRaw = MTVectorRaw() // 0..1, y from bottom
    public var total: Float = 0          // Capacitance contact area
    public var pressure: Float = 0       // Force Touch pressure in grams
    public var angle: Float = 0
    public var majorAxis: Float = 0
    public var minorAxis: Float = 0
    public var absolute: MTVectorRaw = MTVectorRaw()
    public var field14: Int32 = 0
    public var field15: Int32 = 0
    public var density: Float = 0

    public init() {}
}

public typealias MTFrameCallbackWithRefcon = @convention(c) (
    MTDeviceRef?,
    UnsafeMutableRawPointer?,
    Int32,
    Double,
    Int32,
    UnsafeMutableRawPointer?
) -> Void

public final class MultitouchBridge: @unchecked Sendable {
    public static let shared = MultitouchBridge()

    private var dylibHandle: UnsafeMutableRawPointer?

    private var pCreateList: (@convention(c) () -> CFArray?)?
    private var pCreateDefault: (@convention(c) () -> MTDeviceRef?)?
    private var pRelease: (@convention(c) (MTDeviceRef) -> Void)?
    private var pIsBuiltIn: (@convention(c) (MTDeviceRef) -> Bool)?
    private var pSupportsForce: (@convention(c) (MTDeviceRef) -> Bool)?
    private var pRegisterWithRefcon: (@convention(c) (MTDeviceRef, MTFrameCallbackWithRefcon, UnsafeMutableRawPointer?) -> Void)?
    private var pUnregister: (@convention(c) (MTDeviceRef, MTFrameCallbackWithRefcon) -> Void)?
    private var pStart: (@convention(c) (MTDeviceRef, Int32) -> Int32)?
    private var pStop: (@convention(c) (MTDeviceRef) -> Int32)?
    private var pGetDeviceID: (@convention(c) (MTDeviceRef, UnsafeMutablePointer<UInt64>) -> Int32)?
    private var pActCreate: (@convention(c) (UInt64) -> CFTypeRef?)?
    private var pActOpen: (@convention(c) (CFTypeRef) -> Int32)?
    private var pActClose: (@convention(c) (CFTypeRef) -> Int32)?
    private var pActActuate: (@convention(c) (CFTypeRef, Int32, UInt32, Float, Float) -> Int32)?

    private var device: MTDeviceRef?
    private var actuator: CFTypeRef?
    public private(set) var isAvailable: Bool = false
    public private(set) var supportsForce: Bool = false

    private let hapticQueue = DispatchQueue(label: "org.trautonium.haptics", qos: .userInteractive)
    private var lastHapticTimestamp: Double = 0
    private let hapticLock = NSLock()

    private init() {
        loadFramework()
    }

    private func loadFramework() {
        let bundlePath = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(bundlePath, RTLD_NOW) else {
            print("[MultitouchBridge] MultitouchSupport.framework not found, using fallback input")
            return
        }
        dylibHandle = handle

        pCreateList = unsafeBitCast(dlsym(handle, "MTDeviceCreateList"), to: (@convention(c) () -> CFArray?).self)
        pCreateDefault = unsafeBitCast(dlsym(handle, "MTDeviceCreateDefault"), to: (@convention(c) () -> MTDeviceRef?).self)
        pRelease = unsafeBitCast(dlsym(handle, "MTDeviceRelease"), to: (@convention(c) (MTDeviceRef) -> Void).self)
        pIsBuiltIn = unsafeBitCast(dlsym(handle, "MTDeviceIsBuiltIn"), to: (@convention(c) (MTDeviceRef) -> Bool).self)
        pSupportsForce = unsafeBitCast(dlsym(handle, "MTDeviceSupportsForce"), to: (@convention(c) (MTDeviceRef) -> Bool).self)
        pRegisterWithRefcon = unsafeBitCast(dlsym(handle, "MTRegisterContactFrameCallbackWithRefcon"), to: (@convention(c) (MTDeviceRef, MTFrameCallbackWithRefcon, UnsafeMutableRawPointer?) -> Void).self)
        pUnregister = unsafeBitCast(dlsym(handle, "MTUnregisterContactFrameCallback"), to: (@convention(c) (MTDeviceRef, MTFrameCallbackWithRefcon) -> Void).self)
        pStart = unsafeBitCast(dlsym(handle, "MTDeviceStart"), to: (@convention(c) (MTDeviceRef, Int32) -> Int32).self)
        pStop = unsafeBitCast(dlsym(handle, "MTDeviceStop"), to: (@convention(c) (MTDeviceRef) -> Int32).self)
        pGetDeviceID = unsafeBitCast(dlsym(handle, "MTDeviceGetDeviceID"), to: (@convention(c) (MTDeviceRef, UnsafeMutablePointer<UInt64>) -> Int32).self)
        pActCreate = unsafeBitCast(dlsym(handle, "MTActuatorCreateFromDeviceID"), to: (@convention(c) (UInt64) -> CFTypeRef?).self)
        pActOpen = unsafeBitCast(dlsym(handle, "MTActuatorOpen"), to: (@convention(c) (CFTypeRef) -> Int32).self)
        pActClose = unsafeBitCast(dlsym(handle, "MTActuatorClose"), to: (@convention(c) (CFTypeRef) -> Int32).self)
        pActActuate = unsafeBitCast(dlsym(handle, "MTActuatorActuate"), to: (@convention(c) (CFTypeRef, Int32, UInt32, Float, Float) -> Int32).self)

        isAvailable = (pStart != nil && pRegisterWithRefcon != nil && (pCreateDefault != nil || pCreateList != nil))
        print("[MultitouchBridge] MultitouchSupport available: \(isAvailable)")
    }

    private func pickDevice() -> MTDeviceRef? {
        if let createList = pCreateList, let list = createList() {
            let count = CFArrayGetCount(list)
            for i in 0..<count {
                if let ptr = CFArrayGetValueAtIndex(list, i) {
                    let dev = MTDeviceRef(mutating: ptr)
                    if let isBuiltIn = pIsBuiltIn, isBuiltIn(dev) {
                        return dev
                    }
                }
            }
            if count > 0, let first = CFArrayGetValueAtIndex(list, 0) {
                return MTDeviceRef(mutating: first)
            }
        }
        return pCreateDefault?()
    }

    public func start(callback: MTFrameCallbackWithRefcon, context: UnsafeMutableRawPointer?) -> Bool {
        guard isAvailable else { return false }
        guard let dev = pickDevice() else {
            print("[MultitouchBridge] No multitouch device found")
            return false
        }
        self.device = dev

        if let supportsForceFn = pSupportsForce {
            self.supportsForce = supportsForceFn(dev)
        }

        pRegisterWithRefcon?(dev, callback, context)
        let status = pStart?(dev, 0) ?? -1
        if status == 0 {
            openActuator(for: dev)
            return true
        }
        return false
    }

    public func stop() {
        guard let dev = device else { return }
        _ = pStop?(dev)
        closeActuator()
        device = nil
    }

    private func openActuator(for dev: MTDeviceRef) {
        guard let getID = pGetDeviceID, let createAct = pActCreate, let openAct = pActOpen else { return }
        var devID: UInt64 = 0
        if getID(dev, &devID) == 0 && devID != 0 {
            if let act = createAct(devID) {
                if openAct(act) == 0 {
                    self.actuator = act
                }
            }
        }
    }

    private func closeActuator() {
        if let act = actuator, let closeAct = pActClose {
            _ = closeAct(act)
            actuator = nil
        }
    }

    public func triggerHaptic(strength: Int32 = 2) {
        let now = ProcessInfo.processInfo.systemUptime
        hapticLock.lock()
        if now - lastHapticTimestamp < 0.025 { // 25ms cooldown throttle (~40Hz max rate)
            hapticLock.unlock()
            return
        }
        lastHapticTimestamp = now
        hapticLock.unlock()

        hapticQueue.async { [weak self] in
            guard let self = self else { return }
            if let act = self.actuator, let actuate = self.pActActuate {
                let s = max(1, min(6, strength))
                _ = actuate(act, s, 0, 1.0, 2.0)
                return
            }
            // Fallback to public AppKit haptic manager on main thread
            DispatchQueue.main.async {
                NSHapticFeedbackManager.defaultPerformer.perform(
                    strength >= 3 ? .levelChange : .alignment,
                    performanceTime: .now
                )
            }
        }
    }
}
