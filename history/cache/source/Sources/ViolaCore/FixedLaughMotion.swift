import Foundation

/// Authored belly-laugh v2: inhale, three chuckles, a breath, two chuckles,
/// one last chuckle, wipe away the tears, then settle. Input changes must not retime this clip.
/// Revise it only after an explicit request to change the laugh.
public enum FixedLaughMotion {
    public static let revision = "layered-rocking-laugh-v5"
    public static let duration = 8.0
    public static let entryDuration = 0.42
    public static let exitDuration = 0.7

    public static func weight(age: Double) -> Double {
        guard age >= 0, age < duration else { return 0 }
        return smooth(age/entryDuration)*smooth((duration-age)/exitDuration)
    }

    /// An exhalation has a quick contraction and a slower release. Each bump
    /// reaches rest before the next one; there is no continuous shaking wave.
    public static func pulse(age: Double) -> Double {
        guard isActive(age) else { return 0 }
        return bump(age, peak:1.02, attack:0.16, release:0.27)
            + bump(age, peak:1.48, attack:0.15, release:0.28)*0.91
            + bump(age, peak:1.94, attack:0.17, release:0.31)*0.77
            + bump(age, peak:2.92, attack:0.19, release:0.32)*0.96
            + bump(age, peak:3.40, attack:0.16, release:0.31)*0.78
            + bump(age, peak:4.15, attack:0.19, release:0.36)*0.66
    }

    /// Shoulders and chest lift during the silent breaths between phrases.
    public static func inhale(age: Double) -> Double {
        guard isActive(age) else { return 0 }
        return bump(age, peak:0.55, attack:0.48, release:0.31)
            + bump(age, peak:2.58, attack:0.30, release:0.20)*0.75
            + bump(age, peak:3.92, attack:0.19, release:0.15)*0.45
    }

    /// Tears develop during the second laughter phrase, before either hand
    /// rises. They disappear as the two wipes clear the cheek.
    public static func tearWeight(age: Double) -> Double {
        guard isActive(age) else { return 0 }
        return smooth((age-3.2)/0.55)*(1-smooth((age-5.65)/0.8))
    }

    /// Blend into the painted hand-at-eye pose, hold for both gentle wipes,
    /// then lower the hand before fading back to the ordinary seated pose.
    public static func wipeWeight(age: Double) -> Double {
        guard isActive(age) else { return 0 }
        return smooth((age-5.0)/0.35)*(1-smooth((age-6.6)/0.5))
    }

    /// Signed source-art points for a subtle lateral wipe. This is not an
    /// arm deformation; apply only to an appropriate rigid painted layer.
    public static func wipeStroke(age: Double) -> Double {
        guard isActive(age) else { return 0 }
        func stroke(_ start: Double) -> Double {
            let progress = (age-start)/0.48
            guard progress > 0, progress < 1 else { return 0 }
            return sin(progress*2*Double.pi)*sin(progress*Double.pi)*1.8
        }
        return stroke(5.45)+stroke(6.0)
    }

    /// Added forward/backward rocking at the seated waist. Keep the authored
    /// chest contraction, smile and tear-wipe timeline from the .47 clip.
    public static func torsoRotation(age: Double) -> Double {
        guard isActive(age) else { return 0 }
        return bow(age:age)*0.040-inhale(age:age)*0.006
            + sin((age-0.6)*4.4)*0.145*rockWeight(age:age)
    }

    /// Unweighted source-art points in an upward-positive coordinate system.
    /// The renderer applies laugh weight and its reduced-motion scale once.
    public static func torsoTranslation(age: Double) -> (x: Double, y: Double) {
        guard isActive(age) else { return (0,0) }
        return (bow(age:age)*2.5, -bow(age:age)*4.0+bounce(age:age))
    }

    /// Independent head rotation in radians, relative to the chest/neck.
    /// Apply to the head layer only; do not add it to the torso pivot.
    public static func headNod(age: Double) -> Double {
        guard isActive(age) else { return 0 }
        return bow(age:age)*0.010+pulse(age:age)*0.040-inhale(age:age)*0.008
    }

    /// Direct vertical chest scale: shallow contraction on each chuckle,
    /// slight expansion on an inhale, and exactly 1 outside the active clip.
    /// Weight/reduced-motion blending is the renderer's responsibility.
    public static func chestCompression(age: Double) -> Double {
        guard isActive(age) else { return 1 }
        return 1+inhale(age:age)*0.014-pulse(age:age)*0.028
    }

    /// Independent shoulder lift in upward-positive canvas units. Do not add
    /// this displacement to the waist or retained legs.
    public static func shoulderLift(age: Double) -> Double {
        guard isActive(age) else { return 0 }
        return inhale(age:age)*2.0-pulse(age:age)*1.8
    }

    /// Independent hair rotation relative to the chest, in radians, trailing the head by
    /// 80 ms. The final envelope settles the delayed strand at the clip boundary.
    public static func hairSway(age: Double) -> Double {
        guard isActive(age) else { return 0 }
        return headNod(age:age-0.08)*0.65*smooth((duration-age)/0.25)
    }

    /// 0...1 opening emphasis: broad on a chuckle, eased toward a recovering
    /// smile in the breathing gaps. Mouth art supplies the actual shape.
    public static func mouthExcitement(age: Double) -> Double {
        guard isActive(age) else { return 0 }
        return min(1,bow(age:age)*0.28+pulse(age:age)*0.70)
    }

    public static func bounce(age: Double) -> Double {
        guard isActive(age) else { return 0 }
        return (inhale(age:age)*2.6-pulse(age:age)*2.4)*(1-smooth((age-4.4)/0.1))
    }

    public static func supportSway(age: Double) -> Double {
        guard isActive(age) else { return 0 }
        let unstable = (sin(age*5.1)*0.050+sin(age*11.7)*0.010)*rockWeight(age:age)
        let wipingSway = sin(age*3.4)*0.008*wipeWeight(age:age)
        return bow(age:age)*0.004+pulse(age:age)*0.004-inhale(age:age)*0.002+unstable+wipingSway
    }

    public static func supportDip(age: Double) -> Double {
        guard isActive(age) else { return 0 }
        return -bow(age:age)*0.7-pulse(age:age)*0.7-(3.0+sin(age*8.5)*1.6)*rockWeight(age:age)
    }

    /// Alternating calf kicks about the retained seated knees, settling before
    /// the wiping hand rises. Idle leg movement remains independent.
    public static func legSwing(age: Double, front: Bool) -> Double {
        guard isActive(age) else { return 0 }
        return bow(age:age)*(front ? 0.025 : 0.018)
            + pulse(age:age)*(front ? 0.010 : 0.007)
            + sin(age*5.8+(front ? 0 : 2.1))*(front ? 0.82 : 0.76)*rockWeight(age:age)
    }

    public static func legSideSwing(age: Double, front: Bool) -> Double {
        guard isActive(age) else { return 0 }
        return bow(age:age)*(front ? 0.007 : -0.006)
            + sin(age*4.1+(front ? 0.5 : 2.8))*(front ? 0.15 : 0.14)*rockWeight(age:age)
    }

    /// Ramp in without a first-frame kick, then calm down before the existing
    /// 5.0s eye-wipe begins. Head, eye and hand contact stay stable in that phase.
    public static func rockWeight(age: Double) -> Double {
        guard isActive(age) else { return 0 }
        return smooth(age/0.65)*(1-smooth((age-4.2)/0.75))
    }

    /// A portrait is opaque throughout the handoff: never crossfade two pairs
    /// of painted eyes. Normal and dedicated renderers consume this predicate.
    public static func ownsLaughPortrait(weight: Double) -> Bool { weight >= 0.5 }

    private static func isActive(_ age: Double) -> Bool { age >= 0 && age < duration }
    private static func smooth(_ value: Double) -> Double {
        let x = min(1,max(0,value))
        return x*x*(3-2*x)
    }

    private static func bump(_ age: Double, peak: Double, attack: Double, release: Double) -> Double {
        if age <= peak { return smooth((age-(peak-attack))/attack) }
        return 1-smooth((age-peak)/release)
    }

    private static func bow(age: Double) -> Double {
        let poses: [(Double,Double)] = [
            (0,0), (0.62,0.08), (0.92,0.82), (2.16,0.90),
            (2.57,0.28), (2.85,0.87), (3.56,0.94),
            (3.93,0.48), (4.21,0.80), (4.52,0.61),
            (5.05,0.12), (5.35,0.10), (6.6,0.10), (7.1,0.06), (duration,0)
        ]
        for index in 1..<poses.count where age <= poses[index].0 {
            let previous = poses[index-1], next = poses[index]
            let blend = smooth((age-previous.0)/(next.0-previous.0))
            return previous.1+(next.1-previous.1)*blend
        }
        return 0
    }
}
