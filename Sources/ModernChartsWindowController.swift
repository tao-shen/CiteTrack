import Cocoa

// MARK: - Modern Charts Window Controller
class ModernChartsWindowController: NSWindowController {
    
    private var modernChartsViewController: ModernChartsViewController?
    
    override init(window: NSWindow?) {
        super.init(window: window)
        setupModernWindow()
        setupModernViewController()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupModernWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "CiteTrack - Modern Analytics Dashboard"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 1000, height: 700)
        
        // Modern window styling
        window.level = .normal
        window.hidesOnDeactivate = false
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor.controlBackgroundColor
        
        // Add subtle shadow for modern look
        window.hasShadow = true
        
        self.window = window
    }
    
    private func setupModernViewController() {
        print("ModernChartsWindowController: Creating ModernChartsViewController...")
        modernChartsViewController = ModernChartsViewController()
        
        guard let modernChartsVC = modernChartsViewController else {
            print("ModernChartsWindowController: ERROR - Failed to create ModernChartsViewController")
            return
        }
        
        // Set as content view controller for proper lifecycle management
        window?.contentViewController = modernChartsVC
        
        print("ModernChartsWindowController: Successfully created and configured modern charts view controller")
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        
        // Modern window presentation with animation
        window?.alphaValue = 0.0
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window?.animator().alphaValue = 1.0
        }
        
        print("ModernChartsWindowController: Modern window shown with animation")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        window?.delegate = self
        
        // Configure toolbar if needed
        configureModernToolbar()
    }
    
    private func configureModernToolbar() {
        // Configure the modern toolbar appearance
        if let toolbar = window?.toolbar {
            toolbar.displayMode = .iconOnly
            toolbar.showsBaselineSeparator = false
        }
    }
    
    deinit {
        print("ModernChartsWindowController: Deallocated")
    }
}

// MARK: - NSWindowDelegate
extension ModernChartsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        print("ModernChartsWindowController: Modern window will close, cleaning up")
        
        // Animate window closing
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window?.animator().alphaValue = 0.0
        } completionHandler: {
            // Notify AppDelegate to clean up window reference
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.chartsWindowDidClose()
            }
        }
    }
    
    func windowDidResize(_ notification: Notification) {
        // Handle any resize-specific logic for modern layout
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        // Modern window became active
        print("ModernChartsWindowController: Window became key")
    }
}