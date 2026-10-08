from pathlib import Path
import re
root=Path('/Users/tanlantian/Library/Caches/ViolaDesktop/source')
old=Path('/Users/tanlantian/Library/Caches/ViolaDesktop/fixed-laugh-v0.2.45/source-before')
(root/'Sources/ViolaCore/FixedLaughMotion.swift').write_text('''import Foundation

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
''')
p=root/'Sources/ViolaCore/Animation.swift'
s=p.read_text().replace('''        // The authored laugh includes its own inhalations and contractions.
        // Fade out idle breathing instead of layering a second body rhythm.
        if laughing { frame.breath *= 1-frame.laugh }
''','')
p.write_text(s)
p=root/'Sources/ViolaDesktop/LayerRenderer.swift'
s=p.read_text(); o=(old/'Sources/ViolaDesktop/LayerRenderer.swift').read_text()
s=s.replace('''    private var fixedLaugh: FixedLaughRig?
    private let laughBodyMask = CAGradientLayer()
    private let laughForeground = CALayer()
    private var laughForegroundPairs: [(CALayer,CALayer)] = []
''','''    private var keyboardLegacySleeveBlend: Double = 0
    private var keyboardLegacyHandOrder = false
''')
s=s.replace('''         "fixedLaugh":fixedLaugh?.diagnostics ?? ["active":false,"revision":FixedLaughRig.revision]]''','''         "fixedLaugh":["active":sourceLaughWeight > 0,"revision":FixedLaughMotion.revision,
            "art":"original-reference-components","weight":sourceLaughWeight]]''')
a=s.index('            if let rig = FixedLaughRig(canvasSize:canvasSize) {')
b=s.index('            let face = SourceReferenceFaceRig',a)
s=s[:a]+s[b:]
a=s.index('    private func renderSourceArms('); b=s.index('    private func referenceArmPose(',a)
oa=o.index('    private func renderSourceArms('); ob=o.index('    private func referenceArmPose(',oa)
s=s[:a]+o[oa:ob]+s[b:]
# The source sleeves remain fully opaque; their old wrist solver owns the laugh.
# setDesksVisible is run on every frame to hide/show the correct single sleeve.
s=s.replace('''                (id == "reference_left_arm" && straightKeyboardArm != nil) ||''','''                (id == "reference_left_arm" && straightKeyboardArm != nil && keyboardLegacySleeveBlend == 0) ||''')
s=s.replace('''        straightKeyboardArm?.root.isHidden = !visible\n''','''        straightKeyboardArm?.root.isHidden = !visible || keyboardLegacySleeveBlend == 1\n''')
s=s.replace('''        if sourceReference { updateSourceArmVisibility() }\n''','')
s=s.replace('''        if sourceReference { renderNaturalLaughVisibility() }\n''','')
# Restore the original eyelid patch's ownership only outside laughter. During
# laughter SourceReferenceFaceRig supplies partial lids and the open mouth.
# Keep the parked mouse itself on the desk while its extracted hand leaves it.
s=s.replace('''        pose("reference_mouse",dx:mouseX,dy:mouseY)''','''        pose("reference_mouse",dx:mouseX+(parkedMouse.x-mouseX)*sourceLaughWeight,
            dy:mouseY+(parkedMouse.y-mouseY)*sourceLaughWeight)''')
p.write_text(s)
p=root/'Sources/ViolaDesktop/SourceReferenceFaceRig.swift'
s=p.read_text().replace('''        // The painted laugh owns its face; keep these original face patches
        // only for the normal portrait and for the independent friend.
        rider.opacity = Float(1-Self.ease(laugh))''','''        // The restored laugh uses the original portrait and registered face
        // patches throughout; its head/torso artwork never crossfades.
        rider.opacity = 1''')
p.write_text(s)
# Replace tests specific to the discarded v3 breathing/wipe with restoration
# evidence: opposing leg phases, strong support sway, soft entry/exit, 35% mode.
p=root/'Sources/ViolaChecks/main.swift'; s=p.read_text()
a=s.index('    func testNaturalLaughTearsPrecedeWipeAndClearBeforeHandLowers()')
b=s.index('    func testFrameCadenceActiveDoesNotSkipJitteredTicks()',a)
s=s[:a]+'''    func testOriginalLaughRestoresKicksAndSupportSway() {
        checkEqual(FixedLaughMotion.revision,"original-rocking-laugh-v4")
        checkEqual(FixedLaughMotion.duration,5.6)
        var leftMin = 1.0, leftMax = -1.0, rightMin = 1.0, rightMax = -1.0
        var swayMin = 1.0, swayMax = -1.0, opposing = 0
        for n in 50...480 {
            let age = Double(n)/100
            let l = FixedLaughMotion.legSwing(age:age,front:true)
            let r = FixedLaughMotion.legSwing(age:age,front:false)
            let sway = FixedLaughMotion.supportSway(age:age)
            leftMin = min(leftMin,l); leftMax = max(leftMax,l)
            rightMin = min(rightMin,r); rightMax = max(rightMax,r)
            swayMin = min(swayMin,sway); swayMax = max(swayMax,sway)
            if l*r < 0 { opposing += 1 }
            checkEqual(l,sin(age*5.8)*0.82,accuracy:0.0000001)
            checkEqual(r,sin(age*5.8+2.1)*0.76,accuracy:0.0000001)
            checkEqual(FixedLaughMotion.bounce(age:age),sin(age*17)*2.6+sin(age*8.5)*1.4,accuracy:0.0000001)
            checkEqual(FixedLaughMotion.supportDip(age:age),-(3.5+sin(age*8.5)*2.5),accuracy:0.0000001)
            checkEqual(FixedLaughMotion.tearWeight(age:age),0)
            checkEqual(FixedLaughMotion.wipeWeight(age:age),0)
        }
        checkLess(leftMin,-0.81); checkGreater(leftMax,0.81)
        checkLess(rightMin,-0.75); checkGreater(rightMax,0.75)
        checkLess(swayMin,-0.05); checkGreater(swayMax,0.05)
        checkGreater(opposing,200)
    }
    func testOriginalLaughContinuousEnvelopeAndReducedMotionRecovery() {
        let curves: [(Double) -> Double] = [FixedLaughMotion.bounce,
            FixedLaughMotion.supportSway, FixedLaughMotion.supportDip,
            { FixedLaughMotion.legSwing(age:$0,front:true) },
            { FixedLaughMotion.legSwing(age:$0,front:false) }]
        let maximumStep = [0.5,0.004,0.23,0.05,0.05]
        var previous = curves.map { $0(0)*FixedLaughMotion.weight(age:0) }
        for n in 0...672 {
            let age = Double(n)/120, weight = FixedLaughMotion.weight(age:Double(n)/120)
            for index in curves.indices {
                let value = curves[index](age)*weight
                checkTrue(value.isFinite)
                checkLess(abs(value-previous[index]),maximumStep[index])
                previous[index] = value
            }
        }
        for age in [-1.0,5.6,6,Double.infinity,Double.nan] {
            checkEqual(FixedLaughMotion.weight(age:age),0)
            for curve in curves { checkEqual(curve(age),0) }
        }
        for age in [0.0,5.6-0.000001] {
            for curve in curves { checkEqual(curve(age)*FixedLaughMotion.weight(age:age),0,accuracy:0.000001) }
        }
        let full = AnimationEngine(now:0), reduced = AnimationEngine(now:0)
        full.allowsShoeDrops = false; reduced.allowsShoeDrops = false
        reduced.reducedMotion = true
        checkTrue(full.startLaugh(now:0)); checkTrue(reduced.startLaugh(now:0))
        for n in 0...360 {
            let now = Double(n)/60, a = full.tick(now:Double(n)/60), b = reduced.tick(now:Double(n)/60)
            if a.laugh == 1 {
                checkEqual(b.leftLegSwing,a.leftLegSwing*0.35,accuracy:0.0000001)
                checkEqual(b.supportSway,a.supportSway*0.35,accuracy:0.0000001)
                checkEqual(b.laughBounce,a.laughBounce*0.35,accuracy:0.0000001)
                checkEqual(b.friendExpression,.effort)
            }
            if now >= 5.6 {
                checkEqual(a.laugh,0); checkEqual(a.supportSway,0); checkEqual(a.laughBounce,0)
            }
        }
    }
''' +s[b:]
s=s.replace('("testNaturalLaughTearsPrecedeWipeAndClearBeforeHandLowers", suite.testNaturalLaughTearsPrecedeWipeAndClearBeforeHandLowers)','("testOriginalLaughRestoresKicksAndSupportSway", suite.testOriginalLaughRestoresKicksAndSupportSway)')
s=s.replace('("testLayeredLaughMotionRangesContinuityAndNeutralRecovery", suite.testLayeredLaughMotionRangesContinuityAndNeutralRecovery)','("testOriginalLaughContinuousEnvelopeAndReducedMotionRecovery", suite.testOriginalLaughContinuousEnvelopeAndReducedMotionRecovery)')
p.write_text(s)
print('Restored original motion and original character/arm rendering; normal solvers retained.')
