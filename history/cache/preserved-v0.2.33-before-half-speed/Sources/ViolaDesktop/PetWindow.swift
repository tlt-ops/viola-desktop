import AppKit
import ViolaCore
final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
final class PetView: NSView {
    let renderer: CharacterRenderer
    var onMenu: ((NSEvent) -> Void)?
    var onInteraction: (() -> Void)?
    var isInteracting: Bool { pressedPoint != nil }
    var onMoved: (() -> Void)?
    var onScale: ((Double) -> Void)?
    var onShoePickup: ((ShoeSide) -> Void)?
    var onLaugh: (() -> Void)?
    private var pressedShoe: ShoeSide?
    private var pressedPoint: CGPoint?
    private var dragOrigin: NSPoint?
    private var windowOrigin: NSPoint?
    private var didDrag = false
    init(renderer: CharacterRenderer) {
        self.renderer = renderer
        super.init(frame: .zero)
        wantsLayer = true; layer = CALayer()
        layer?.addSublayer(renderer.rootLayer)
        setAccessibilityElement(true); setAccessibilityRole(.image)
        setAccessibilityLabel("薇欧拉桌面伙伴，点击头部或上半身大笑，拖动移动，点击掉落的高跟鞋穿回，滚轮或触控板捏合缩放，右键打开大小菜单")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        renderer.rootLayer.position = .zero
        renderer.rootLayer.transform = CATransform3DMakeScale(bounds.width / renderer.canvasSize.width, bounds.height / renderer.canvasSize.height, 1)
        CATransaction.commit()
    }
    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    private func canvasPoint(_ event: NSEvent) -> CGPoint {
        let point = convert(event.locationInWindow,from:nil)
        return CGPoint(x:point.x*renderer.canvasSize.width/max(1,bounds.width),y:point.y*renderer.canvasSize.height/max(1,bounds.height))
    }
    override func mouseDown(with event: NSEvent) {
        // Stop autonomous movement before recording the origin used by dragging.
        onInteraction?()
        didDrag = false
        pressedPoint = canvasPoint(event); pressedShoe = renderer.recoverableShoe(at:pressedPoint!)
        if pressedShoe == nil { dragOrigin = NSEvent.mouseLocation; windowOrigin = window?.frame.origin }
    }
    override func mouseDragged(with event: NSEvent) {
        guard let dragOrigin, let windowOrigin else { return }
        let cursor = NSEvent.mouseLocation
        if hypot(cursor.x-dragOrigin.x,cursor.y-dragOrigin.y) >= 5 { didDrag = true }
        guard didDrag else { return }
        window?.setFrameOrigin(NSPoint(x: windowOrigin.x + cursor.x - dragOrigin.x, y: windowOrigin.y + cursor.y - dragOrigin.y))
    }
    override func mouseUp(with event: NSEvent) {
        if let shoe = pressedShoe, let down = pressedPoint {
            let point = canvasPoint(event)
            if hypot(point.x-down.x,point.y-down.y) < 10, renderer.recoverableShoe(at:point) == shoe { onShoePickup?(shoe) }
        } else if didDrag { onMoved?() }
        else if let down = pressedPoint, renderer.canLaugh(at:down), renderer.canLaugh(at:canvasPoint(event)) { onLaugh?() }
        pressedShoe = nil; pressedPoint = nil; dragOrigin = nil; windowOrigin = nil
    }
    override func rightMouseDown(with event: NSEvent) { onInteraction?(); onMenu?(event) }
    override func scrollWheel(with event: NSEvent) {
        onInteraction?()
        // Ignore inertia so a completed trackpad gesture cannot keep resizing the pet.
        guard event.momentumPhase.isEmpty, event.scrollingDeltaY != 0 else { return }
        let sensitivity = event.hasPreciseScrollingDeltas ? 0.003 : 0.03
        let exponent = max(-0.2, min(0.2, Double(event.scrollingDeltaY) * sensitivity))
        onScale?(exp(exponent))
    }
    override func magnify(with event: NSEvent) {
        onInteraction?()
        guard event.magnification != 0 else { return }
        onScale?(max(0.5, min(1.5, 1 + Double(event.magnification))))
    }
}
