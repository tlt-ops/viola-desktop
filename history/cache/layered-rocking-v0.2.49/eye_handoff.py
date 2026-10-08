from pathlib import Path
r=Path('/Users/tanlantian/Library/Caches/ViolaDesktop/source')
p=r/'Sources/ViolaCore/FixedLaughMotion.swift';s=p.read_text();pos=s.index('    private static func isActive(')
s=s[:pos]+'''    /// A portrait is opaque throughout the handoff: never crossfade two pairs
    /// of painted eyes. Normal and dedicated renderers consume this predicate.
    public static func ownsLaughPortrait(weight: Double) -> Bool { weight >= 0.5 }

''' +s[pos:];p.write_text(s)
p=r/'Sources/ViolaDesktop/FixedLaughRig.swift';s=p.read_text().replace('    let root = CALayer()','    let root = CALayer()\n    let portraitRoot = CALayer()',1)
s=s.replace('''        root.bounds = CGRect(origin:.zero,size:canvasSize); root.contentsScale = 2''','''        root.bounds = CGRect(origin:.zero,size:canvasSize); root.contentsScale = 2
        portraitRoot.anchorPoint = .zero; portraitRoot.position = .zero
        portraitRoot.bounds = root.bounds; portraitRoot.contentsScale = 2
        portraitRoot.opacity = 1; portraitRoot.isHidden = true''')
s=s.replace('''        root.addSublayer(head)
        root.addSublayer(r.wipeRoot)''','''        portraitRoot.addSublayer(head)
        portraitRoot.addSublayer(r.wipeRoot)''')
s=s.replace('''        hair.position = head.position
        let hairAngle = FixedLaughMotion.hairSway(age:age)*amount
        hair.setAffineTransform(CGAffineTransform(rotationAngle:angle+hairAngle))''','''        // At the ownership boundary fit the laugh's painted eye line to the
        // normal portrait. Then release that registration smoothly into the
        // untouched .47 head pose. This is one rigid similarity transform, not
        // an eye deformation or two translucent faces.
        let localEyes = [Self.point(350,413),Self.point(507,362)].map {
            CGPoint(x:$0.x-neck.x,y:$0.y-neck.y)
        }
        let normalEyes = [CGPoint(x:283.2+shoulderOffset.x,y:807.52+shoulderOffset.y),
                          CGPoint(x:331.2+shoulderOffset.x,y:815.20+shoulderOffset.y)]
        let naturalMap = head.affineTransform(), naturalPosition = head.position
        let localCenter = CGPoint(x:(localEyes[0].x+localEyes[1].x)/2,y:(localEyes[0].y+localEyes[1].y)/2)
        let sourceLine = CGPoint(x:localEyes[1].x-localEyes[0].x,y:localEyes[1].y-localEyes[0].y)
        let targetLine = CGPoint(x:normalEyes[1].x-normalEyes[0].x,y:normalEyes[1].y-normalEyes[0].y)
        let alignedAngle = atan2(targetLine.y,targetLine.x)-atan2(sourceLine.y,sourceLine.x)
        let alignedScale = hypot(targetLine.x,targetLine.y)/hypot(sourceLine.x,sourceLine.y)
        let normalCenter = CGPoint(x:(normalEyes[0].x+normalEyes[1].x)/2,y:(normalEyes[0].y+normalEyes[1].y)/2)
        let naturalCenter = localCenter.applying(naturalMap)
            .applying(CGAffineTransform(translationX:naturalPosition.x,y:naturalPosition.y))
        let progress = max(0,min(1,(weight-0.5)/0.5)), release = progress*progress*(3-2*progress)
        let naturalAngle = angle+headAngle
        let turn = atan2(sin(naturalAngle-alignedAngle),cos(naturalAngle-alignedAngle))
        let portraitAngle = alignedAngle+turn*release
        let portraitScale = alignedScale+(1-alignedScale)*release
        let center = CGPoint(x:normalCenter.x+(naturalCenter.x-normalCenter.x)*release,
                             y:normalCenter.y+(naturalCenter.y-normalCenter.y)*release)
        let portraitMap = CGAffineTransform(rotationAngle:portraitAngle).scaledBy(x:portraitScale,y:portraitScale)
        let centerOffset = localCenter.applying(portraitMap)
        head.position = CGPoint(x:center.x-centerOffset.x,y:center.y-centerOffset.y)
        head.setAffineTransform(portraitMap)
        let ownsPortrait = FixedLaughMotion.ownsLaughPortrait(weight:weight)
        portraitRoot.isHidden = !ownsPortrait
        hair.position = head.position
        let hairAngle = FixedLaughMotion.hairSway(age:age)*amount
        hair.setAffineTransform(CGAffineTransform(rotationAngle:portraitAngle-headAngle+hairAngle)
            .scaledBy(x:portraitScale,y:portraitScale))''')
s=s.replace('''wipe:wipe,wipeAngle:angle+headAngle)''','''wipe:wipe,wipeAngle:portraitAngle)''')
s=s.replace('''"paintedEyeOwner":true,
            "paintedEyeArt":"viola-layered-head-v0.2.47.png","normalEyeOverlayOpacity":1-weight,''','''"paintedEyeOwner":ownsPortrait,
            "paintedEyeArt":"viola-layered-head-v0.2.47.png","normalEyeOverlayOpacity":ownsPortrait ? 0.0 : 1.0,
            "portraitOpaque":true,"portraitOpacity":ownsPortrait ? 1.0 : 0.0,
            "portraitRegistrationRelease":release,"portraitScale":portraitScale,"portraitRotation":portraitAngle,''')
p.write_text(s)
p=r/'Sources/ViolaDesktop/LayerRenderer.swift';s=p.read_text()
s=s.replace('''                rootLayer.addSublayer(rig.root); fixedLaugh = rig''','''                rootLayer.addSublayer(rig.root); rootLayer.addSublayer(rig.portraitRoot); fixedLaugh = rig''')
s=s.replace('''        layers["head"]?.opacity = Float(1-weight)''','''        layers["head"]?.opacity = FixedLaughMotion.ownsLaughPortrait(weight:weight) ? 0 : 1''')
p.write_text(s)
p=r/'Sources/ViolaDesktop/SourceReferenceFaceRig.swift';s=p.read_text()
s=s.replace('''        // The painted laugh owns its face; keep these original face patches
        // only for the normal portrait and for the independent friend.
        rider.opacity = Float(1-Self.ease(laugh))''','''        // The normal head and the opaque dedicated laugh portrait use the same
        // ownership rule, preventing displaced old irises from showing through.
        rider.opacity = FixedLaughMotion.ownsLaughPortrait(weight:Self.ease(laugh)) ? 0 : 1''')
s=s.replace('''        diagnostics = ["riderClosure":riderClosure,"friendClosure":friendClosure,''','''        diagnostics = ["normalPortraitOpacity":Double(rider.opacity),
                       "riderClosure":riderClosure,"friendClosure":friendClosure,''')
p.write_text(s)
p=r/'Sources/ViolaDesktop/main.swift';s=p.read_text()
s=s.replace('''                              fixed["artSignature"] as? String == "viola-layered-clean-v0.2.47.png" else {''','''                              fixed["artSignature"] as? String == "viola-layered-clean-v0.2.47.png",
                              fixed["portraitOpaque"] as? Bool == true,
                              let portraitOpacity = fixed["portraitOpacity"] as? Double,
                              let normalOpacity = face["normalPortraitOpacity"] as? Double,
                              portraitOpacity+normalOpacity == 1 else {''')
s=s.replace('''[0,6,12,18,26,45,66,120,180,240,294,306,318,336,372,396,426,444,474,480,528]''','''[0,6,11,12,13,18,26,45,66,89,120,180,240,294,306,318,336,372,396,426,444,459,460,461,474,480,528]''')
# Render both full-blink states of the actual dedicated portrait, not merely
# the hidden normal-face closure diagnostics.
s=s.replace('''            a.render(edge); try capture(a,"laugh-with-full-blink")''','''            a.render(edge); try capture(a,"laugh-with-full-blink")
            edge.blink = 0; edge.friendBlink = 0
            a.render(edge); try capture(a,"laugh-with-open-blink")''')
p.write_text(s)
print('Separated opaque laugh portrait and aligned eye-line handoff; kept mouth, tears and wiping palm on final head transform.')
