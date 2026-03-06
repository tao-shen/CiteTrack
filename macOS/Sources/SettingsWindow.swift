import Cocoa
import SwiftUI

// MARK: - Settings Window Controller (SwiftUI)
class SettingsWindowController: NSWindowController {

    override init(window: NSWindow?) {
        super.init(window: window)
        setupWindow()
        setupSwiftUIContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupWindow() {
        guard let screen = NSScreen.main else {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 550, height: 500),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = L("settings_title")
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 500, height: 450)
            self.window = window
            return
        }

        let screenSize = screen.visibleFrame.size
        let preferredWidth: CGFloat = min(600, screenSize.width * 0.45)
        let preferredHeight: CGFloat = min(550, screenSize.height * 0.55)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: preferredWidth, height: preferredHeight),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.title = L("settings_title")
        window.isReleasedWhenClosed = false

        let minWidth = min(500, screenSize.width * 0.35)
        let minHeight = min(420, screenSize.height * 0.45)
        window.minSize = NSSize(width: minWidth, height: minHeight)

        let maxWidth = screenSize.width * 0.9
        let maxHeight = screenSize.height * 0.9
        window.maxSize = NSSize(width: maxWidth, height: maxHeight)

        self.window = window
    }

    private func setupSwiftUIContent() {
        let hostingController = NSHostingController(rootView: SettingsView())
        window?.contentViewController = hostingController
    }
}
