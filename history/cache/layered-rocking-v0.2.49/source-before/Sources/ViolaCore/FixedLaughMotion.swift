import Foundation

/// Original 5.6-second rocking and kicking laugh, restored at the user's request.
/// The seated rider follows the supporting friend's sway; her own bounce is added
/// without replacing the original head, torso or normal keyboard/mouse artwork.
public enum FixedLaughMotion {
    public static let revision = "original-rocking-laugh-v4"
    public static let duration = 5.6
    public static let entryDuration = 0.42
    public static let exitDuration = 0.7

    public static func weight(age: Double) -> Double {
        guard isActive(age) else { return 0 }
        return smooth(age/entryDuration)*smooth((duration-age)/exitDuration)
    }
    public static func pulse(age: Double) -> Double {
        guard isActive(age) else { return 0 }
        return pow(cos(age*13),2)
    }
    public static func bounce(age: Double) -> Double {
        guard isActive(age) else { return 0 }
        return sin(age*17)*2.6+sin(age*8.5)*1.4
    }
    public static func supportSway(age: Double) -> Double {
        guard isActive(age) else { return 0 }
        return sin(age*5.1)*0.055+sin(age*11.7)*0.012
    }
    public static func supportDip(age: Double) -> Double {
        guard isActive(age) else { return 0 }
        return -(3.5+sin(age*8.5)*2.5)
    }
    public static func legSwing(age: Double, front: Bool) -> Double {
        guard isActive(age) else { return 0 }
        return sin(age*5.8+(front ? 0 : 2.1))*(front ? 0.82 : 0.76)
    }
    public static func legSideSwing(age: Double, front: Bool) -> Double {
        guard isActive(age) else { return 0 }
        return sin(age*4.1+(front ? 0.5 : 2.8))*(front ? 0.15 : 0.14)
    }

    // The replaced painted belly-laugh/tear-wipe rig is archived, and is not
    // instantiated. Neutral compatibility values prevent accidental mixed clips.
    public static func inhale(age: Double) -> Double { 0 }
    public static func tearWeight(age: Double) -> Double { 0 }
    public static func wipeWeight(age: Double) -> Double { 0 }
    public static func wipeStroke(age: Double) -> Double { 0 }
    public static func torsoRotation(age: Double) -> Double { 0 }
    public static func torsoTranslation(age: Double) -> (x: Double, y: Double) { (0,0) }
    public static func headNod(age: Double) -> Double { 0 }
    public static func chestCompression(age: Double) -> Double { 1 }
    public static func shoulderLift(age: Double) -> Double { 0 }
    public static func hairSway(age: Double) -> Double { 0 }
    public static func mouthExcitement(age: Double) -> Double { pulse(age:age) }

    private static func isActive(_ age: Double) -> Bool { age.isFinite && age >= 0 && age < duration }
    private static func smooth(_ value: Double) -> Double {
        let x = min(1,max(0,value)); return x*x*(3-2*x)
    }
}
