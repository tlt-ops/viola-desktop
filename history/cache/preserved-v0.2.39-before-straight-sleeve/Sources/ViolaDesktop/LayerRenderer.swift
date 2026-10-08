import AppKit
import QuartzCore
import ViolaCore

protocol CharacterRenderer: AnyObject {
    var rootLayer: CALayer { get }
    var canvasSize: CGSize { get }
    func render(_ frame: AnimationFrame)
    func recoverableShoe(at point: CGPoint) -> ShoeSide?
    func canLaugh(at point: CGPoint) -> Bool
}
final class LayerRenderer: CharacterRenderer {
    let rootLayer = CALayer()
    let canvasSize: CGSize
    private var layers: [String: CALayer] = [:]
    private var definitions: [String: SpriteDefinition] = [:]
    private(set) var desksVisible = true
    private var bodyCompletion: ReferenceBodyCompletion?
    private var inspectionUpperBody: CALayer?
    private var restingPose: RestingPoseRig?
    private var deskSurface: DeskSurfaceRig?
    private var continuousFriendClothing = false
    private var supportBackings: [(id:String,layer:CALayer,frame:CGRect)] = []
    private var recoveryJoinErrors: [String:Double] = [:]
    private var friendCrawlRig: FriendCrawlRig?
    private let sourceReference: Bool
    private var sourceFace: SourceReferenceFaceRig?
    private var sourceArms: [String:SourceReferenceArmRig] = [:]
    private var sourceLaughWeight: Double = 0
    var sourceFaceDiagnostics: [String:Any] { sourceFace?.diagnostics ?? [:] }
    var sourceArmDiagnostics: [String:Any] {
        ["laughWeight":sourceLaughWeight,"desksVisible":desksVisible,
         "mouseGripRestored":definitions["mouse_grip_hand"] != nil,
         "mouseGripOpacity":layers["mouse_grip_hand"]?.opacity ?? 0,
         "emptyMouseHandOpacity":layers["mouse_hand"]?.opacity ?? 0,
         "arms":sourceArms.mapValues { $0.diagnostics }]
    }
    private var seatedHip: CGPoint { sourceReference ? CGPoint(x:330.56,y:564.96) : CGPoint(x:400,y:440) }
    private static let inspectionBodyIDs = ["inspection_left_arm","inspection_right_arm","inspection_left_hand","inspection_right_hand"]
    private static let deskOverlayIDs: Set<String> = [
        "desk_keyboard","desk_mouse","keyboard","reference_mouse","laugh_mouse","mouse_hand","mouse_grip_hand",
        "left_palm","left_pinky","left_ring","left_middle","left_index","left_thumb",
        "left_arm","left_arm_forearm","right_arm","right_arm_forearm",
        "reference_left_arm","reference_right_arm"
    ]
    func setDesksVisible(_ visible: Bool) {
        desksVisible = visible
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for id in Self.deskOverlayIDs { layers[id]?.isHidden = !visible }
        deskSurface?.root.isHidden = !visible
        bodyCompletion?.setInteractiveDeskMode(visible && deskSurface != nil)
        bodyCompletion?.setRestingPoseMode(!visible && restingPose != nil)
        restingPose?.root.isHidden = visible || sourceReference
        for (id,rig) in sourceArms { rig.root.isHidden = id.hasPrefix("resting_") ? visible : !visible }
        for id in Self.inspectionBodyIDs { layers[id]?.isHidden = visible || inspectionUpperBody != nil }
        inspectionUpperBody?.isHidden = visible
        layers["body"]?.isHidden = !visible && inspectionUpperBody != nil
        keyboardGlow.isHidden = !visible
        CATransaction.commit()
    }
    var deskVisibilityDiagnostics: [String:Any] {
        ["visible":desksVisible,"connectedSurface":deskSurface != nil,
         "surfaceOffset":deskSurface.map { [$0.root.position.x,$0.root.position.y] } ?? [],
         "restingPoseVisible":restingPose.map { !$0.root.isHidden } ?? false,
         "restingPose":restingPose?.diagnostics ?? [:],
         "overlays":Self.deskOverlayIDs.sorted().compactMap { id in layers[id].map { ["id":id,"hidden":$0.isHidden] as [String:Any] } },
         "inspectionBody":Self.inspectionBodyIDs.compactMap { id in layers[id].map { ["id":id,"hidden":$0.isHidden] as [String:Any] } }]
    }
    private struct LegStrip {
        let layer: CALayer
        let left: CGFloat; let right: CGFloat; let bottom: CGFloat; let top: CGFloat
        let toePatch: Bool
    }
    private var legStrips: [String:[LegStrip]] = [:]
    private var toeMotions: [String:ToeMicroMotion] = [:]
    var toeMotionDiagnostics: [String:Any] {
        var result: [String:Any] = [:]
        for (id,motion) in toeMotions {
            let vectors = motion.tipDisplacements
            result[motion.side] = [
                "enabled":motion.enabled,"time":motion.time,"amplitudeLimit":motion.amplitudeLimit,
                "maxTipDisplacement":vectors.map { hypot($0.x,$0.y) }.max() ?? 0,
                "patchCount":(legStrips[id] ?? []).filter { $0.toePatch }.count,
                "sourceSize":[motion.sourceSize.width,motion.sourceSize.height],
                "tips":motion.toes.enumerated().map { index,toe in
                    ["index":index,"rootSource":[toe.root.x,toe.root.y],
                     "tipSource":[toe.tip.x,toe.tip.y],"period":toe.period,
                     "displacement":[vectors[index].x,vectors[index].y]] as [String:Any]
                }
            ]
        }
        return result
    }
    private var thighTransforms: [String:CGAffineTransform] = [:]
    private struct SleevePatch { let layer: CALayer; let bottom: CGFloat; let top: CGFloat; let lowerRight: Bool }
    private var armStrips: [String:[SleevePatch]] = [:]
    private var leftArmPath: (shoulder: CGPoint, wrist: CGPoint)?
    private var projectedLegContacts: [String:CGPoint] = [:]
    private var projectedLegScales: [String:CGFloat] = [:]
    private var shoeRigs: [String:ShoeRig] = [:]
    private var clothRigs: [String:ClothRig] = [:]
    private let violaCloth = ClothMotion()
    private let friendCloth = ClothMotion(gain:0.7)
    private var referenceFriendExpressions: ReferenceFriendExpressions?
    private let keyboardGlow = CAShapeLayer()
    private var keyboardRenderer: KeyboardRenderer?
    private var leftOffset = CGPoint(x: 0, y: 36)
    private var wasLaughing = false
    private var mouseRest = CGPoint.zero
    private var parkedMouse = CGPoint.zero
    private var mouseReturnOffset = CGPoint.zero
    init(assets: CharacterAssets) {
        sourceReference = assets.manifest.rigProfile == "reference-v0.2.29"
        canvasSize = CGSize(width: assets.manifest.canvas[0], height: assets.manifest.canvas[1])
        rootLayer.bounds = CGRect(origin: .zero, size: canvasSize)
        rootLayer.anchorPoint = .zero; rootLayer.contentsScale = 2
        var renderImages = assets.images
        let seatingDefinition = assets.manifest.sprites.first { $0.id == "seating" }
        let friendSkirtDefinition = assets.manifest.sprites.first { $0.id == "friend_skirt" }
        continuousFriendClothing = sourceReference || (seatingDefinition?.file == "seating-reference-v0.2.16.png" &&
            friendSkirtDefinition?.file == seatingDefinition?.file && friendSkirtDefinition?.polygon != nil)
        if !sourceReference, continuousFriendClothing,
           assets.manifest.sprites.first(where: { $0.id == "leg_front" })?.file == "leg_front-toes-reference-v0.2.16.png",
           let front = assets.images["leg_front"], let seating = assets.images["seating"],
           let owned = ReferenceSpriteOwnership.split(front:front,seating:seating) {
            renderImages["leg_front"] = owned.front; renderImages["leg_front_thigh"] = owned.front
            renderImages["seating"] = owned.seating
        }
        if !sourceReference, assets.images["neck_bridge"] != nil {
            bodyCompletion = ReferenceBodyCompletion(canvasSize:canvasSize,patch:assets.images["completion_patch_source"],
                restingSource:assets.images["resting_fill_source"])
        }
        restingPose = RestingPoseRig(canvasSize:canvasSize,images:assets.images,
            definitions:Dictionary(uniqueKeysWithValues:assets.manifest.sprites.map { ($0.id,$0) }))
        if assets.manifest.sprites.contains(where: { $0.id == "desk_keyboard" && $0.mode == "connectedSurface" }),
           let source = assets.images["desk_keyboard"] {
            deskSurface = DeskSurfaceRig(canvasSize:canvasSize,source:source,
                offset:sourceReference ? CGPoint(x:-80,y:75) : .zero)
        }
        // Older external layouts may still list the retired shoe-assistance face.
        for sprite in assets.manifest.sprites where !sprite.id.hasPrefix("viola_amused_") {
            if sprite.id.hasPrefix("resting_") { continue }
            if ["reference_completion_source","completion_patch_source"].contains(sprite.id) { continue }
            if continuousFriendClothing && sprite.id == "friend_skirt" {
                // This polygon cuts through the middle of one connected garment,
                // not a free hem. Keep its pixels in the shared support texture.
                definitions[sprite.id] = sprite
                continue
            }
            if let surface = deskSurface, ["desk_keyboard","desk_mouse"].contains(sprite.id) {
                definitions[sprite.id] = sprite
                if sprite.id == "desk_keyboard" {
                    // Sleeves rest on the deeper tabletop even at the front of
                    // the mouse range; its rear edge must not cut through them.
                    if let arm = layers["left_arm"] ?? layers["reference_left_arm"] {
                        rootLayer.insertSublayer(surface.root,below:arm)
                    } else { rootLayer.addSublayer(surface.root) }
                }
                continue
            }
            let layer = CALayer()
            let originalImage = renderImages[sprite.id]
            let image = ["seating","viola_skirt"].contains(sprite.id) ?
                originalImage.map { bodyCompletion?.softeningCutEdge($0,frame:sprite.frame,upper:true,
                    discardAbove:sprite.id == "viola_skirt" ? 505 : nil) ?? $0 } : originalImage
            layer.contents = image; layer.contentsGravity = .resize; layer.contentsScale = 2
            let anchor = CGPoint(x: sprite.anchor?.first ?? 0.5, y: sprite.anchor?.last ?? 0.5)
            layer.anchorPoint = anchor
            layer.bounds = CGRect(origin: .zero, size: sprite.frame.size)
            layer.position = CGPoint(x: sprite.frame.minX + anchor.x * sprite.frame.width, y: sprite.frame.minY + anchor.y * sprite.frame.height)
            layer.transform = CATransform3DMakeRotation((sprite.rotationDegrees ?? 0)*Double.pi/180,0,0,1)
            if sprite.mirror == true {
                let content = CALayer(); content.contents = layer.contents; layer.contents = nil
                content.bounds = layer.bounds; content.position = CGPoint(x: layer.bounds.midX, y: layer.bounds.midY)
                content.transform = CATransform3DMakeScale(-1, 1, 1); content.contentsGravity = .resize; content.contentsScale = 2
                layer.addSublayer(content)
            }
            if let polygon = sprite.polygon {
                let mask = CAShapeLayer(), path = CGMutablePath()
                for (index, p) in polygon.enumerated() where p.count == 2 {
                    let point = CGPoint(x: (sprite.mirror == true ? 1-p[0] : p[0]) * sprite.frame.width, y: (1 - p[1]) * sprite.frame.height)
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                path.closeSubpath()
                for hole in sprite.cutouts ?? [] {
                    if continuousFriendClothing && sprite.id == "seating" && hole == friendSkirtDefinition?.polygon { continue }
                    for (index, p) in hole.enumerated() {
                        let point = CGPoint(x:p[0]*sprite.frame.width,y:(1-p[1])*sprite.frame.height)
                        if index == 0 { path.move(to:point) } else { path.addLine(to:point) }
                    }
                    path.closeSubpath()
                }
                mask.path = path; mask.fillRule = .evenOdd
                mask.fillColor = NSColor.white.cgColor
                if continuousFriendClothing && sprite.id == "seating" {
                    // Complementary antialiased cutouts otherwise leave a partial-
                    // alpha line even when both sleeves share the same transform.
                    mask.strokeColor = NSColor.white.cgColor; mask.lineWidth = 1.3
                }
                layer.mask = mask
            }
            if !sourceReference, continuousFriendClothing,
               ["viola_skirt","viola_thigh_skin","leg_back_thigh","leg_front_thigh"].contains(sprite.id), let image {
                // Retain the reference pixels behind an internal join. Breathing
                // and knee movement can reveal this small overlap without exposing
                // the desktop between two formerly adjacent texture boundaries.
                let backing = CALayer(); backing.contents = image; backing.contentsGravity = .resize
                backing.bounds = layer.bounds; backing.anchorPoint = .zero
                backing.position = sprite.frame.origin; backing.contentsScale = 2
                if let originalMask = layer.mask as? CAShapeLayer {
                    let mask = CAShapeLayer(); mask.path = originalMask.path
                    mask.fillRule = originalMask.fillRule; mask.fillColor = NSColor.white.cgColor
                    backing.mask = mask
                }
                rootLayer.insertSublayer(backing,at:0)
                supportBackings.append(("join_"+sprite.id,backing,sprite.frame))
            }
            if sprite.feather == true {
                let mask = CALayer(); mask.frame = layer.bounds
                mask.contents = Self.softFeatureMask(); layer.mask = mask
            }
            if ["leg_back","leg_front"].contains(sprite.id), let image {
                makeLegStrips(layer,image:image,definition:sprite)
            }
            if ["left_arm","left_arm_forearm"].contains(sprite.id), let image = assets.images[sprite.id] {
                makeArmStrips(layer,image:image,definition:sprite)
            }
            if !sourceReference, ["viola_skirt","friend_skirt"].contains(sprite.id), let image {
                clothRigs[sprite.id] = ClothRig(container:layer,image:image,definition:sprite)
            }
            rootLayer.addSublayer(layer); layers[sprite.id] = layer; definitions[sprite.id] = sprite
        }
        for (id,direction) in [("back",CGFloat(-1)),("front",CGFloat(1))] {
            if sourceReference { continue }
            if let rear = layers["shoe_"+id+"_rear"], let front = layers["shoe_"+id+"_front"] {
                // Restored toe textures retain the old pump opening contact;
                // scale its half-worn depth with the calibrated atlas height.
                let fitted = definitions["leg_"+id]?.file.contains("-toes-reference-") == true
                let fittingScale = fitted ? front.bounds.height/84 : 1
                shoeRigs[id] = ShoeRig(rear:rear,front:front,direction:direction,
                                      floorY:CGFloat(definitions["shoe_"+id+"_front"]?.floorY ?? 42),
                                      fittingOffset:CGPoint(x:0,y:-6*fittingScale))
            }
        }
        if !sourceReference, continuousFriendClothing, let lining = assets.images["friend_leg_underlay"] {
            // The original hidden-dress strip ended below the knee. Continue the
            // same existing lining behind the calf's swept area up to the hip.
            let frame = CGRect(x:510,y:150,width:57,height:295)
            let backing = CALayer(); backing.contents = lining; backing.contentsGravity = .resize
            backing.bounds = CGRect(origin:.zero,size:frame.size); backing.anchorPoint = .zero
            backing.position = frame.origin; backing.contentsScale = 2
            let path = CGMutablePath()
            for (index,p) in [(526.0,445.0),(541,445),(555,418),(567,350),(563,200),
                              (553,150),(524,150),(520,205),(518,320),(510,408)].enumerated() {
                let point = CGPoint(x:p.0-frame.minX,y:p.1-frame.minY)
                if index == 0 { path.move(to:point) } else { path.addLine(to:point) }
            }
            path.closeSubpath()
            let mask = CAShapeLayer(); mask.path = path; mask.fillColor = NSColor.white.cgColor
            backing.mask = mask; rootLayer.insertSublayer(backing,at:0)
            supportBackings.append(("friend_lining",backing,frame))
        }
        if !sourceReference, continuousFriendClothing, let texture = renderImages["seating"], let base = seatingDefinition?.frame {
            // Reuse the adjacent hair/shoulder pixels beneath the upper calf.
            // The original crop has no drawing where the resting leg occluded it.
            // Keep this overlap inside that occluded upper area; the natural open
            // space beside the friend's forearm remains transparent below it.
            let frame = base.offsetBy(dx:12,dy:0)
            let backing = CALayer(); backing.contents = texture; backing.contentsGravity = .resize
            backing.bounds = CGRect(origin:.zero,size:frame.size); backing.anchorPoint = .zero
            backing.position = frame.origin; backing.contentsScale = 2
            let path = CGMutablePath()
            for (index,p) in [(465.0,445.0),(515,445),(532,390),(540,345),(537,309),
                              (500,309),(493,335),(480,370),(470,400)].enumerated() {
                let point = CGPoint(x:p.0-frame.minX,y:p.1-frame.minY)
                if index == 0 { path.move(to:point) } else { path.addLine(to:point) }
            }
            path.closeSubpath()
            let mask = CAShapeLayer(); mask.path = path; mask.fillColor = NSColor.white.cgColor
            backing.mask = mask; rootLayer.insertSublayer(backing,at:0)
            supportBackings.append(("friend_shoulder_lining",backing,frame))
        }
        if let completion = bodyCompletion {
            rootLayer.insertSublayer(completion.crown,at:0)
            rootLayer.insertSublayer(completion.costume,at:1)
            if restingPose != nil, let body = layers["body"] {
                rootLayer.insertSublayer(completion.restingUnderlay,below:body)
            }
            if let source = assets.images["reference_completion_source"],
               let joined = ReferenceBodyJoin.make(source:source,images:assets.images,includeOriginalArms:restingPose == nil),
               let definition = definitions["body"], let original = layers["body"] {
                let layer = CALayer(); layer.contents = completion.softeningCutEdge(joined,frame:definition.frame,upper:false); layer.contentsGravity = .resize
                layer.anchorPoint = .zero; layer.bounds = CGRect(origin:.zero,size:definition.frame.size)
                layer.position = definition.frame.origin; layer.contentsScale = 2
                rootLayer.insertSublayer(layer,above:original); inspectionUpperBody = layer
            }
        }
        if let closedHead = layers["head_close"] {
            // Reuse only the generated closed eyelids. Replacing the complete head creates
            // a second hair silhouette and moves the neck/hair boundary during every blink.
            let mask = CALayer()
            mask.frame = closedHead.bounds
            mask.contents = Self.eyeMask(size: closedHead.bounds.size)
            closedHead.mask = mask
        }
        if let torso = layers["laugh_body"] {
            // Keep the original collar and hair at the shared head/torso seam.
            let mask = CAGradientLayer(); mask.frame = torso.bounds
            mask.colors = [NSColor.white.cgColor,NSColor.white.cgColor,NSColor.clear.cgColor]
            mask.locations = [0,0.88,1]
            mask.startPoint = CGPoint(x:0.5,y:0); mask.endPoint = CGPoint(x:0.5,y:1)
            torso.mask = mask
        }
        if let keyboard = layers["keyboard"] {
            let drawing = KeyboardRenderer(size: keyboard.bounds.size)
            drawing.root.position = CGPoint(x: keyboard.bounds.midX, y: keyboard.bounds.midY)
            keyboard.contents = nil; keyboard.addSublayer(drawing.root); keyboardRenderer = drawing
        }
        keyboardGlow.path = CGPath(roundedRect: CGRect(x: 158, y: 435, width: 204, height: 24), cornerWidth: 6, cornerHeight: 6, transform: nil)
        keyboardGlow.fillColor = NSColor(calibratedRed: 0.90, green: 0.82, blue: 0.54, alpha: 0.3).cgColor
        keyboardGlow.opacity = 0
        if let keyboard = layers["keyboard"] { rootLayer.insertSublayer(keyboardGlow, above: keyboard) }
        if definitions["reference_left_arm"] != nil { leftOffset = .zero }
        if !sourceReference, definitions["reference_blink_left"] != nil {
            let eyes = ReferenceFriendExpressions(canvasSize:canvasSize,
                closedEyes:assets.images["friend_reference_effort_eyes"])
            rootLayer.addSublayer(eyes.root)
            referenceFriendExpressions = eyes
        }
        if let pose = restingPose {
            if let fill = bodyCompletion?.restingFill { rootLayer.addSublayer(fill) }
            rootLayer.addSublayer(pose.root)
        }
        if sourceReference {
            for id in ["reference_left_arm","reference_right_arm","resting_pet_arm","resting_lap_arm"] {
                guard let image = assets.images[id],
                      let definition = assets.manifest.sprites.first(where: { $0.id == id }) else { continue }
                let left = id.contains("left") || id.contains("pet")
                let rig = SourceReferenceArmRig(image:image,definition:definition,
                    elbow:left ? CGPoint(x:244.16,y:625.12) : CGPoint(x:464.96,y:625.12))
                if let old = layers[id] { rootLayer.insertSublayer(rig.root,above:old); old.contents = nil }
                else { rootLayer.addSublayer(rig.root) }
                sourceArms[id] = rig
            }
            // Keycaps sit beneath the sleeve, palm and separately animated
            // fingers; the original manifest order covered the pressing hand.
            if let keyboard = layers["keyboard"], let sleeve = sourceArms["reference_left_arm"] {
                keyboard.removeFromSuperlayer(); rootLayer.insertSublayer(keyboard,below:sleeve.root)
                keyboardGlow.removeFromSuperlayer(); rootLayer.insertSublayer(keyboardGlow,above:keyboard)
            }
            // The grip's fingers must cover the mouse buttons. The supplied
            // reference originally put the mouse above the entire hand.
            if definitions["mouse_grip_hand"] != nil,
               let mouse = layers["reference_mouse"], let sleeve = sourceArms["reference_right_arm"] {
                mouse.removeFromSuperlayer(); rootLayer.insertSublayer(mouse,below:sleeve.root)
            }
            let face = SourceReferenceFaceRig(canvasSize:canvasSize,images:assets.images,definitions:definitions)
            rootLayer.addSublayer(face.root); sourceFace = face
        }
        if continuousFriendClothing { friendCrawlRig = FriendCrawlRig(layers:layers,definitions:definitions,sourceReference:sourceReference) }
        setDesksVisible(true)
        render(AnimationFrame())
    }
    func render(_ input: AnimationFrame) {
        var frame = input
        if sourceReference {
            // This supplied picture contains only fitted, stocking-covered heels.
            // Keep its actual pixels together until uncovered-foot art exists.
            frame.leftShoe = ShoeFrame(); frame.rightShoe = ShoeFrame()
        }
        // The seated hip and painted waist remain bound; the loose calves and
        // fitted shoes carry the small delayed response to each support step.
        frame.leftLegSwing += frame.crawl.riderBounce*0.04
        frame.rightLegSwing -= frame.crawl.riderBounce*0.032
        frame.leftLegSideSwing += frame.crawl.riderBounce*0.006
        frame.rightLegSideSwing += frame.crawl.riderBounce*0.005
        if sourceReference {
            // The supplied pose has no unseen clothing behind its calves.
            // Retain live motion while limiting how far those occlusions open.
            frame.leftLegSwing *= 0.45; frame.rightLegSwing *= 0.45
            frame.leftLegSideSwing *= 0.25; frame.rightLegSideSwing *= 0.25
        }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        recoveryJoinErrors = [:]
        let laughPose = frame.laugh > 0.12 && (sourceReference || (layers["laugh_body"] != nil && desksVisible))
        let legacyLaughPose = laughPose && !sourceReference
        let laughAmount = max(0,min(1,frame.laugh))
        sourceLaughWeight = laughAmount*laughAmount*(3-2*laughAmount)
        let support = supportTransform(frame)
        let movedHip = seatedHip.applying(support)
        let seatX = movedHip.x-seatedHip.x
        let seatY = movedHip.y-seatedHip.y
        let torsoY = frame.breath+frame.laughBounce+seatY
        for backing in supportBackings {
            backing.layer.position = backing.frame.origin.applying(support)
            backing.layer.setAffineTransform(CGAffineTransform(a:support.a,b:support.b,c:support.c,d:support.d,tx:0,ty:0))
        }
        if laughPose && !wasLaughing { parkedMouse = mouseRest }
        if !laughPose && wasLaughing { mouseReturnOffset = CGPoint(x:parkedMouse.x-frame.mouseX,y:parkedMouse.y-frame.mouseY+frame.mousePress*2.5) }
        let release = exp(-max(0,frame.renderInterval ?? frame.dt)*12)
        mouseReturnOffset.x *= release; mouseReturnOffset.y *= release
        layers["laugh_body"]?.opacity = laughPose ? 1 : 0
        pose("body",dx:seatX,dy:torsoY)
        pose("neck_bridge",dx:seatX,dy:torsoY)
        for id in Self.inspectionBodyIDs { pose(id,dx:seatX,dy:torsoY) }
        bodyCompletion?.render(seatX:seatX,torsoY:torsoY,support:support)
        restingPose?.render(dt:frame.renderInterval ?? frame.dt,reducedMotion:frame.reducedMotion,
            seatX:seatX,torsoY:torsoY,support:support)
        if let definition = definitions["body"] {
            inspectionUpperBody?.position = CGPoint(x:definition.frame.minX+seatX,y:definition.frame.minY+torsoY)
        }
        pose("laugh_body",dx:seatX,dy:torsoY)
        pose("head",dx:seatX,dy:torsoY)
        pose("head_close",dx:seatX,dy:torsoY)
        pose("laugh_mouth",dx:seatX,dy:torsoY)
        layers["laugh_mouth"]?.opacity = Float(frame.laugh)
        // Discrete eye sprites avoid briefly displaying both irises and closed lashes.
        layers["head_close"]?.opacity = frame.blink >= 0.55 || laughPose ? 1 : 0
        for id in ["seating","seating_repair","seating_floor_repair","friend_leg_underlay"] {
            pose(id); swaySupport(id,transform:support)
        }
        renderCloth(frame,seatX:seatX,torsoY:torsoY,support:support)
        // The retained thigh, skin, apron and torso meet at painted cut edges.
        // They must share the breathing displacement before knee motion is added.
        let legY = torsoY
        let backKnee = thighPose("back",shoe:frame.rightShoe,dx:seatX,dy:legY)
        let frontKnee = thighPose("front",shoe:frame.leftShoe,dx:seatX,dy:legY)
        let toeInterval = frame.renderInterval ?? frame.dt
        toeMotions["leg_back"]?.advance(dt:toeInterval,shoe:frame.rightShoe,reducedMotion:frame.reducedMotion)
        toeMotions["leg_front"]?.advance(dt:toeInterval,shoe:frame.leftShoe,reducedMotion:frame.reducedMotion)
        legPose("leg_back", dx:seatX+backKnee.x,dy:legY+backKnee.y, angle: frame.rightLegSwing, sideAngle: frame.rightLegSideSwing,
                recovery:shoeRigs["back"]?.recoveryTarget(frame.rightShoe))
        legPose("leg_front", dx:seatX+frontKnee.x,dy:legY+frontKnee.y, angle: frame.leftLegSwing, sideAngle: frame.leftLegSideSwing,
                recovery:shoeRigs["front"]?.recoveryTarget(frame.leftShoe))
        for (id,shoe,side) in [("back",frame.rightShoe,frame.rightLegSideSwing),("front",frame.leftShoe,frame.leftLegSideSwing)] {
            if let foot = projectedLegContacts["leg_"+id] {
                shoeRigs[id]?.render(shoe,foot:foot,footScale:projectedLegScales["leg_"+id] ?? 1,side:side,dt:frame.dt)
            }
        }
        for (id,shoe) in [("back",frame.rightShoe),("front",frame.leftShoe)] {
            for prefix in ["friend_rest_","friend_repair_","friend_shoulder_"] {
                pose(prefix+id); swaySupport(prefix+id,transform:support)
            }
            if let rest = spriteContact("friend_rest_"+id), let help = shoeRigs[id]?.helpHand(shoe,rest:rest) {
                helpArmPose(id,target:help.point,opacity:help.opacity,support:support)
            }
        }
        friendCrawlRig?.render(frame.crawl,support:support,baselineSupport:restingSupportTransform(frame))
        for (id, definition) in definitions where definition.expression != nil {
            pose(id); swaySupport(id,transform:support)
            if referenceFriendExpressions != nil && ReferenceFriendExpressions.retiredEyeIDs.contains(id) {
                layers[id]?.opacity = 0
            } else {
                layers[id]?.opacity = definition.expression == frame.friendExpression ? Float(frame.friendExpressionOpacity) : 0
            }
        }
        referenceFriendExpressions?.render(expression:frame.friendExpression,opacity:frame.friendExpressionOpacity,support:support)
        sourceFace?.render(blink:frame.blink, laugh:frame.laugh, expression:frame.friendExpression,
            opacity:frame.friendExpressionOpacity, seatX:seatX, torsoY:torsoY, support:support,
            friendBlink:frame.friendBlink,laughAge:frame.laughAge)
        pose("keyboard", dy: frame.keyboardY)
        let smoothing = 1 - exp(-max(0, frame.renderInterval ?? frame.dt) * 28)
        let referencePose = definitions["reference_left_arm"] != nil
        let leftTarget = aimOffset(referencePose ? frame.leftAim : (frame.leftAim ?? 3), rest: referencePose ? .zero : CGPoint(x: 0, y: 36), pressure: frame.keyPressures[frame.leftAim ?? 65535] ?? 0)
        leftOffset.x += (leftTarget.x-leftOffset.x) * smoothing; leftOffset.y += (leftTarget.y-leftOffset.y) * smoothing
        let leftY = leftOffset.y + (frame.leftAim == nil ? frame.leftHandY * 0.18 : 0)
        if referencePose && !sourceReference { referenceArmPose("reference_left_arm",shoulder:CGPoint(x:seatX,y:torsoY),hand:CGPoint(x:leftOffset.x,y:leftY)) }
        else if !sourceReference { armPose("left_arm", shoulderX:seatX, shoulderY: torsoY, handX: leftOffset.x, handY: leftY) }
        pose("left_palm", dx: leftOffset.x, dy: leftY)
        for (id, definition) in definitions where definition.finger?.isLeft == true {
            let finger = definition.finger!
            let offset = CGPoint(x: leftOffset.x,y:leftY)
            fingerPose(id, offset: offset, pressure: frame.fingerPressures[finger] ?? 0)
        }
        let mouseX = frame.mouseX+mouseReturnOffset.x
        let mouseY = frame.mouseY-frame.mousePress*2.5+mouseReturnOffset.y
        let gripShift = (definitions["mouse_hand"]?.frame.minX ?? 0) - (definitions["right_arm"]?.frame.minX ?? 0)
        let gripDepth = (definitions["mouse_hand"]?.frame.minY ?? 0) - (definitions["right_arm"]?.frame.minY ?? 0)
        if referencePose && !sourceReference { referenceArmPose("reference_right_arm",shoulder:CGPoint(x:seatX,y:torsoY),hand:CGPoint(x:mouseX,y:mouseY)) }
        else if !sourceReference { armPose("right_arm", shoulderX:seatX, shoulderY: torsoY, handX: mouseX + gripShift, handY: mouseY + gripDepth) }
        // Hand and mouse are one rigid sprite. Only the sleeve extends to meet the wrist.
        pose("mouse_hand", dx: mouseX, dy: mouseY)
        pose("reference_mouse",dx:mouseX,dy:mouseY)
        layers["reference_mouse"]?.opacity = sourceReference ? 1 : (laughPose ? 0 : 1)
        for id in ["reference_blink_left","reference_blink_right"] {
            pose(id,dx:seatX,dy:torsoY)
            layers[id]?.opacity = frame.blink >= 0.55 || laughPose ? 1 : 0
        }
        mouseRest = CGPoint(x:mouseX,y:mouseY)
        pose("laugh_mouse",dx:parkedMouse.x,dy:parkedMouse.y)
        layers["laugh_mouse"]?.opacity = laughPose ? 1 : 0
        for id in ["left_arm","left_arm_forearm","left_palm","right_arm","right_arm_forearm","mouse_hand","reference_left_arm","reference_right_arm"] {
            layers[id]?.opacity = legacyLaughPose ? 0 : 1
        }
        for (id,definition) in definitions where definition.finger != nil { layers[id]?.opacity = legacyLaughPose ? 0 : 1 }
        if sourceReference {
            renderSourceArms(frame,shoulder:CGPoint(x:seatX,y:torsoY),
                leftHandOffset:CGPoint(x:leftOffset.x,y:leftY),mouseOffset:CGPoint(x:mouseX,y:mouseY))
        }
        wasLaughing = laughPose
        keyboardGlow.opacity = frame.keyPressures.isEmpty ? Float(frame.keyGlow) : 0
        keyboardRenderer?.render(frame.keyPressures)
        CATransaction.commit()
    }
    private func renderSourceArms(_ frame: AnimationFrame, shoulder: CGPoint,
                                  leftHandOffset: CGPoint, mouseOffset: CGPoint) {
        let weight = sourceLaughWeight
        func blended(_ normal: CGPoint,_ belly: CGPoint) -> CGPoint {
            CGPoint(x:normal.x+(belly.x+shoulder.x-normal.x)*weight,
                    y:normal.y+(belly.y+shoulder.y-normal.y)*weight)
        }
        func anchor(_ id: String) -> CGPoint {
            guard let d = definitions[id] else { return .zero }
            let a = d.anchor ?? [0.5,0.5]
            return CGPoint(x:d.frame.minX+a[0]*d.frame.width,y:d.frame.minY+a[1]*d.frame.height)
        }
        let restoredGrip = definitions["mouse_grip_hand"] != nil
        let leftAnchor = anchor("left_palm")
        let rightAnchor = anchor(restoredGrip ? "mouse_grip_hand" : "mouse_hand")
        let leftRest = CGPoint(x:242.24+shoulder.x,y:579.68+shoulder.y)
        let rightRest = CGPoint(x:416.96+shoulder.x,y:577.12+shoulder.y)
        let leftDesk = CGPoint(x:leftAnchor.x+leftHandOffset.x,y:leftAnchor.y+leftHandOffset.y)
        let rightDesk = CGPoint(x:rightAnchor.x+mouseOffset.x,y:rightAnchor.y+mouseOffset.y)
        let leftTarget = blended(desksVisible ? leftDesk : leftRest,CGPoint(x:317,y:648))
        let rightTarget = blended(desksVisible ? rightDesk : rightRest,CGPoint(x:405,y:643))
        let leftAngle = pow(weight,5)*0.8
        let leftID = desksVisible ? "reference_left_arm" : "resting_pet_arm"
        let rightID = desksVisible ? "reference_right_arm" : "resting_lap_arm"
        let left = sourceArms[leftID]?.render(shoulderOffset:shoulder,target:leftTarget,handAngle:leftAngle)
        // The original resting cuff points diagonally down-left; the retained
        // desktop grip points down. Rotate the sleeve's cuff into that axis,
        // keeping the grip's own painted fingers upright over the mouse.
        let gripCuffAngle = restoredGrip && desksVisible ? Double.pi/4 : 0
        let rightCuffAngle = gripCuffAngle*(1-weight)-weight*0.30
        let right = sourceArms[rightID]?.render(shoulderOffset:shoulder,target:rightTarget,handAngle:rightCuffAngle,
            wristAlignment:desksVisible ? 1-weight : 0)
        guard desksVisible else { return }
        func hand(_ id: String, sourceAnchor: CGPoint, result: SourceReferenceArmRig.Result?, angle: Double, pressure: Double = 0) {
            guard let result, let layer = layers[id], let definition = definitions[id] else { return }
            let a = definition.anchor ?? [0.5,0.5]
            let old = CGPoint(x:definition.frame.minX+a[0]*definition.frame.width,
                              y:definition.frame.minY+a[1]*definition.frame.height)
            let c = cos(angle), s = sin(angle)
            let d = CGPoint(x:old.x-sourceAnchor.x,y:old.y-sourceAnchor.y)
            layer.position = CGPoint(x:result.wrist.x+c*d.x-s*d.y,y:result.wrist.y+s*d.x+c*d.y)
            let flex = definition.finger == nil ? 1 : fingerDepthScale(definition,pressure:pressure*(1-weight))
            layer.setAffineTransform(CGAffineTransform(a:c,b:s,c:-s*flex,d:c*flex,tx:0,ty:0))
        }
        hand("left_palm",sourceAnchor:leftAnchor,result:left,angle:leftAngle)
        for (id,d) in definitions where d.finger?.isLeft == true {
            hand(id,sourceAnchor:leftAnchor,result:left,angle:leftAngle,pressure:frame.fingerPressures[d.finger!] ?? 0)
        }
        if restoredGrip {
            // This extraction contains only the hand, so the same fingers can
            // leave the stationary mouse and hold the belly. Keep one opaque
            // hand throughout instead of crossfading two different outlines.
            hand("mouse_grip_hand",sourceAnchor:rightAnchor,result:right,angle:rightCuffAngle-gripCuffAngle)
            layers["mouse_grip_hand"]?.opacity = 1
            layers["mouse_hand"]?.opacity = 0
        } else {
            hand("mouse_hand",sourceAnchor:rightAnchor,result:right,angle:-weight*0.30)
        }
    }
    private func referenceArmPose(_ id: String, shoulder: CGPoint, hand: CGPoint) {
        guard let layer = layers[id], let sprite = definitions[id], let wrist = sprite.contact else { return }
        let a = layer.anchorPoint
        let v = CGPoint(x:(wrist[0]-a.x)*sprite.frame.width,y:(wrist[1]-a.y)*sprite.frame.height)
        let distance = max(1,v.x*v.x+v.y*v.y)
        let d = CGPoint(x:hand.x-shoulder.x,y:hand.y-shoulder.y)
        layer.position = CGPoint(x:sprite.frame.minX+a.x*sprite.frame.width+shoulder.x,
                                 y:sprite.frame.minY+a.y*sprite.frame.height+shoulder.y)
        // Identity at rest; distribute wrist travel along the original diagonal sleeve.
        layer.setAffineTransform(CGAffineTransform(a:1+d.x*v.x/distance,b:d.y*v.x/distance,
            c:d.x*v.y/distance,d:1+d.y*v.y/distance,tx:0,ty:0))
    }
    private func aimOffset(_ code: UInt16?, rest: CGPoint, pressure: Double) -> CGPoint {
        guard let code, let key = KeyboardLayout.byCode[code], let keyboard = keyboardRenderer,
              let sprite = definitions.first(where: { $0.value.finger == key.finger })?.value,
              let contact = sprite.contact else { return rest }
        let anchorY = sprite.anchor?.last ?? 0.5
        let flex = fingerDepthScale(sprite,pressure:pressure)
        let tip = CGPoint(x: sprite.frame.minX + contact[0]*sprite.frame.width,
                          y: sprite.frame.minY + (anchorY+(contact[1]-anchorY)*flex)*sprite.frame.height)
        let near = keyboard.root.convert(CGPoint(x: tip.x+rest.x,y:tip.y+rest.y), from: rootLayer)
        guard let local = keyboard.keyContact(code, near: near, pressure: pressure) else { return rest }
        let target = keyboard.root.convert(local, to: rootLayer)
        // Layout bounds already constrain the target. Clamping the displacement can make
        // an edge key light up while the fingertip stops short of that actual key.
        return CGPoint(x: target.x-tip.x, y: target.y-tip.y)
    }
    private func renderCloth(_ frame: AnimationFrame, seatX: Double, torsoY: Double, support: CGAffineTransform) {
        if sourceReference {
            // Keep the apron and waist attached with the exact source silhouette.
            pose("viola_skirt",dx:seatX,dy:torsoY)
            pose("viola_thigh_skin",dx:seatX,dy:torsoY)
            return
        }
        // The reference's exposed side of the thigh stays solid beneath the drape.
        pose("viola_thigh_skin",dx:seatX,dy:torsoY)
        let hook = [frame.leftShoe,frame.rightShoe].reduce(0.0) { amount,shoe in
            guard shoe.phase == .recovering, shoe.recovery == .toeHook else { return amount }
            let pose = shoe.toeHookPose
            return max(amount,pose.reach*(0.25+pose.straighten*0.45+pose.forward*0.3))
        }
        if let rig = clothRigs["viola_skirt"] {
            pose("viola_skirt",dx:seatX,dy:torsoY)
            let drive = ClothDrive(baseX:seatX,baseY:torsoY,
                legSwing:frame.leftLegSwing*0.55+frame.rightLegSwing*0.45,
                legSideSwing:frame.leftLegSideSwing*0.55+frame.rightLegSideSwing*0.45,stretch:hook)
            rig.render(violaCloth.tick(dt:frame.dt,drive:drive,reducedMotion:frame.reducedMotion))
        }
        if let rig = clothRigs["friend_skirt"], let definition = definitions["friend_skirt"] {
            pose("friend_skirt"); swaySupport("friend_skirt",transform:support)
            let anchor = CGPoint(x:definition.frame.midX,y:definition.frame.minY+rig.attachmentY)
            let attachment = anchor.applying(support)
            let drive = ClothDrive(baseX:attachment.x-anchor.x,baseY:attachment.y-anchor.y,
                baseAngle:frame.supportSway+frame.friendTrembleX/340,
                legSideSwing:frame.supportSway*0.8)
            rig.render(friendCloth.tick(dt:frame.dt,drive:drive,reducedMotion:frame.reducedMotion))
        }
    }
    private func fingerDepthScale(_ definition: SpriteDefinition, pressure: Double) -> Double {
        // Foreshorten the already curved finger slightly as it curls down. The
        // previous stretch lengthened each digit during a press and looked rubbery.
        1 - (definition.finger == .leftThumb ? 0.035 : 0.065)*max(0,min(1,pressure))
    }
    private func fingerPose(_ id: String, offset: CGPoint, pressure: Double) {
        guard let layer = layers[id], let definition = definitions[id], definition.contact != nil else { return }
        let anchor = layer.anchorPoint
        layer.position = CGPoint(x: definition.frame.minX+anchor.x*definition.frame.width+offset.x,
                                 y: definition.frame.minY+anchor.y*definition.frame.height+offset.y)
        // Knuckle stays attached to the rigid palm; aimOffset uses this same
        // projected fingertip so the pressed key and the final contact agree.
        layer.setAffineTransform(CGAffineTransform(a: 1,b: 0,c: 0,
            d:fingerDepthScale(definition,pressure:pressure),tx: 0,ty: 0))
    }
    private func pose(_ id: String, dx: Double = 0, dy: Double = 0, angle: Double = 0) {
        guard let layer = layers[id], let definition = definitions[id] else { return }
        let anchor = layer.anchorPoint
        layer.position = CGPoint(x: definition.frame.minX + anchor.x * definition.frame.width + dx, y: definition.frame.minY + anchor.y * definition.frame.height + dy)
        layer.transform = CATransform3DMakeRotation(angle + (definition.rotationDegrees ?? 0)*Double.pi/180, 0, 0, 1)
    }
    private func thighPose(_ side: String, shoe: ShoeFrame, dx: Double, dy: Double) -> CGPoint {
        let id = "leg_"+side+"_thigh"
        thighTransforms["leg_"+side] = .identity
        pose(id,dx:dx,dy:dy)
        guard let thigh = layers[id],let definition = definitions[id],let calf = definitions["leg_"+side] else { return .zero }
        guard shoe.phase == .recovering,shoe.recovery == .toeHook else { return .zero }
        let motion = shoe.toeHookPose
        let extensionAmount = CGFloat(motion.straighten),depth = CGFloat(motion.forward)
        let angle: CGFloat = (side == "back" ? 0.18 : 0.10)*extensionAmount
        let scale: CGFloat = 1+0.05*depth
        // Reveal a little of the existing thigh by opening it around its hip.
        // Retain the normal layer order so the supporting girl's face stays clear.
        thigh.setAffineTransform(CGAffineTransform(rotationAngle:angle).scaledBy(x:scale,y:scale))
        thighTransforms["leg_"+side] = thigh.affineTransform()
        if side == "front", let skin = layers["viola_thigh_skin"] {
            let transform = thigh.affineTransform()
            let relative = CGPoint(x:skin.position.x-thigh.position.x,y:skin.position.y-thigh.position.y).applying(transform)
            skin.position = CGPoint(x:thigh.position.x+relative.x,y:thigh.position.y+relative.y)
            skin.setAffineTransform(transform)
        }
        // The seam backing may stay at the seated join during breathing, but it
        // must follow the same upper-leg extension during toe-hook recovery.
        // Otherwise a complete old thigh silhouette remains behind the knee.
        for part in [id] + (side == "front" ? ["viola_thigh_skin"] : []) {
            guard let foreground = layers[part],
                  let backing = supportBackings.first(where: { $0.id == "join_"+part }) else { continue }
            backing.layer.position = foreground.convert(.zero,to:rootLayer)
            backing.layer.setAffineTransform(foreground.affineTransform())
            let size = foreground.bounds.size
            recoveryJoinErrors[part] = [CGPoint.zero,CGPoint(x:size.width,y:0),
                CGPoint(x:size.width,y:size.height),CGPoint(x:0,y:size.height)].map { point in
                    let a = foreground.convert(point,to:rootLayer), b = backing.layer.convert(point,to:rootLayer)
                    return hypot(a.x-b.x,a.y-b.y)
                }.max() ?? 0
        }
        let hip = CGPoint(x:definition.frame.minX+thigh.anchorPoint.x*definition.frame.width,
                          y:definition.frame.minY+thigh.anchorPoint.y*definition.frame.height)
        let knee = CGPoint(x:calf.frame.minX+CGFloat(calf.anchor?.first ?? 0.5)*calf.frame.width,
                           y:calf.frame.minY+CGFloat(calf.anchor?.last ?? 0.5)*calf.frame.height)
        let relative = CGPoint(x:knee.x-hip.x,y:knee.y-hip.y)
        // Carry the calf's fixed knee through exactly the same hip transform.
        return CGPoint(x:(relative.x*cos(angle)-relative.y*sin(angle))*scale-relative.x,
                       y:(relative.x*sin(angle)+relative.y*cos(angle))*scale-relative.y)
    }
    private func makeLegStrips(_ container: CALayer, image: CGImage, definition: SpriteDefinition) {
        // A shallow 2D strip mesh shares the same perspective in native rendering and
        // PNG exports; CALayer.render(in:) omits non-affine layer transforms.
        let first = Int(floor((definition.polygon?.map { $0[1] }.min() ?? 0)*Double(image.height)))
        let rows = image.height-first, count = 48
        guard rows >= count else { return }
        let motion = definition.file.contains("-toes-reference-") ?
            ToeMicroMotion(side:definition.id == "leg_front" ? "front" : "back",
                           sourceSize:CGSize(width:image.width,height:image.height),canvasSize:definition.frame.size) : nil
        let coarseEnd = motion?.meshSourceY ?? image.height
        if let motion { toeMotions[definition.id] = motion }
        container.contents = nil; container.mask = nil
        var strips: [LegStrip] = []
        func appendPatch(left: Int, right: Int, start: Int, end: Int, toePatch: Bool) {
            guard let part = image.cropping(to:CGRect(x:left,y:start,width:right-left,height:end-start)) else { return }
            // Inspect alpha only while building the persistent texture mesh.
            // Transparent cells never become layers or consume per-frame work.
            if toePatch && !Self.containsOpaquePixel(part) { return }
            let localLeft = CGFloat(left)/CGFloat(image.width)*definition.frame.width
            let localRight = CGFloat(right)/CGFloat(image.width)*definition.frame.width
            let bottom = CGFloat(image.height-end)/CGFloat(image.height)*definition.frame.height
            let top = CGFloat(image.height-start)/CGFloat(image.height)*definition.frame.height
            let strip = CALayer(); strip.contents = part; strip.contentsGravity = .resize; strip.contentsScale = 2
            strip.bounds = CGRect(x:0,y:0,width:localRight-localLeft,height:top-bottom)
            strip.position = CGPoint(x:(localLeft+localRight)/2,y:(top+bottom)/2)
            container.addSublayer(strip)
            strips.append(LegStrip(layer:strip,left:localLeft,right:localRight,bottom:bottom,top:top,toePatch:toePatch))
        }
        for index in 0..<count {
            // Two source pixels of overlap absorb texture-edge filtering during flexion.
            let start = max(first,first+(coarseEnd-first)*index/count-2)
            let end = min(image.height,coarseEnd+1,first+(coarseEnd-first)*(index+1)/count+2)
            appendPatch(left:0,right:image.width,start:start,end:end,toePatch:false)
        }
        if motion != nil {
            // Four source pixels per cell resolve individual toe lobes. A one
            // pixel overlap absorbs affine approximation/filtering at the edges.
            for y in stride(from:coarseEnd,to:image.height,by:4) {
                for x in stride(from:0,to:image.width,by:4) {
                    appendPatch(left:max(0,x-1),right:min(image.width,x+5),
                                start:max(coarseEnd,y-1),end:min(image.height,y+5),toePatch:true)
                }
            }
        }
        legStrips[definition.id] = strips
    }
    private static func containsOpaquePixel(_ image: CGImage) -> Bool {
        var rgba = [UInt8](repeating:0,count:image.width*image.height*4)
        return rgba.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data:bytes.baseAddress,width:image.width,height:image.height,
                bitsPerComponent:8,bytesPerRow:image.width*4,space:CGColorSpaceCreateDeviceRGB(),
                bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return true }
            context.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height))
            for index in stride(from:3,to:bytes.count,by:4) where bytes[index] > 0 { return true }
            return false
        }
    }
    private func legPose(_ id: String, dx: Double = 0, dy: Double, angle: Double, sideAngle: Double, recovery: LegRecoveryTarget? = nil) {
        guard let layer = layers[id], let definition = definitions[id] else { return }
        let anchor = layer.anchorPoint
        layer.position = CGPoint(x:definition.frame.minX+anchor.x*definition.frame.width+dx,
                                 y:definition.frame.minY+anchor.y*definition.frame.height+dy)
        let straightening = Double((recovery?.straighten ?? 0)*(recovery?.blend ?? 0))
        let flexion = max(-0.88,min(0.88,angle*(definition.swingMultiplier ?? 1)))*(1-straightening)
        let side = max(-0.18,min(0.18,sideAngle*(definition.sideSwingMultiplier ?? 1)))*(1-straightening)
        // The calf inherits the hip extension before adding its own knee swing.
        layer.setAffineTransform((thighTransforms[id] ?? .identity).rotated(by:side))
        let pivot = CGPoint(x:anchor.x*definition.frame.width,y:anchor.y*definition.frame.height)
        let sine = CGFloat(sin(flexion)), cosine = CGFloat(cos(flexion))
        let distance = CGFloat(definition.perspectiveDistance ?? 760)
        func projected(_ y: CGFloat) -> (scale: CGFloat, y: CGFloat) {
            let relative = y-pivot.y, scale = 1/(1-relative*sine/distance)
            return (scale,pivot.y+relative*cosine*scale)
        }
        let footY = CGFloat(definition.contact?.last ?? 0)*definition.frame.height
        let footProjection = projected(footY)
        let footLocal = CGPoint(x:pivot.x+(CGFloat(definition.contact?.first ?? 0.5)*definition.frame.width-pivot.x)*footProjection.scale,y:footProjection.y)
        var recoveryShift = CGPoint.zero
        var depthScale: CGFloat = 1
        if let recovery {
            var target = layer.convert(recovery.point,from:rootLayer)
            // After insertion and toe lift, straighten below the fixed knee.
            // Forward travel includes depth enlargement and foreshortening, so
            // the movement reads toward the viewer as well as across the canvas.
            let straightX = pivot.x+(footLocal.x-pivot.x)*0.55
            target.x += (straightX-target.x)*recovery.straighten+recovery.direction*9*recovery.forward
            target.y += (footLocal.y-target.y)*recovery.straighten+18*recovery.forward
            recoveryShift = CGPoint(x:(target.x-footLocal.x)*recovery.blend,y:(target.y-footLocal.y)*recovery.blend)
            depthScale = 1+(recovery.scale/max(0.01,footProjection.scale)-1)*recovery.blend
        }
        func reachWeight(_ y: CGFloat) -> CGFloat { max(0,min(1.12,(pivot.y-y)/max(1,pivot.y-footProjection.y))) }
        let sourceCenterX = definition.frame.width/2
        let sourceContactX = CGFloat(definition.contact?.first ?? 0.5)*definition.frame.width
        func depthCenterShift(_ projection: (scale: CGFloat, y: CGFloat)) -> CGFloat {
            // Enlarge the forefoot around its actual insertion point. Scaling
            // each row around the full crop center moves the visible toes away
            // from the independent shoe while diagnostics retain the old point.
            (sourceCenterX-sourceContactX)*projection.scale*(depthScale-1)*min(1,reachWeight(projection.y))
        }
        func mappedToePoint(_ point: CGPoint) -> CGPoint {
            var deformed = point
            if let motion = toeMotions[id] {
                let source = CGPoint(x:point.x/definition.frame.width*motion.sourceSize.width,
                                     y:(1-point.y/definition.frame.height)*motion.sourceSize.height)
                let displacement = motion.displacement(at:source)
                deformed.x += displacement.x; deformed.y += displacement.y
            }
            let projection = projected(deformed.y), weight = reachWeight(projection.y)
            let projectedX = pivot.x+(deformed.x-pivot.x)*projection.scale+recoveryShift.x*weight
            let depthX = (deformed.x-sourceContactX)*projection.scale*(depthScale-1)*min(1,weight)
            return CGPoint(x:projectedX+depthX,y:projection.y+recoveryShift.y*weight)
        }
        for strip in legStrips[id] ?? [] {
            if strip.toePatch {
                let center = CGPoint(x:(strip.left+strip.right)/2,y:(strip.bottom+strip.top)/2)
                let left = mappedToePoint(CGPoint(x:strip.left,y:center.y))
                let right = mappedToePoint(CGPoint(x:strip.right,y:center.y))
                let bottom = mappedToePoint(CGPoint(x:center.x,y:strip.bottom))
                let top = mappedToePoint(CGPoint(x:center.x,y:strip.top))
                strip.layer.position = mappedToePoint(center)
                // The affine Jacobian comes from the same continuous field on
                // both sides of every cell; no individual toe is a loose layer.
                strip.layer.setAffineTransform(CGAffineTransform(
                    a:(right.x-left.x)/(strip.right-strip.left),
                    b:(right.y-left.y)/(strip.right-strip.left),
                    c:(top.x-bottom.x)/(strip.top-strip.bottom),
                    d:(top.y-bottom.y)/(strip.top-strip.bottom),tx:0,ty:0))
                continue
            }
            let bottom = projected(strip.bottom), top = projected(strip.top)
            let middle = projected((strip.bottom+strip.top)/2)
            let weight = reachWeight(middle.y)
            let widthScale = middle.scale*(1+(depthScale-1)*min(1,weight))
            let bottomX = pivot.x+(sourceCenterX-pivot.x)*bottom.scale+recoveryShift.x*reachWeight(bottom.y)+depthCenterShift(bottom)
            let topX = pivot.x+(sourceCenterX-pivot.x)*top.scale+recoveryShift.x*reachWeight(top.y)+depthCenterShift(top)
            let bottomY = bottom.y+recoveryShift.y*reachWeight(bottom.y)
            let topY = top.y+recoveryShift.y*reachWeight(top.y)
            strip.layer.position = CGPoint(x:(bottomX+topX)/2,y:(bottomY+topY)/2)
            // Follow the same edge at each end of a strip while the toe reaches.
            // A translation per row leaves staircase edges in the ankle silhouette.
            strip.layer.setAffineTransform(CGAffineTransform(a:widthScale,b:0,c:(topX-bottomX)/(strip.top-strip.bottom),
                d:(topY-bottomY)/(strip.top-strip.bottom),tx:0,ty:0))
        }
        if let contact = definition.contact {
            let foot = projected(contact[1]*definition.frame.height)
            let local = CGPoint(x:pivot.x+(contact[0]*definition.frame.width-pivot.x)*foot.scale,y:foot.y)
            projectedLegContacts[id] = layer.convert(CGPoint(x:local.x+recoveryShift.x,y:local.y+recoveryShift.y),to:rootLayer)
            projectedLegScales[id] = foot.scale*depthScale
        }
    }
    func recoverableShoe(at point: CGPoint) -> ShoeSide? {
        if shoeRigs["front"]?.containsGroundedShoe(point,in:rootLayer) == true { return .left }
        if shoeRigs["back"]?.containsGroundedShoe(point,in:rootLayer) == true { return .right }
        return nil
    }
    func canLaugh(at point: CGPoint) -> Bool {
        // Exclude the keyboard, mouse, friend, and shoes from the laughter target.
        if desksVisible, deskSurface?.contains(point) == true { return false }
        for id in ["keyboard", "desk_keyboard", "desk_mouse", "reference_mouse", "laugh_mouse"] {
            if let device = layers[id], !device.isHidden, device.opacity > 0,
               device.bounds.contains(device.convert(point, from: rootLayer)) { return false }
        }
        if sourceReference {
            return CGRect(x:254,y:756,width:140,height:115).contains(point) ||
                CGRect(x:275,y:610,width:130,height:140).contains(point)
        }
        guard let head = layers["head"] else { return false }
        let local = head.convert(point,from:rootLayer)
        if definitions["reference_blink_left"] != nil {
            let b = head.bounds
            return CGRect(x:b.width*0.18,y:b.height*0.05,width:b.width*0.65,height:b.height*0.6).contains(local)
                || definitions["body"]?.frame.insetBy(dx:20,dy:20).contains(point) == true
        }
        let face = CGRect(x:95,y:8,width:200,height:215)
        return face.contains(local) || CGRect(x:290,y:500,width:200,height:130).contains(point)
    }
    private func supportTransform(_ frame: AnimationFrame) -> CGAffineTransform {
        let resting = restingSupportTransform(frame)
        guard frame.crawl.weight > 0 else { return resting }
        let angle = frame.crawl.bodyRoll, c = cos(angle), s = sin(angle)
        // One world map carries the support's torso, crown, face, sleeves and
        // seam backings. The rider is carried at the same seated hip point.
        let hip = seatedHip
        let crawl = CGAffineTransform(a:c,b:s,c:-s,d:c,
            tx:hip.x-c*hip.x+s*hip.y+frame.crawl.bodyX,
            ty:hip.y-s*hip.x-c*hip.y+frame.crawl.bodyY)
        return resting.concatenating(crawl)
    }
    private func restingSupportTransform(_ frame: AnimationFrame) -> CGAffineTransform {
        // The art's palms touch a slightly sloped ground line. This world-space
        // affine map fixes every point on that line, including both palms, while
        // the torso, hair, face patches and resting sleeves deform together.
        func contact(_ id: String) -> CGPoint? {
            guard let d = definitions[id], let p = d.contact else { return nil }
            return CGPoint(x:d.frame.minX+p[0]*d.frame.width,y:d.frame.minY+p[1]*d.frame.height)
        }
        let back = contact("friend_rest_back") ?? CGPoint(x:230,y:100)
        let front = contact("friend_rest_front") ?? CGPoint(x:365,y:100)
        let slope = abs(front.x-back.x) > 1 ? (front.y-back.y)/(front.x-back.x) : 0
        let intercept = back.y-slope*back.x
        let shear = frame.supportSway+frame.friendTrembleX/340
        let vertical = (frame.friendBreath+frame.friendTrembleY+frame.supportDip)/340
        return CGAffineTransform(a:1-slope*shear,b:-slope*vertical,c:shear,d:1+vertical,
                                 tx:-intercept*shear,ty:-intercept*vertical)
    }
    private func swaySupport(_ id: String, transform: CGAffineTransform) {
        guard let layer = layers[id] else { return }
        layer.position = layer.position.applying(transform)
        let linear = CGAffineTransform(a:transform.a,b:transform.b,c:transform.c,d:transform.d,tx:0,ty:0)
        layer.setAffineTransform(layer.affineTransform().concatenating(linear))
    }
    var shoeDiagnostics: [String:Any] { shoeRigs.mapValues { $0.diagnostic } }
    var clothDiagnostics: [String:Any] { clothRigs.mapValues { $0.diagnostic } }
    var crawlDiagnostics: [String:Any] { friendCrawlRig?.diagnostics ?? ["available":false] }
    var motionSeamDiagnostics: [String:Any] {
        func geometry(_ id: String) -> [Double] {
            guard let layer = layers[id] else { return [] }
            let b = layer.bounds
            return [CGPoint(x:0,y:0),CGPoint(x:b.width,y:0),CGPoint(x:b.width,y:b.height),CGPoint(x:0,y:b.height)]
                .flatMap { point -> [Double] in
                    let p = layer.convert(point,to:rootLayer); return [p.x,p.y]
                }
        }
        let friendIDs = definitions.keys.filter { $0.hasPrefix("friend_") || $0 == "seating" }.sorted()
        var friend: [String:Any] = Dictionary(uniqueKeysWithValues:friendIDs.map { ($0,geometry($0) as Any) })
        friend["cloth"] = clothRigs["friend_skirt"]?.diagnostic ?? [:]
        friend["continuousClothing"] = continuousFriendClothing
        for backing in supportBackings where backing.id.hasPrefix("friend_") {
            let layer = backing.layer, t = layer.affineTransform()
            friend[backing.id] = [layer.position.x,layer.position.y,t.a,t.b,t.c,t.d]
        }
        var attachment: [String:Any] = [:]
        if let body = layers["body"], let bd = definitions["body"] {
            let dy = body.position.y-bd.frame.minY-body.anchorPoint.y*bd.frame.height
            for id in ["leg_front_thigh","leg_back_thigh"] {
                if let layer = layers[id], let d = definitions[id] {
                    attachment[id] = layer.position.y-d.frame.minY-layer.anchorPoint.y*d.frame.height-dy
                }
            }
        }
        return ["friend":friend,"breathingAttachmentDeltaY":attachment,"cloth":clothDiagnostics,
                "rigProfile":sourceReference ? "reference-v0.2.29" : "legacy",
                "shoeArtPolicy":sourceReference ? "source heels remain attached; uncovered foot not supplied" : "independent shoe recovery",
                "recoveryBackingCornerError":recoveryJoinErrors,
                "desks":deskVisibilityDiagnostics,"toes":toeMotionDiagnostics,"crawl":crawlDiagnostics,
                "sourceArms":sourceArmDiagnostics]
    }
    func saveFriendSupportPNG(to url: URL) throws {
        let kept = Set(layers.filter { $0.key.hasPrefix("friend_") || $0.key == "seating" }.values.map(ObjectIdentifier.init) +
            supportBackings.filter { $0.id.hasPrefix("friend_") }.map { ObjectIdentifier($0.layer) })
        let children = rootLayer.sublayers ?? [], hidden = children.map(\.isHidden)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for child in children {
            child.isHidden = child.isHidden || !(kept.contains(ObjectIdentifier(child)) || child === bodyCompletion?.crown || child === referenceFriendExpressions?.root)
        }
        defer {
            for (child,value) in zip(children,hidden) { child.isHidden = value }
            CATransaction.commit()
        }
        try savePNG(to:url)
    }
    func saveCompletionInput(to url: URL) throws {
        bodyCompletion?.costume.isHidden = true; bodyCompletion?.crown.isHidden = true
        setDesksVisible(false); render(AnimationFrame())
        try savePNG(to:url,background:NSColor.white,region:CGRect(x:260,y:440,width:390,height:180),scale:2)
        bodyCompletion?.costume.isHidden = false; bodyCompletion?.crown.isHidden = false
    }
    var friendMotionDiagnostics: [String:Any] {
        var points: [String:Any] = [:]
        for id in ["friend_rest_back","friend_rest_front","friend_help_back_palm","friend_help_front_palm","leg_back","leg_front"] {
            if let contact = spriteContact(id) { points[id] = [contact.x,contact.y] }
        }
        for id in ["seating","friend_hearts_eye_l","friend_hearts_eye_r","friend_effort_mouth"] {
            if let layer = layers[id] { points[id+"Center"] = [layer.position.x,layer.position.y] }
        }
        return points
    }
    private func helpArmPose(_ id: String, target: CGPoint, opacity: Float, support: CGAffineTransform) {
        let prefix = "friend_help_"+id
        guard let sleeve = layers[prefix+"_sleeve"], let upper = definitions[prefix+"_sleeve"],
              let palm = layers[prefix+"_palm"], let hand = definitions[prefix+"_palm"],
              let wrist = upper.contact, let cup = hand.contact else { return }
        sleeve.opacity = opacity; palm.opacity = opacity; layers["friend_rest_"+id]?.opacity = 1-opacity
        layers["friend_shoulder_"+id]?.opacity = opacity
        let a = sleeve.anchorPoint, h = palm.anchorPoint
        let shoulder = CGPoint(x:upper.frame.minX+a.x*upper.frame.width,y:upper.frame.minY+a.y*upper.frame.height).applying(support)
        let cupBase = CGPoint(x:hand.frame.minX+cup[0]*hand.frame.width,y:hand.frame.minY+cup[1]*hand.frame.height)
        let handWrist = CGPoint(x:hand.frame.minX+h.x*hand.frame.width+target.x-cupBase.x,
                               y:hand.frame.minY+h.y*hand.frame.height+target.y-cupBase.y)
        palm.position = handWrist; palm.setAffineTransform(.identity)
        sleeve.position = shoulder
        let vx = (wrist[0]-a.x)*upper.frame.width, vy = (wrist[1]-a.y)*upper.frame.height
        if abs(vy) > 1 {
            sleeve.setAffineTransform(CGAffineTransform(a:1,b:0,c:(handWrist.x-shoulder.x-vx)/vy,
                d:(handWrist.y-shoulder.y)/vy,tx:0,ty:0))
        }
    }
    private func makeArmStrips(_ container: CALayer, image: CGImage, definition: SpriteDefinition) {
        guard let polygon = definition.polygon else { return }
        let first = Int(floor((polygon.map { $0[1] }.min() ?? 0)*Double(image.height)))
        let end = Int(ceil((polygon.map { $0[1] }.max() ?? 1)*Double(image.height)))
        container.contents = nil; container.mask = nil
        var strips: [SleevePatch] = []
        // Shared quad corners prevent cracks when adjacent sleeve rows turn.
        // Each quad uses two affine triangles, supported by native and PNG rendering.
        for row in stride(from:(first/8)*8,to:end,by:8) {
            let start = max(first,row-2), stop = min(end,row+10)
            guard stop > start, let cut = image.cropping(to:CGRect(x:0,y:start,width:image.width,height:stop-start)) else { continue }
            let bottom = CGFloat(image.height-stop)/CGFloat(image.height)*definition.frame.height
            let top = CGFloat(image.height-start)/CGFloat(image.height)*definition.frame.height
            let width = definition.frame.width, height = top-bottom
            for lowerRight in [true,false] {
                let layer = CALayer(); layer.contents = cut; layer.contentsGravity = .resize; layer.contentsScale = 2
                layer.bounds = CGRect(x:0,y:0,width:width,height:height); layer.anchorPoint = .zero
                let mask = CAShapeLayer(), path = CGMutablePath()
                path.move(to:.zero)
                if lowerRight { path.addLine(to:CGPoint(x:width,y:0)); path.addLine(to:CGPoint(x:width,y:height)) }
                else { path.addLine(to:CGPoint(x:width,y:height)); path.addLine(to:CGPoint(x:0,y:height)) }
                path.closeSubpath(); mask.path = path; mask.fillColor = NSColor.white.cgColor
                mask.strokeColor = NSColor.white.cgColor; mask.lineWidth = 0.4
                layer.mask = mask
                container.addSublayer(layer); strips.append(SleevePatch(layer:layer,bottom:bottom,top:top,lowerRight:lowerRight))
            }
        }
        armStrips[definition.id] = strips
    }
    private func leftSleeveGeometry(_ sourceY: CGFloat, shoulder: CGPoint, wrist: CGPoint) -> (center:CGPoint, normal:CGPoint, derivative:CGPoint, sourceX:CGFloat) {
        let upper = definitions["left_arm"]!, lower = definitions["left_arm_forearm"]!
        let top = CGFloat(upper.anchor![1])*upper.frame.height
        let bottom = CGFloat(lower.anchor![1])*lower.frame.height
        let span = max(1,top-bottom), t = (top-sourceY)/span, u = max(0,min(1,t)), v = 1-u
        let gap = shoulder.y-wrist.y
        let firstY = shoulder.y-gap*0.36, secondY = wrist.y+gap*0.36
        var center = CGPoint(x:shoulder.x+(wrist.x-shoulder.x)*u*u*(3-2*u),
                             y:v*v*v*shoulder.y+3*v*v*u*firstY+3*v*u*u*secondY+u*u*u*wrist.y)
        let dx = (wrist.x-shoulder.x)*6*u*v
        let dy = 3*v*v*(firstY-shoulder.y)+6*v*u*(secondY-firstY)+3*u*u*(wrist.y-secondY)
        if t < 0 { center.y += t*dy }
        if t > 1 { center.y += (t-1)*dy }
        // Keep the broad sleeve cross-sections mostly forward-facing. Following
        // the full path normal would fold the fabric over itself near the shoulder.
        let angle = atan2(dx,-dy)*0.4, normal = CGPoint(x:cos(angle),y:sin(angle))
        let sourceX = CGFloat(upper.anchor![0])*upper.frame.width+(CGFloat(lower.anchor![0])*lower.frame.width-CGFloat(upper.anchor![0])*upper.frame.width)*u*u*(3-2*u)
        return (center,normal,CGPoint(x:-dx/span,y:-dy/span),sourceX)
    }
    private func curvedLeftSleeve(shoulder: CGPoint, wrist: CGPoint, handX: Double, handY: Double) {
        leftArmPath = (shoulder,wrist)
        for id in ["left_arm","left_arm_forearm"] {
            guard let container = layers[id], let definition = definitions[id] else { continue }
            let offset = id == "left_arm_forearm" ? CGPoint(x:handX,y:handY) : CGPoint(x:0,y:shoulder.y-(definition.frame.minY+container.anchorPoint.y*definition.frame.height))
            let origin = CGPoint(x:definition.frame.minX+offset.x,y:definition.frame.minY+offset.y)
            container.position = CGPoint(x:origin.x+container.anchorPoint.x*definition.frame.width,y:origin.y+container.anchorPoint.y*definition.frame.height)
            container.setAffineTransform(.identity)
            for strip in armStrips[id] ?? [] {
                func vertex(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                    let g = leftSleeveGeometry(y,shoulder:shoulder,wrist:wrist), lateral = x-g.sourceX
                    return CGPoint(x:g.center.x+g.normal.x*lateral-origin.x,y:g.center.y+g.normal.y*lateral-origin.y)
                }
                let width = definition.frame.width, height = strip.top-strip.bottom
                let a = vertex(0,strip.bottom), b = vertex(width,strip.bottom)
                let c = vertex(width,strip.top), d = vertex(0,strip.top)
                // The two triangles meet on the same A–C diagonal.
                let hx = strip.lowerRight ? b.x-a.x : c.x-d.x
                let hy = strip.lowerRight ? b.y-a.y : c.y-d.y
                let vx = strip.lowerRight ? c.x-b.x : d.x-a.x
                let vy = strip.lowerRight ? c.y-b.y : d.y-a.y
                strip.layer.position = .zero
                strip.layer.setAffineTransform(CGAffineTransform(a:hx/width,b:hy/width,c:vx/height,d:vy/height,tx:a.x,ty:a.y))
            }
        }
    }
    private func armPose(_ id: String, shoulderX: Double = 0, shoulderY: Double, handX: Double, handY: Double) {
        guard let layer = layers[id], let definition = definitions[id], let contact = definition.contact,
              let forearm = layers[id+"_forearm"], let lower = definitions[id+"_forearm"] else { return }
        let anchor = layer.anchorPoint
        let shoulder = CGPoint(x: definition.frame.minX+anchor.x*definition.frame.width+shoulderX,
                               y: definition.frame.minY+anchor.y*definition.frame.height+shoulderY)
        layer.position = shoulder
        let wristAnchor = forearm.anchorPoint
        let wrist = CGPoint(x:lower.frame.minX+wristAnchor.x*lower.frame.width+handX,
                            y:lower.frame.minY+wristAnchor.y*lower.frame.height+handY)
        if id == "left_arm", armStrips[id] != nil {
            curvedLeftSleeve(shoulder:shoulder,wrist:wrist,handX:handX,handY:handY)
            return
        }
        let lowerReach = max(1,(contact[1]-wristAnchor.y)*lower.frame.height)
        let lowerScale = max(0.2,min(1.25,(shoulder.y-wrist.y)*0.42/lowerReach))
        let elbow = CGPoint(x:definition.frame.minX+contact[0]*definition.frame.width+handX*0.58,
                            y:wrist.y+lowerReach*lowerScale)
        forearm.position = wrist
        // Share lateral travel between both sleeve segments. Horizontal cross-sections
        // preserve the cuff-to-palm seam while the elbow follows only part of the wrist.
        let forearmX = (contact[0]-wristAnchor.x)*lower.frame.width
        forearm.setAffineTransform(CGAffineTransform(a:1,b:0,
            c:(elbow.x-wrist.x-forearmX)/lowerReach,d:lowerScale,tx:0,ty:0))
        let vx = (contact[0]-anchor.x)*definition.frame.width
        let vy = (contact[1]-anchor.y)*definition.frame.height
        guard abs(vy) > 0.001 else { return }
        // The shoulder cap stays upright instead of rotating sideways on edge keys.
        // The compact board and elbow split retain sleeve depth throughout the reach.
        layer.setAffineTransform(CGAffineTransform(a:1,b:0,
            c:(elbow.x-shoulder.x-vx)/vy,d:(elbow.y-shoulder.y)/vy,tx:0,ty:0))
    }
    func pointInCanvas(_ id: String, normalized: CGPoint) -> CGPoint? {
        if armStrips[id] != nil, let path = leftArmPath, let definition = definitions[id] {
            let geometry = leftSleeveGeometry(normalized.y*definition.frame.height,shoulder:path.shoulder,wrist:path.wrist)
            let lateral = normalized.x*definition.frame.width-geometry.sourceX
            return CGPoint(x:geometry.center.x+geometry.normal.x*lateral,y:geometry.center.y+geometry.normal.y*lateral)
        }
        guard let layer = layers[id] else { return nil }
        let local = CGPoint(x: layer.bounds.width * normalized.x, y: layer.bounds.height * normalized.y)
        return layer.convert(local, to: rootLayer)
    }
    func fingerContact(for finger: TypingFinger) -> CGPoint? {
        guard let sprite = definitions.values.first(where: { $0.finger == finger }), let contact = sprite.contact else { return nil }
        return pointInCanvas(sprite.id, normalized: CGPoint(x: contact[0],y:contact[1]))
    }
    func spriteContact(_ id: String) -> CGPoint? {
        if let crawled = friendCrawlRig?.contact(id) { return crawled }
        if let projected = projectedLegContacts[id] { return projected }
        guard let contact = definitions[id]?.contact else { return nil }
        return pointInCanvas(id,normalized:CGPoint(x:contact[0],y:contact[1]))
    }
    func spriteIsVisible(_ id: String) -> Bool {
        guard let layer = layers[id] else { return false }
        return !layer.isHidden && layer.opacity > 0 && layer.contents != nil
    }
    func keyContactInCanvas(_ code: UInt16, near point: CGPoint, pressure: Double) -> CGPoint? {
        guard let keyboard = keyboardRenderer,
              let local = keyboard.keyContact(code, near: keyboard.root.convert(point,from:rootLayer), pressure: pressure) else { return nil }
        return keyboard.root.convert(local,to:rootLayer)
    }
    private static func eyeMask(size: CGSize) -> CGImage? {
        let width = 645, height = 352
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // Top-left source coordinates, restricted to facial skin around each eye.
        let regions = [CGRect(x: 193, y: 211, width: 68, height: 51), CGRect(x: 276, y: 201, width: 78, height: 54)]
        for region in regions {
            for inset in 0...6 {
                let r = region.insetBy(dx: CGFloat(inset), dy: CGFloat(inset))
                let local = CGRect(x: r.minX, y: CGFloat(height) - r.maxY, width: r.width, height: r.height)
                context.setFillColor(NSColor.white.withAlphaComponent(inset == 6 ? 1 : 0.22).cgColor)
                context.fillEllipse(in: local)
            }
        }
        return context.makeImage()
    }
    private static func softFeatureMask() -> CGImage? {
        guard let context = CGContext(data:nil,width:256,height:128,bitsPerComponent:8,bytesPerRow:0,
            space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        for inset in 0...5 {
            context.setFillColor(NSColor.white.withAlphaComponent(inset == 5 ? 1 : 0.28).cgColor)
            context.fillEllipse(in:CGRect(x:inset,y:inset,width:256-2*inset,height:128-2*inset))
        }
        return context.makeImage()
    }
    func savePNG(to url: URL, background: NSColor? = nil, region: CGRect? = nil, scale: Double = 1) throws {
        let viewport = region ?? CGRect(origin:.zero,size:canvasSize)
        let w = Int(viewport.width*scale), h = Int(viewport.height*scale)
        guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw AssetError.invalid("render context") }
        if let background { context.setFillColor(background.cgColor); context.fill(CGRect(x:0,y:0,width:w,height:h)) }
        context.scaleBy(x:scale,y:scale); context.translateBy(x:-viewport.minX,y:-viewport.minY)
        rootLayer.render(in: context)
        guard let cg = context.makeImage(), let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { throw AssetError.invalid("render PNG") }
        try data.write(to: url)
    }
}
