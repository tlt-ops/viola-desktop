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
    private var petPresentationRect: CGRect?
    private var mouseDownCount = 0
    private var mouseUpCount = 0
    private var laughRequestCount = 0
    private var shoePickupRequestCount = 0
    private var dragCompletionCount = 0
    private var rightMenuRequestCount = 0
    private var lastDownCoordinates: [String: Double] = [:]
    private var lastUpCoordinates: [String: Double] = [:]
    var interactionDiagnostics: [String: Any] {
        ["mouseDownCount": mouseDownCount, "mouseUpCount": mouseUpCount,
         "laughRequestCount": laughRequestCount, "shoePickupRequestCount": shoePickupRequestCount,
         "dragCompletionCount": dragCompletionCount, "rightMenuRequestCount": rightMenuRequestCount,
         "lastDown": lastDownCoordinates, "lastUp": lastUpCoordinates, "gestureActive": isInteracting]
    }
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
        layoutPetLayer()
    }
    /// A fixed crawl host can be wider than the pet; preserve the original point size.
    func setPetPresentationRect(_ rect: CGRect?) {
        petPresentationRect = rect
        layoutPetLayer()
    }
    func movePetPresentation(to origin: CGPoint) {
        guard var rect = petPresentationRect else { return }
        rect.origin = origin
        petPresentationRect = rect
        CATransaction.begin(); CATransaction.setDisableActions(true)
        renderer.rootLayer.position = origin
        CATransaction.commit()
    }
    private func layoutPetLayer() {
        let rect = petPresentationRect ?? bounds
        CATransaction.begin(); CATransaction.setDisableActions(true)
        renderer.rootLayer.position = rect.origin
        renderer.rootLayer.transform = CATransform3DMakeScale(rect.width / renderer.canvasSize.width, rect.height / renderer.canvasSize.height, 1)
        CATransaction.commit()
    }
    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        if let rect = petPresentationRect, !rect.contains(convert(point, from: superview)) { return nil }
        return super.hitTest(point)
    }
    private func screenPoint(_ event: NSEvent) -> CGPoint {
        // Prefer the event's window when a queued event belongs to an earlier host.
        if let eventWindow = event.window { return eventWindow.convertPoint(toScreen: event.locationInWindow) }
        if let window, event.windowNumber == window.windowNumber {
            return window.convertPoint(toScreen: event.locationInWindow)
        }
        return NSEvent.mouseLocation
    }
    private func canvasPoint(screenPoint: CGPoint) -> CGPoint {
        guard let window else { return .zero }
        let point = convert(window.convertPoint(fromScreen: screenPoint), from: nil)
        let rect = petPresentationRect ?? bounds
        return CGPoint(x: (point.x - rect.minX) * renderer.canvasSize.width / max(1, rect.width),
                       y: (point.y - rect.minY) * renderer.canvasSize.height / max(1, rect.height))
    }
    override func mouseDown(with event: NSEvent) {
        // Stop autonomous movement before recording the origin used by dragging.
        let screenLocation = screenPoint(event)
        guard CGRect(origin: .zero, size: renderer.canvasSize).contains(canvasPoint(screenPoint: screenLocation)) else { return }
        onInteraction?()
        didDrag = false
        pressedPoint = canvasPoint(screenPoint: screenLocation); pressedShoe = renderer.recoverableShoe(at:pressedPoint!)
        mouseDownCount += 1
        lastDownCoordinates = ["screenX": screenLocation.x, "screenY": screenLocation.y,
            "canvasX": pressedPoint!.x, "canvasY": pressedPoint!.y,
            "eventWindowNumber": Double(event.windowNumber), "mappedWindowNumber": Double(window?.windowNumber ?? -1)]
        if pressedShoe == nil { dragOrigin = screenLocation; windowOrigin = window?.frame.origin }
    }
    override func mouseDragged(with event: NSEvent) {
        guard let dragOrigin, let windowOrigin else { return }
        // Use the event's screen location consistently for physical and injected gestures.
        let cursor = screenPoint(event)
        if hypot(cursor.x-dragOrigin.x,cursor.y-dragOrigin.y) >= 5 { didDrag = true }
        guard didDrag else { return }
        window?.setFrameOrigin(NSPoint(x: windowOrigin.x + cursor.x - dragOrigin.x, y: windowOrigin.y + cursor.y - dragOrigin.y))
    }
    override func mouseUp(with event: NSEvent) {
        let screenLocation = screenPoint(event)
        let point = canvasPoint(screenPoint: screenLocation)
        mouseUpCount += 1
        lastUpCoordinates = ["screenX": screenLocation.x, "screenY": screenLocation.y,
            "canvasX": point.x, "canvasY": point.y,
            "eventWindowNumber": Double(event.windowNumber), "mappedWindowNumber": Double(window?.windowNumber ?? -1)]
        if let shoe = pressedShoe, let down = pressedPoint {
            if hypot(point.x-down.x,point.y-down.y) < 10, renderer.recoverableShoe(at:point) == shoe {
                shoePickupRequestCount += 1; onShoePickup?(shoe)
            }
        } else if didDrag { dragCompletionCount += 1; onMoved?() }
        else if let down = pressedPoint, renderer.canLaugh(at:down), renderer.canLaugh(at:point) {
            laughRequestCount += 1; onLaugh?()
        }
        pressedShoe = nil; pressedPoint = nil; dragOrigin = nil; windowOrigin = nil; didDrag = false
    }
    override func rightMouseDown(with event: NSEvent) {
        let screenLocation = screenPoint(event)
        guard CGRect(origin: .zero, size: renderer.canvasSize).contains(canvasPoint(screenPoint: screenLocation)) else { return }
        onInteraction?()
        guard let window else { return }
        // The old event location belongs to the expanded host, which cancellation restores.
        let relocated = NSEvent.mouseEvent(with: event.type,
            location: window.convertPoint(fromScreen: screenLocation),
            modifierFlags: event.modifierFlags, timestamp: event.timestamp,
            windowNumber: window.windowNumber, context: nil,
            eventNumber: event.eventNumber, clickCount: event.clickCount, pressure: event.pressure)
        rightMenuRequestCount += 1; onMenu?(relocated ?? event)
    }
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
