import Foundation

public struct TrautoniumPrefs: Codable, Sendable, Equatable {
    public var pressSource: PressSource = .force
    public var pressCurve: PressCurve = .linear
    public var forceFloorGrams: Float = 0.0     // Minimum sensitivity threshold (grams)
    public var forceMaxGrams: Float = 320.0     // Full pressure saturation threshold (grams)
    public var areaFloor: Float = 0.0           // Capacitance area floor
    public var areaMax: Float = 0.0             // Capacitance area max (0 = auto-adjust)
    public var isCalibrated: Bool = false
    public var gateThresholdGrams: Float = 0.0  // Hysteresis threshold (0 = always triggered on contact)
    public var minLevel: Float = 0.12           // Minimum volume at lightest feather touch
    public var snapSpeedMs: Float = 120.0       // Time constant for magnetic scale attraction
    public var enableHaptics: Bool = true       // Tactile click on semitone crossing
    public var masterVolume: Float = 0.85

    public init() {}
}
