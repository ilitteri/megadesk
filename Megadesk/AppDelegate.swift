import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: FloatingWindowController?
    private var statusItem: NSStatusItem?
    private var onboardingController: OnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = ContentView()
        windowController = FloatingWindowController(contentView: contentView)
        windowController?.window?.delegate = self
        setupMenuBar()

        if UserDefaults.standard.bool(forKey: "megadesk.onboardingComplete") {
            windowController?.show()
        } else {
            onboardingController = OnboardingWindowController {
                self.onboardingController = nil
                self.windowController?.show()
            }
            onboardingController?.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Menu bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            let icon = NSImage(named: "MenuBarIcon")
            icon?.size = NSSize(width: 18, height: 18)
            icon?.isTemplate = true
            button.image = icon
        }
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Hide Widget", action: #selector(toggleWidget), keyEquivalent: "")
            .target = self
        let compactItem = NSMenuItem(title: "Compact Mode", action: #selector(toggleCompact), keyEquivalent: "")
        compactItem.target = self
        menu.addItem(compactItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Megadesk", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem?.menu = menu
    }

    @objc private func toggleWidget() {
        windowController?.toggle()
    }

    @objc private func toggleCompact() {
        windowController?.toggleCompact()
    }
}

// MARK: - NSMenuDelegate — refresh title before menu appears

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        let isVisible = windowController?.isWidgetVisible ?? false
        menu.item(at: 0)?.title = isVisible ? "Hide Widget" : "Show Widget"
        menu.item(at: 1)?.state = (windowController?.isCompact ?? false) ? .on : .off
    }
}

// MARK: - NSWindowDelegate — close button hides instead of quitting

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        windowController?.hide()
        return false
    }
}
