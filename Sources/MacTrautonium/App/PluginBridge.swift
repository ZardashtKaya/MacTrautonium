import Foundation
import AppKit
import SwiftUI
import TrautoniumKit

@MainActor
final class TrautoniumPluginHostView: NSView {
    private weak var engine: TrautoniumPluginEngine?
    private let state: AppState

    init(engine: TrautoniumPluginEngine, state: AppState, hostingView: NSView) {
        self.engine = engine
        self.state = state
        super.init(frame: hostingView.frame)
        self.autoresizingMask = [.width, .height]
        hostingView.frame = self.bounds
        hostingView.autoresizingMask = [.width, .height]
        addSubview(hostingView)

        self.allowedTouchTypes = [.indirect, .direct]

        TrautoniumPluginEngine.activeInstance = engine
        TouchInputManager.shared.start()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        if let engine = engine {
            TrautoniumPluginEngine.activeInstance = engine
        }
        return true
    }

    override func mouseDown(with event: NSEvent) {
        if let engine = engine {
            TrautoniumPluginEngine.activeInstance = engine
        }
        self.window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            if let engine = engine {
                TrautoniumPluginEngine.activeInstance = engine
            }
            TouchInputManager.shared.start()
        }
    }

    override func touchesBegan(with event: NSEvent) {
        handleAppKitTouches(event)
        super.touchesBegan(with: event)
    }

    override func touchesMoved(with event: NSEvent) {
        handleAppKitTouches(event)
        super.touchesMoved(with: event)
    }

    override func touchesEnded(with event: NSEvent) {
        handleAppKitTouchesEnded(event)
        super.touchesEnded(with: event)
    }

    override func touchesCancelled(with event: NSEvent) {
        handleAppKitTouchesEnded(event)
        super.touchesCancelled(with: event)
    }

    private func handleAppKitTouches(_ event: NSEvent) {
        if let engine = engine {
            TrautoniumPluginEngine.activeInstance = engine
        }
        let touches = event.touches(matching: .touching, in: self)
        for touch in touches {
            let id = touch.identity.hash
            let normPos = touch.normalizedPosition
            let x = Float(normPos.x)
            let y = Float(1.0 - normPos.y)
            let pressure: Float = 0.75
            TouchInputManager.shared.setAppKitTouch(id: id, x: x, y: y, pressure: pressure)
        }
    }

    private func handleAppKitTouchesEnded(_ event: NSEvent) {
        let touches = event.touches(matching: .ended, in: self)
        for touch in touches {
            let id = touch.identity.hash
            TouchInputManager.shared.removeAppKitTouch(id: id)
        }
    }
}

@MainActor
private func createHostingView(engine: TrautoniumPluginEngine) -> NSView {
    TrautoniumPluginEngine.activeInstance = engine
    engine.isTouchInputEnabled = true
    let state = AppState(pluginEngine: engine)
    let hosting = NSHostingView(rootView: ContentView(state: state))
    hosting.frame = NSRect(x: 0, y: 0, width: 880, height: 600)
    hosting.autoresizingMask = [.width, .height]
    return TrautoniumPluginHostView(engine: engine, state: state, hostingView: hosting)
}

@MainActor
@_cdecl("trautonium_create_view")
public func trautonium_create_view(handle: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer {
    let engine = Unmanaged<TrautoniumPluginEngine>.fromOpaque(handle).takeUnretainedValue()
    let view = createHostingView(engine: engine)
    return Unmanaged.passRetained(view).toOpaque()
}

@MainActor
@_cdecl("trautonium_destroy_view")
public func trautonium_destroy_view(viewHandle: UnsafeMutableRawPointer) {
    let view = Unmanaged<NSView>.fromOpaque(viewHandle).takeRetainedValue()
    view.removeFromSuperview()
}
