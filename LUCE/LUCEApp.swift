//
//  LuceApp.swift
//  LUCE
//
//  Created on 22/05/2026.
//

import SwiftUI

@main
struct Luce: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

extension Notification.Name {
    static let menuBarIconChanged  = Notification.Name("menuBarIconChanged")
    static let keyboardLockChanged = Notification.Name("keyboardLockChanged")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var floatingPanel: FloatingPanel!
    var luceClient: LuceClient!

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        luceClient = LuceClient()

        setupStatusBar()
        setupFloatingPanel()
        setupNotifications()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Safety: always release the keyboard lock on normal quit
        luceClient?.emergencyUnlock()
    }

    // MARK: - Status Bar

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            let iconName = UserDefaults.standard.string(forKey: "menuBarIcon") ?? "keyboard"
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "LUCE")
            button.action = #selector(statusBarClicked)
        }
    }

    // MARK: - Floating Panel

    func setupFloatingPanel() {
        let screenRect = NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let panelWidth: CGFloat = 320
        let initialHeight: CGFloat = 80

        let panelX = screenRect.maxX - panelWidth - 10
        let panelY = screenRect.maxY - initialHeight

        floatingPanel = FloatingPanel(
            contentRect: NSRect(x: panelX, y: panelY,
                                width: panelWidth, height: initialHeight),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        let contentView = LuceView(client: luceClient, onClose: { [weak self] in
            self?.hidePanel()
        })
        floatingPanel.contentView = NSHostingView(rootView: contentView)
    }

    // MARK: - Notifications

    func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .menuBarIconChanged, object: nil, queue: .main
        ) { [weak self] notification in
            if let icon = notification.userInfo?["icon"] as? String {
                self?.statusItem?.button?.image = NSImage(
                    systemSymbolName: icon, accessibilityDescription: "LUCE"
                )
            }
        }

        NotificationCenter.default.addObserver(
            forName: .keyboardLockChanged, object: nil, queue: .main
        ) { [weak self] notification in
            let isLocked = notification.userInfo?["isLocked"] as? Bool ?? false
            if isLocked {
                self?.statusItem?.button?.image = NSImage(
                    systemSymbolName: "lock.fill",
                    accessibilityDescription: "LUCE – Locked"
                )
            } else {
                let iconName = UserDefaults.standard.string(forKey: "menuBarIcon") ?? "keyboard"
                self?.statusItem?.button?.image = NSImage(
                    systemSymbolName: iconName, accessibilityDescription: "LUCE"
                )
            }
        }
    }

    // MARK: - Toggle / Show / Hide

    @objc func statusBarClicked() {
        if floatingPanel.isVisible { hidePanel() } else { showPanel() }
    }

    func showPanel() {
        if !floatingPanel.isMovableByWindowBackground {
            let screenRect = NSScreen.main?.visibleFrame ?? .zero
            var frame = floatingPanel.frame

            if let button = statusItem?.button, let buttonWindow = button.window {
                let buttonFrame = buttonWindow.convertToScreen(button.bounds)
                frame.origin.x = buttonFrame.midX - frame.width / 2
            } else {
                frame.origin.x = screenRect.maxX - frame.width - 10
            }

            frame.origin.x = max(10, frame.origin.x)
            frame.origin.y = screenRect.maxY - frame.height

            floatingPanel.setFrame(frame, display: true)
        }

        floatingPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hidePanel() {
        floatingPanel.orderOut(nil)
    }
}
