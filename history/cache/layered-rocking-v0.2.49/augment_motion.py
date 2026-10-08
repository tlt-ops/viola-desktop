from pathlib import Path
r=Path('/Users/tanlantian/Library/Caches/ViolaDesktop/source')
p=r/'Sources/ViolaCore/FixedLaughMotion.swift';s=p.read_text()
s=s.replace('layered-belly-laugh-v3','layered-rocking-laugh-v5')
s=s.replace('''    /// Slow unweighted torso lean in radians. Contraction belongs to the
    /// independent chest, shoulders and head, rather than this whole-body pivot.''','''    /// Added forward/backward rocking at the seated waist. Keep the authored
    /// chest contraction, smile and tear-wipe timeline from the .47 clip.''')
s=s.replace('return bow(age:age)*0.040-inhale(age:age)*0.006','return bow(age:age)*0.040-inhale(age:age)*0.006\n            + sin((age-0.6)*4.4)*0.145*rockWeight(age:age)')
s=s.replace('''        return bow(age:age)*0.004+pulse(age:age)*0.004-inhale(age:age)*0.002''','''        let unstable = (sin(age*5.1)*0.050+sin(age*11.7)*0.010)*rockWeight(age:age)
        let wipingSway = sin(age*3.4)*0.008*wipeWeight(age:age)
        return bow(age:age)*0.004+pulse(age:age)*0.004-inhale(age:age)*0.002+unstable+wipingSway''')
s=s.replace('''        return -bow(age:age)*0.7-pulse(age:age)*0.7''','''        return -bow(age:age)*0.7-pulse(age:age)*0.7
            -(3.0+sin(age*8.5)*1.6)*rockWeight(age:age)''')
s=s.replace('''    /// Seated knees settle slightly as she folds toward her abdomen. They do
    /// not alternate or kick in time with the laughter.''','''    /// Alternating calf kicks about the retained seated knees, settling before
    /// the wiping hand rises. Idle leg movement remains independent.''')
s=s.replace('''        return bow(age:age)*(front ? 0.025 : 0.018)
            + pulse(age:age)*(front ? 0.010 : 0.007)''','''        return bow(age:age)*(front ? 0.025 : 0.018)
            + pulse(age:age)*(front ? 0.010 : 0.007)
            + sin(age*5.8+(front ? 0 : 2.1))*(front ? 0.82 : 0.76)*rockWeight(age:age)''')
s=s.replace('''        return bow(age:age)*(front ? 0.007 : -0.006)''','''        return bow(age:age)*(front ? 0.007 : -0.006)
            + sin(age*4.1+(front ? 0.5 : 2.8))*(front ? 0.15 : 0.14)*rockWeight(age:age)''')
s=s.replace('''    private static func isActive(_ age: Double) -> Bool''','''    /// Ramp in without a first-frame kick, then calm down before the existing
    /// 5.0s eye-wipe begins. Head, eye and hand contact stay stable in that phase.
    public static func rockWeight(age: Double) -> Double {
        guard isActive(age) else { return 0 }
        return smooth(age/0.65)*(1-smooth((age-4.2)/0.75))
    }

    private static func isActive(_ age: Double) -> Bool''')
p.write_text(s)
p=r/'Sources/ViolaDesktop/FixedLaughRig.swift';s=p.read_text().replace('layered-belly-laugh-v3','layered-rocking-laugh-v5').replace('articulated-belly-laugh-then-tear-wipe-v3','rocking-belly-laugh-then-tear-wipe-v5')
s=s.replace('''            "headRotation":headAngle,''','''            "rockWeight":FixedLaughMotion.rockWeight(age:age),"paintedEyeOwner":true,
            "paintedEyeArt":"viola-layered-head-v0.2.47.png","normalEyeOverlayOpacity":1-weight,
            "headRotation":headAngle,''')
p.write_text(s)
p=r/'Sources/ViolaChecks/main.swift';s=p.read_text().replace('layered-belly-laugh-v3','layered-rocking-laugh-v5')
s=s.replace('let maximumStep = [0.004,0.008,0.006,0.4,0.005]','let maximumStep = [0.009,0.008,0.006,0.4,0.005]')
s=s.replace('checkLess(abs(values[0]),0.05)','checkLess(abs(values[0]),0.19)')
s=s.replace('''        var maximumHead = 0.0, minimumChest = 1.0, maximumChest = 1.0''','''        var maximumHead = 0.0, minimumChest = 1.0, maximumChest = 1.0
        var minimumLean = 0.0, maximumLean = 0.0''')
s=s.replace('''            maximumHead = max(maximumHead,values[1])''','''            minimumLean = min(minimumLean,values[0]); maximumLean = max(maximumLean,values[0])
            maximumHead = max(maximumHead,values[1])''')
s=s.replace('''        checkGreater(maximumHead,0.03)''','''        checkLess(minimumLean,-0.09); checkGreater(maximumLean,0.15)
        checkGreater(maximumHead,0.03)''')
a=s.index('    func testFrameCadenceActiveDoesNotSkipJitteredTicks()')
s=s[:a]+'''    func testLayeredLaughKeepsWipeWhileAddingAlternatingKicksAndEffortSway() {
        var leftMin = 1.0, leftMax = -1.0, rightMin = 1.0, rightMax = -1.0
        var swayMin = 1.0, swayMax = -1.0, opposed = 0
        for n in 80...410 {
            let age = Double(n)/100
            let left = FixedLaughMotion.legSwing(age:age,front:true)
            let right = FixedLaughMotion.legSwing(age:age,front:false)
            let sway = FixedLaughMotion.supportSway(age:age)
            leftMin = min(leftMin,left);leftMax = max(leftMax,left)
            rightMin = min(rightMin,right);rightMax = max(rightMax,right)
            swayMin = min(swayMin,sway);swayMax = max(swayMax,sway)
            if left*right < 0 { opposed += 1 }
        }
        checkLess(leftMin,-0.77);checkGreater(leftMax,0.80)
        checkLess(rightMin,-0.72);checkGreater(rightMax,0.75)
        checkLess(swayMin,-0.045);checkGreater(swayMax,0.055)
        checkGreater(opposed,180)
        for age in [5.0,5.45,5.65,6.0,6.5,7.0] {
            checkEqual(FixedLaughMotion.rockWeight(age:age),0)
            checkLess(abs(FixedLaughMotion.legSwing(age:age,front:true)),0.03)
            checkLess(abs(FixedLaughMotion.legSwing(age:age,front:false)),0.025)
        }
        checkEqual(FixedLaughMotion.duration,8)
        checkEqual(FixedLaughMotion.wipeWeight(age:6),1)
        checkGreater(FixedLaughMotion.tearWeight(age:5.6),0.9)
    }
''' +s[a:]
s=s.replace('''    ("testFrameCadenceActiveDoesNotSkipJitteredTicks",''','''    ("testLayeredLaughKeepsWipeWhileAddingAlternatingKicksAndEffortSway", suite.testLayeredLaughKeepsWipeWhileAddingAlternatingKicksAndEffortSway),
    ("testFrameCadenceActiveDoesNotSkipJitteredTicks",''')
p.write_text(s)
p=r/'Sources/ViolaDesktop/main.swift';s=p.read_text().replace('Layered laugh v3:', 'Layered rocking laugh v5:')
s=s.replace('''                        "face":face,"arms":arms])''','''                        "face":face,"arms":arms,"leftLeg":frame.leftLegSwing,"rightLeg":frame.rightLegSwing,
                        "supportSway":frame.supportSway,"supportDip":frame.supportDip,
                        "attachment":rig.motionSeamDiagnostics["breathingAttachmentDeltaY"] ?? [:]])''',1)
# wider face region follows the stronger waist pivot and support sway.
s=s.replace('region:CGRect(x:242,y:745,width:145,height:105),scale:4','region:CGRect(x:185,y:700,width:255,height:185),scale:3',1)
s=s.replace('region:CGRect(x:196,y:376,width:162,height:112),scale:4','region:CGRect(x:160,y:350,width:215,height:165),scale:3',1)
p.write_text(s)
p=r/'packaging/Info.plist';s=p.read_text().replace('<string>0.2.48</string>','<string>0.2.49</string>').replace('<string>49</string>','<string>50</string>');p.write_text(s)
print('Preserved .47 smile/belly/tears/wipe art and 8s timeline; added waist rocking, opposing kicks and support sway.')
