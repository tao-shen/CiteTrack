import Cocoa

// MARK: - Charts Window Controller
class ChartsWindowController: NSWindowController {
    
    private var chartsViewController: ChartsViewController?
    
    override init(window: NSWindow?) {
        super.init(window: window)
        setupWindow()
        setupViewController()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "CiteTrack - Citation Charts"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 600, height: 400)
        
        // 设置窗口级别和属性，避免与设置窗口冲突
        window.level = .normal
        window.hidesOnDeactivate = false
        
        self.window = window
    }
    
    private func setupViewController() {
        print("ChartsWindowController: Creating ChartsViewController...")
        chartsViewController = ChartsViewController()
        
        guard let chartsVC = chartsViewController else {
            print("ChartsWindowController: ERROR - Failed to create ChartsViewController")
            return
        }
        
        // 确保视图控制器正确初始化
        print("ChartsWindowController: Loading view...")
        chartsVC.loadView()
        
        print("ChartsWindowController: Calling viewDidLoad...")
        chartsVC.viewDidLoad()
        
        // 设置窗口内容视图
        window?.contentView = chartsVC.view
        
        print("ChartsWindowController: Successfully created and configured charts view controller")
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        
        // 确保窗口在前台显示
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        print("ChartsWindowController: Window shown")
    }
    
    // 实现窗口委托方法来处理窗口关闭
    override func windowDidLoad() {
        super.windowDidLoad()
        window?.delegate = self
    }
    
    deinit {
        print("ChartsWindowController: Deallocated")
    }
}

// MARK: - NSWindowDelegate
extension ChartsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        print("ChartsWindowController: Window will close, cleaning up")
        
        // 通知AppDelegate清理窗口引用
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.chartsWindowDidClose()
        }
    }
} 