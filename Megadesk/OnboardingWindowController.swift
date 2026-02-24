import AppKit
import SwiftUI

final class OnboardingWindowController: NSWindowController {
    var onFinish: (() -> Void)?

    convenience init(onFinish: @escaping () -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Megadesk"
        window.isReleasedWhenClosed = false

        // Close the window then hand off to the caller's callback
        let view = OnboardingView {
            window.close()
            onFinish()
        }
        let hosting = NSHostingView(rootView: view)
        window.contentView = hosting
        window.center()

        // Size the window to fit the SwiftUI content
        let fittingSize = hosting.fittingSize
        if fittingSize.height > 0 {
            window.setContentSize(fittingSize)
            window.center()
        }

        self.init(window: window)
        self.onFinish = onFinish
    }
}
