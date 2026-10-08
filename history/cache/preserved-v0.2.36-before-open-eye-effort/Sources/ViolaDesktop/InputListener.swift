import AppKit
import CoreGraphics
import ViolaCore
/// Passive physical-key observation. No filtering, injection or character decoding.
final class InputListener {
    var onEvent: ((InputEvent) -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var globalMouse: Any?
    private var localMonitor: Any?
    private var heldModifiers: Set<UInt16> = []
    private(set) var running = false
    private(set) var keyboardAvailable = false
    private(set) var keyDownCount = 0
    private(set) var keyUpCount = 0
    private(set) var mouseMoveCount = 0
    private(set) var leftClickCount = 0
    private(set) var rightClickCount = 0
    var permissionGranted: Bool { CGPreflightListenEventAccess() }
    static var now: Double { ProcessInfo.processInfo.systemUptime }
    func start() {
        stop(); running = true
        let kinds: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, .mouseMoved, .leftMouseDragged, .rightMouseDragged, .leftMouseDown, .rightMouseDown]
        let mask = kinds.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        if permissionGranted {
            tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly, eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let listener = Unmanaged<InputListener>.fromOpaque(context).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = listener.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                } else if type == .flagsChanged, let input = listener.modifier(code: UInt16(event.getIntegerValueField(.keyboardEventKeycode)), flags: event.flags) {
                    listener.deliver(input)
                } else if let input = InputListener.decode(type: type, event: event, now: InputListener.now) {
                    listener.deliver(input)
                }
                return Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        }
        if let tap {
            source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true); keyboardAvailable = true
        } else {
            globalMouse = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .leftMouseDown, .rightMouseDown]) { [weak self] event in self?.handleLocal(event) }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged, .mouseMoved, .leftMouseDragged, .rightMouseDragged, .leftMouseDown, .rightMouseDown]) { [weak self] event in self?.handleLocal(event); return event }
        }
    }
    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil
        if let tap { CFMachPortInvalidate(tap) }; tap = nil
        if let globalMouse { NSEvent.removeMonitor(globalMouse) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMouse = nil; localMonitor = nil; running = false; keyboardAvailable = false
        heldModifiers.removeAll()
    }
    func requestPermission() { _ = CGRequestListenEventAccess() }
    static func decode(type: CGEventType, event: CGEvent, now: Double) -> InputEvent? {
        switch type {
        case .keyDown: return .keyDown(time: now, isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0, keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)))
        case .keyUp: return .keyUp(time: now, keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)))
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged:
            return .mouseMove(time: now, x: event.location.x, y: event.location.y, dx: event.getDoubleValueField(.mouseEventDeltaX), dy: event.getDoubleValueField(.mouseEventDeltaY))
        case .leftMouseDown: return .leftClick(time: now)
        case .rightMouseDown: return .rightClick(time: now)
        default: return nil
        }
    }
    private func handleLocal(_ event: NSEvent) {
        let t = Self.now
        let input: InputEvent?
        switch event.type {
        case .keyDown: input = .keyDown(time: t, isRepeat: event.isARepeat, keyCode: event.keyCode)
        case .keyUp: input = .keyUp(time: t, keyCode: event.keyCode)
        case .flagsChanged: input = modifier(code: event.keyCode, flags: event.cgEvent?.flags ?? CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)))
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged:
            let p = NSEvent.mouseLocation
            input = .mouseMove(time: t, x: p.x, y: p.y, dx: event.deltaX, dy: event.deltaY)
        case .leftMouseDown: input = .leftClick(time: t)
        case .rightMouseDown: input = .rightClick(time: t)
        default: input = nil
        }
        if let input { deliver(input) }
    }
    private func modifier(code: UInt16, flags: CGEventFlags) -> InputEvent? {
        if code == 57 {
            // Caps Lock emits a flags transition per physical toggle, rather than a
            // conventional down/up pair. Count both on and off toggles as one press.
            deliver(.keyDown(time: Self.now, isRepeat: false, keyCode: code))
            return .keyUp(time: Self.now, keyCode: code)
        }
        let flag: CGEventFlags
        switch code {
        case 54,55: flag = .maskCommand; case 56,60: flag = .maskShift
        case 58,61: flag = .maskAlternate; case 59,62: flag = .maskControl
        case 57: flag = .maskAlphaShift; case 63: flag = .maskSecondaryFn
        default: return nil
        }
        let down = flags.contains(flag) && (code == 57 ? true : !heldModifiers.contains(code))
        if down { heldModifiers.insert(code) } else { heldModifiers.remove(code) }
        return down ? .keyDown(time: Self.now, isRepeat: false, keyCode: code) : .keyUp(time: Self.now, keyCode: code)
    }
    private func deliver(_ input: InputEvent) {
        switch input {
        case .keyDown: keyDownCount += 1
        case .keyUp: keyUpCount += 1
        case .mouseMove: mouseMoveCount += 1
        case .leftClick: leftClickCount += 1
        case .rightClick: rightClickCount += 1
        }
        onEvent?(input)
    }
    deinit { stop() }
}
