import AppKit
import QuartzCore
import Foundation

final class ClickView: NSView {
    let role: String
    let outputURL: URL
    private(set) var clicks = 0
    private let square = CALayer()

    init(role: String, outputURL: URL) {
        self.role = role
        self.outputURL = outputURL
        super.init(frame: NSRect(x: 0, y: 0, width: 600, height: 300))
        setAccessibilityElement(true)
        updateAccessibility()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }

    override var isOpaque: Bool { role == "background" }
    override func makeBackingLayer() -> CALayer { CALayer() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard role == "overlay" else { return }
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        square.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
        square.backgroundColor = NSColor.systemRed.cgColor
        layer?.addSublayer(square)
    }

    override func draw(_ dirtyRect: NSRect) {
        if role == "background" {
            NSColor(calibratedRed: 0.10, green: 0.28, blue: 0.58, alpha: 1).setFill()
            dirtyRect.fill()
            let text = "Background window — click count: \(clicks)"
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 24, weight: .medium), .foregroundColor: NSColor.white]
            (text as NSString).draw(at: NSPoint(x: 24, y: 246), withAttributes: attrs)
        }
    }

    override func mouseDown(with event: NSEvent) {
        clicks += 1
        updateAccessibility()
        let data: [String: Any] = ["role": role, "clickCount": clicks, "timestamp": ISO8601DateFormatter().string(from: Date()), "localPoint": ["x": event.locationInWindow.x, "y": event.locationInWindow.y]]
        if let bytes = try? JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys]) {
            try? bytes.write(to: outputURL, options: .atomic)
        }
        needsDisplay = true
    }

    private func updateAccessibility() {
        setAccessibilityLabel(role == "background" ? "Background click count \(clicks)" : "Overlay red-square click count \(clicks)")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    func applicationDidFinishLaunching(_ notification: Notification) {
        let role = Bundle.main.object(forInfoDictionaryKey: "ProbeRole") as? String ?? "background"
        let out = URL(fileURLWithPath: "/Users/tanlantian/Library/Caches/ViolaDesktop/transparency-probe/\(role)-clicks.json")
        let view = ClickView(role: role, outputURL: out)
        let rect = NSRect(x: 400, y: 300, width: 600, height: 300)
        if role == "overlay" {
            let panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = view
            panel.isReleasedWhenClosed = false
            window = panel
            panel.orderFrontRegardless()
        } else {
            let win = NSWindow(contentRect: rect, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            win.title = "Viola Input Probe"
            win.isOpaque = true
            win.backgroundColor = NSColor(calibratedRed: 0.10, green: 0.28, blue: 0.58, alpha: 1)
            win.contentView = view
            win.isReleasedWhenClosed = false
            window = win
            NSApp.activate(ignoringOtherApps: true)
            win.makeKeyAndOrderFront(nil)
        }
        installQuitMenu()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    private func installQuitMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Viola Probe", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)
        NSApp.mainMenu = main
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
