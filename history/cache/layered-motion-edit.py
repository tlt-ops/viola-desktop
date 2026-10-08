from pathlib import Path
root=Path('/Users/tanlantian/Library/Caches/ViolaDesktop/source')
workspace=Path('/Users/tanlantian/Documents/ChatGPT/键鼠互动')
def save(rel,s):
 for folder in [root,workspace]:
  p=folder/rel;t=p.with_suffix(p.suffix+'.tmp');t.write_text(s);t.replace(p)
p='Sources/ViolaCore/FixedLaughMotion.swift';s=(root/p).read_text();s=s.replace('natural-belly-laugh-v2','layered-belly-laugh-v3');s=s.replace('''    /// Unweighted radians. Apply to the complete upper body at the waist so
    /// the arms, dress, face and hair share a single coherent forward bow.''','''    /// Slow unweighted torso lean in radians. Contraction belongs to the
    /// independent chest, shoulders and head, rather than this whole-body pivot.''');s=s.replace('return bow(age:age)*0.105 + pulse(age:age)*0.042 - inhale(age:age)*0.015','return bow(age:age)*0.040-inhale(age:age)*0.006');s=s.replace('''    /// A small nod accompanies the torso contraction, never an independent
    /// fast head shake. Unweighted radians, same rotation sign as the torso.''','''    /// Independent head rotation in radians, relative to the chest/neck.
    /// Apply to the head layer only; do not add it to the torso pivot.''');s=s.replace('return bow(age:age)*0.015+pulse(age:age)*0.028-inhale(age:age)*0.008','return bow(age:age)*0.010+pulse(age:age)*0.040-inhale(age:age)*0.008');needle='    /// 0...1 opening emphasis:';new='''    /// Direct vertical chest scale: shallow contraction on each chuckle,
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

    /// Relative hair rotation in radians, trailing the independent head by
    /// 80 ms. The final envelope settles the delayed strand at the clip boundary.
    public static func hairSway(age: Double) -> Double {
        guard isActive(age) else { return 0 }
        return headNod(age:age-0.08)*0.65*smooth((duration-age)/0.25)
    }

''';s=s.replace(needle,new+needle);save(p,s)
p='Sources/ViolaChecks/main.swift';s=(root/p).read_text();needle='    func testFrameCadenceActiveDoesNotSkipJitteredTicks() {';new='''    func testLayeredLaughMotionRangesContinuityAndNeutralRecovery() {
        checkEqual(FixedLaughMotion.revision,"layered-belly-laugh-v3")
        checkEqual(FixedLaughMotion.duration,8)
        let curves: [(Double) -> Double] = [
            { FixedLaughMotion.torsoRotation(age:$0) },
            { FixedLaughMotion.headNod(age:$0) },
            { FixedLaughMotion.chestCompression(age:$0) },
            { FixedLaughMotion.shoulderLift(age:$0) },
            { FixedLaughMotion.hairSway(age:$0) }
        ]
        let neutral = [0.0,0,1,0,0]
        let maximumStep = [0.004,0.008,0.006,0.4,0.005]
        var previous = curves.map { $0(0) }
        var maximumHead = 0.0, minimumChest = 1.0, maximumChest = 1.0
        for n in 0...960 {
            let age = Double(n)/120
            let values = curves.map { $0(age) }
            for index in values.indices {
                checkTrue(values[index].isFinite)
                checkLess(abs(values[index]-previous[index]),maximumStep[index])
            }
            checkLess(abs(values[0]),0.05); checkLess(abs(values[1]),0.055)
            checkGreater(values[2],0.969); checkLess(values[2],1.021)
            checkLess(abs(values[3]),3.01); checkLess(abs(values[4]),0.04)
            maximumHead = max(maximumHead,values[1])
            minimumChest = min(minimumChest,values[2]); maximumChest = max(maximumChest,values[2])
            previous = values
        }
        checkGreater(maximumHead,0.03)
        checkLess(minimumChest,0.98); checkGreater(maximumChest,1.01)
        for age in [-1.0,0,8,9,Double.infinity,Double.nan] {
            for index in curves.indices { checkEqual(curves[index](age),neutral[index],accuracy:0.0000001) }
        }
        for index in curves.indices {
            checkEqual(curves[index](8-0.000001),neutral[index],accuracy:0.000001)
        }
        // Hair receives the earlier head motion, not an identical synchronous
        // rotation; sample before the terminal settling envelope takes effect.
        checkEqual(FixedLaughMotion.hairSway(age:1.10),FixedLaughMotion.headNod(age:1.02)*0.65,accuracy:0.0000001)
        checkGreater(abs(FixedLaughMotion.hairSway(age:1.02)-FixedLaughMotion.headNod(age:1.02)*0.65),0.001)
    }
''';s=s.replace(needle,new+needle);needle='    ("testFrameCadenceActiveDoesNotSkipJitteredTicks", suite.testFrameCadenceActiveDoesNotSkipJitteredTicks),';s=s.replace(needle,'    ("testLayeredLaughMotionRangesContinuityAndNeutralRecovery", suite.testLayeredLaughMotionRangesContinuityAndNeutralRecovery),\n'+needle);save(p,s)
