import Foundation

/// Face handoff only; the authored laugh's timing and motion remain independent.
public enum LaughFaceTransition {
    public static func portraitBlend(weight: Double) -> Double {
        // The renderer already eases the authored entry/return envelope. A
        // second narrow handoff would compress it into a few abrupt frames.
        unit(weight)
    }

    public static func eyelidClosure(normal: Double, fixed: Double, weight: Double) -> Double {
        expressionBlend(normal: unit(normal), fixed: unit(fixed), weight: weight)
    }

    /// Also used for effort, brow tension and heart opacity. Values retain their
    /// own units, while the shared weight is bounded to the two endpoint poses.
    public static func expressionBlend(normal: Double, fixed: Double, weight: Double) -> Double {
        let w = unit(weight)
        return normal * (1 - w) + fixed * w
    }

    private static func unit(_ value: Double) -> Double {
        guard value.isFinite else { return value == .infinity ? 1 : 0 }
        return min(1, max(0, value))
    }
}
