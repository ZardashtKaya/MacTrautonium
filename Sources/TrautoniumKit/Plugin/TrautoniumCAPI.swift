import Foundation
import AppKit

@_cdecl("trautonium_create")
public func trautonium_create(sampleRate: Double) -> UnsafeMutableRawPointer {
    let engine = TrautoniumPluginEngine(sampleRate: Float(sampleRate > 0 ? sampleRate : 48000.0))
    let retained = Unmanaged.passRetained(engine).toOpaque()
    return retained
}

@_cdecl("trautonium_destroy")
public func trautonium_destroy(handle: UnsafeMutableRawPointer) {
    _ = Unmanaged<TrautoniumPluginEngine>.fromOpaque(handle).takeRetainedValue()
}

@_cdecl("trautonium_set_sample_rate")
public func trautonium_set_sample_rate(handle: UnsafeMutableRawPointer, sampleRate: Double) {
    let engine = Unmanaged<TrautoniumPluginEngine>.fromOpaque(handle).takeUnretainedValue()
    engine.setSampleRate(Float(sampleRate))
}

@_cdecl("trautonium_reset")
public func trautonium_reset(handle: UnsafeMutableRawPointer) {
    let engine = Unmanaged<TrautoniumPluginEngine>.fromOpaque(handle).takeUnretainedValue()
    engine.panic()
}

@_cdecl("trautonium_set_touch_enabled")
public func trautonium_set_touch_enabled(handle: UnsafeMutableRawPointer, enabled: Bool) {
    let engine = Unmanaged<TrautoniumPluginEngine>.fromOpaque(handle).takeUnretainedValue()
    engine.isTouchInputEnabled = enabled
}

@_cdecl("trautonium_set_active_instance")
public func trautonium_set_active_instance(handle: UnsafeMutableRawPointer) {
    let engine = Unmanaged<TrautoniumPluginEngine>.fromOpaque(handle).takeUnretainedValue()
    TrautoniumPluginEngine.activeInstance = engine
}

@_cdecl("trautonium_note_on")
public func trautonium_note_on(handle: UnsafeMutableRawPointer, channel: Int32, note: Int32, velocity: Float) {
    let engine = Unmanaged<TrautoniumPluginEngine>.fromOpaque(handle).takeUnretainedValue()
    engine.noteOn(channel: Int(channel), note: Int(note), velocity: velocity)
}

@_cdecl("trautonium_note_off")
public func trautonium_note_off(handle: UnsafeMutableRawPointer, channel: Int32, note: Int32) {
    let engine = Unmanaged<TrautoniumPluginEngine>.fromOpaque(handle).takeUnretainedValue()
    engine.noteOff(channel: Int(channel), note: Int(note))
}

@_cdecl("trautonium_pitch_bend")
public func trautonium_pitch_bend(handle: UnsafeMutableRawPointer, channel: Int32, bend14: Int32) {
    let engine = Unmanaged<TrautoniumPluginEngine>.fromOpaque(handle).takeUnretainedValue()
    engine.pitchBend(channel: Int(channel), bend14: Int(bend14))
}

@_cdecl("trautonium_pressure")
public func trautonium_pressure(handle: UnsafeMutableRawPointer, channel: Int32, note: Int32, pressure: Float) {
    let engine = Unmanaged<TrautoniumPluginEngine>.fromOpaque(handle).takeUnretainedValue()
    let noteOpt: Int? = note >= 0 ? Int(note) : nil
    engine.pressure(channel: Int(channel), note: noteOpt, pressure: pressure)
}

@_cdecl("trautonium_cc")
public func trautonium_cc(handle: UnsafeMutableRawPointer, channel: Int32, cc: Int32, value: Int32) {
    let engine = Unmanaged<TrautoniumPluginEngine>.fromOpaque(handle).takeUnretainedValue()
    engine.cc(channel: Int(channel), cc: Int(cc), value: Int(value))
}

@_cdecl("trautonium_all_notes_off")
public func trautonium_all_notes_off(handle: UnsafeMutableRawPointer) {
    let engine = Unmanaged<TrautoniumPluginEngine>.fromOpaque(handle).takeUnretainedValue()
    engine.allNotesOff()
}

@_cdecl("trautonium_render")
public func trautonium_render(
    handle: UnsafeMutableRawPointer,
    outLeft: UnsafeMutablePointer<Float>,
    outRight: UnsafeMutablePointer<Float>,
    frameCount: Int32
) {
    let engine = Unmanaged<TrautoniumPluginEngine>.fromOpaque(handle).takeUnretainedValue()
    engine.render(left: outLeft, right: outRight, frameCount: Int(frameCount))
}

@_cdecl("trautonium_set_param")
public func trautonium_set_param(handle: UnsafeMutableRawPointer, paramId: Int32, value: Float) {
    let engine = Unmanaged<TrautoniumPluginEngine>.fromOpaque(handle).takeUnretainedValue()
    var patch = engine.patch
    var prefs = engine.prefs
    switch paramId {
    case 0: // Master Volume (0..1)
        prefs.masterVolume = max(0, min(1, value))
        engine.prefs = prefs
    case 1: // Cutoff 1 (20..20000)
        patch.manuals[0].cutoff = max(20, min(20000, value))
        engine.patch = patch
    case 2: // Resonance 1 (0..0.95)
        patch.manuals[0].resonance = max(0, min(0.95, value))
        engine.patch = patch
    case 3: // Volume 1 (0..1)
        patch.manuals[0].volume = max(0, min(1, value))
        engine.patch = patch
    case 4: // Vowel 1 (-1..4)
        patch.manuals[0].vowel = max(-1, min(4, Int(round(value))))
        engine.patch = patch
    case 5: // Register 1 (0..2)
        patch.manuals[0].register = max(0, min(2, Int(round(value))))
        engine.patch = patch
    case 6: // Cutoff 2 (20..20000)
        patch.manuals[1].cutoff = max(20, min(20000, value))
        engine.patch = patch
    case 7: // Resonance 2 (0..0.95)
        patch.manuals[1].resonance = max(0, min(0.95, value))
        engine.patch = patch
    case 8: // Volume 2 (0..1)
        patch.manuals[1].volume = max(0, min(1, value))
        engine.patch = patch
    case 9: // Delay Mix (0..1)
        patch.echoMix = max(0, min(1, value))
        engine.patch = patch
    case 10: // Delay Time (50..1200)
        patch.echoTimeMs = max(50, min(1200, value))
        engine.patch = patch
    case 11: // Reverb Mix (0..1)
        patch.reverbMix = max(0, min(1, value))
        engine.patch = patch
    case 12: // Saturation Drive (0..1)
        patch.saturation = max(0, min(1, value))
        engine.patch = patch
    default:
        break
    }
}

@_cdecl("trautonium_get_param")
public func trautonium_get_param(handle: UnsafeMutableRawPointer, paramId: Int32) -> Float {
    let engine = Unmanaged<TrautoniumPluginEngine>.fromOpaque(handle).takeUnretainedValue()
    let patch = engine.patch
    let prefs = engine.prefs
    switch paramId {
    case 0: return prefs.masterVolume
    case 1: return patch.manuals[0].cutoff
    case 2: return patch.manuals[0].resonance
    case 3: return patch.manuals[0].volume
    case 4: return Float(patch.manuals[0].vowel)
    case 5: return Float(patch.manuals[0].register)
    case 6: return patch.manuals[1].cutoff
    case 7: return patch.manuals[1].resonance
    case 8: return patch.manuals[1].volume
    case 9: return patch.echoMix
    case 10: return patch.echoTimeMs
    case 11: return patch.reverbMix
    case 12: return patch.saturation
    default: return 0.0
    }
}
