import Foundation
import AppKit
import SwiftUI
import TrautoniumKit

@MainActor
private func createHostingView(engine: TrautoniumPluginEngine) -> NSView {
    let state = AppState(pluginEngine: engine)
    let hosting = NSHostingView(rootView: ContentView(state: state))
    hosting.frame = NSRect(x: 0, y: 0, width: 880, height: 600)
    hosting.autoresizingMask = [.width, .height]
    return hosting
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
