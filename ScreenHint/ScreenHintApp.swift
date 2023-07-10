//
//  ScreenHintApp.swift
//  ScreenHint
//
//  Created by Salem on 5/1/21.
//

import SwiftUI
import AppKit
import HotKey
import Carbon.HIToolbox
import ServiceManagement
import KeyboardShortcuts
import os

class ScreenHintAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    
    // Status bar item
    var statusBarItem: NSStatusItem!
    
    // Secret Windows
    var swcs: [SecretWindowController] = []
    
    // Mouse drag state
    var dragStart: NSPoint = NSPoint.init(x: 0, y: 0)
    var hotKey: HotKey?
    
    // Mouse event monitors
    var mouseDownMonitor: Any?
    var mouseUpMonitor: Any?
    var mouseDragMonitor: Any?
    var keyDownMonitor: Any?
    
    // The ID of our launcher app    
    @AppStorage(AppStorageKeys.openAtLogin) private var openAtLogin = false
    @Published var hints: [HintWindowController] = []
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        UserDefaults.standard.register(defaults: [
            AppStorageKeys.isFirstLaunch: true,
        ])
        
        let isFirstLaunch = UserDefaults.standard.bool(forKey: AppStorageKeys.isFirstLaunch)
        print("isFirstLaunch", isFirstLaunch)
        
        if (isFirstLaunch) {
            self.showOnboarding(nil)
            // Set the "isFirstLaunch" flag to false so that we don't do this again.
            UserDefaults.standard.set(false, forKey:"isFirstLaunch")
        }
                
        // Register our launcher app as a login item
        if (self.openAtLogin) {
            SMLoginItemSetEnabled(AppIds.launcher as CFString, true)
        }
        
        // Ask for recording access if we don't have it
        let hasScreenAccess = CGPreflightScreenCaptureAccess();
        if (!hasScreenAccess) {
            // The first time we request access, the settings window opens and an entry for ScreenHint is added to
            // the permissions section of Security & Privacy > Privacy > ScreenRecording. Subsequent requests don't
            // seem to open settings, so use #checkForPermissions() instead.
            CGRequestScreenCaptureAccess()
        }
                
        // Generate secret windows, now and any time the screen configuration changes
        self.generateSecretWindows()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: NSApplication.shared,
                                               queue: OperationQueue.main) {
            notification -> Void in
            // TODO: Don't do this, just make secret windows when someone presses the shortcut. this seems to be called all the time.
            self.generateSecretWindows()
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
                                                          object: nil,
                                                          queue: OperationQueue.main) { notification -> Void in
            // TODO: hide secret window when space is transitioning
        }
        
        KeyboardShortcuts.onKeyUp(for: .createNewHint) { [self] in
            // The user pressed the keyboard shortcut for “unicorn mode”!
            self.captureHint(nil)
        }

        
        
        // Initialize the status bar menu
        self.createMenu()
    }
    
    @objc func showOnboarding(_ sender: AnyObject?) {
        // Activate ScreenHint so the window appears in front.
        NSApp.activate(ignoringOtherApps: true)
        
        // Show the onboarding view
        showWindowForView(OnboardingView())
    }
    
    /**
     Create a SecretWindowController for each monitor, clearing any existing SecretWindowControllers.
     */
    func generateSecretWindows() {
        // Remove existing screens
        self.swcs.forEach { swc in
            swc.close()
        }
        
        // TODO: Make sure monitors are unbound here.
        // I get wanrnings like this, and I think it's because we're not freeing these
        // windows here:
        //  NSWindow has detected an excessive live window count of 101. Window 0x2112 of class 'ScreenHint.SecretWindow' created after passing the threshold of 100. This window is not necessarily the cause.
        self.swcs = []
        
        // make a secret window for each screen. These will
        // capture mouse events for us when making a new hint.
        NSScreen.screens.forEach { screen in
            self.swcs.append(SecretWindowController(screen))
        }

    }
    
    // Disable the global hotkey so that the menu hotkey can be the same
    func menuWillOpen(_ menu: NSMenu) {
        if let hotkey = self.hotKey {
            hotkey.isPaused = true
        }
    }
    
    // Re-enable the global hotkey once the menu has closed
    func menuDidClose(_ menu: NSMenu) {
        if let hotkey = self.hotKey {
            hotkey.isPaused = false
        }

    }
    
    func getRectForPoints(_ first: NSPoint, _ second: NSPoint) -> NSRect {
        let x = min(first.x, second.x)
        let y = min(first.y, second.y)
        let width = abs(first.x - second.x)
        let height = abs(first.y - second.y)
        
        return NSRect.init(x:x, y:y, width:width, height:height)
    }
    
    /**
     Set up the status bar menu
     */
    func createMenu() {
        let menu = NSMenu()
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0")

        // Unselectable item displaying the app name and version
        menu.addItem(withTitle: "ScreenHint v\(version)", action: nil, keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        let newHintItem = menu.addItem(
            withTitle: "New Hint",
            action: #selector(captureHint(_:)),
            keyEquivalent: ""
        )
        newHintItem.image = NSImage(systemSymbolName: "rectangle.dashed", accessibilityDescription: nil)
        
        let clearHintItem = menu.addItem(
            withTitle: "Clear All Hints",
            action: #selector(clearHints(_:)),
            keyEquivalent: ""
        )
        clearHintItem.image = NSImage(systemSymbolName: "rectangle.stack.badge.minus", accessibilityDescription: nil)
        
        let settingsItem = menu.addItem(
            withTitle: "Settings...",
            action: #selector(showSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        
        menu.addItem(NSMenuItem.separator())
        
        let onboardingItem = menu.addItem(
            withTitle: "Show Onboarding",
            action: #selector(showOnboarding(_:)),
            keyEquivalent: ""
        )
        onboardingItem.image = NSImage(systemSymbolName: "hand.wave", accessibilityDescription: nil)
        
        let aboutItem = menu.addItem(
            withTitle: "About ScreenHint",
            action: #selector(showAbout(_:)),
            keyEquivalent: ""
        )
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = menu.addItem(
            withTitle: "Quit",
            action: #selector(gameOver(_:)),
            keyEquivalent: ""
        )
        quitItem.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil)
        // TODO: Settings
        //    - whether or not to allow hints to display on all desktops
        //    - set global hotkey
        
        menu.delegate = self
        
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusBarItem.menu = menu
        
        if let button = self.statusBarItem.button {
            button.image = NSImage(named: "Icon")
        }
    }
    
    /**
     Returns true if we have permissions to capture screen information, false otherwise.
     If we don't have permissions, prompt the user to enable them in settings.
     */
    func checkForPermissions() -> Bool {
        let hasScreenAccess = CGPreflightScreenCaptureAccess();
        if (!hasScreenAccess) {
            let alert = NSAlert()
            alert.messageText = "ScreenHint needs your permission to take screenshots."
            alert.informativeText = "Go to System Preferences > Security & Privacy > Privacy, and check \"ScreenHint\" under the Screen Recording section."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Cancel")
            let shouldOpenSettings = alert.runModal() == .alertFirstButtonReturn;
            
            if (shouldOpenSettings) {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
            }
        }
        
        
        return hasScreenAccess;
    }
    
    /**
     Enter the "capture hint" mode. In this mode, we show a tinted NSWindow over every screen, and we watch for a drag gesture. The gesture marks the bounds of a rectangle which we use to make a hint. Once the gesture is done, the event monitors tear themselves down.
     */
    @objc func captureHint(_ sender: AnyObject?) {
        // If we don't have recording permissions,
        if (!self.checkForPermissions()) {
            return
        }
        
        // Show the screen capture overlays on each screen
        self.swcs.forEach({ $0.showWindow(nil); })
        
        // Set up event monitors
        self.setupMonitors()
    }
    
    /**
     Quits the app (used for the menu bar)
     */
    @objc func gameOver(_ sender: AnyObject?) {
        NSApp.terminate(nil);
    }
    
    /**
     Closes all hints.
     */
    @objc func clearHints(_ sender: AnyObject?) {
        self.hints.forEach({(rect) in
            rect.window?.close()
        })
        self.hints = []
    }
    
    /**
     Given a root SwiftUI view, put it in a window and show it. The window will resize itself based on the size of the provided view.
     */
    @discardableResult func showWindowForView<V: View>(_ view: V) -> NSWindow {
        let vc = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: vc)
        
        // Translucent window effect time wooo
        let visualEffect = NSVisualEffectView() // Effects are a view...
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .underWindowBackground
        // ...which means we need to insert them into the view hierarchy
        if let subview = window.contentView {
            visualEffect.addSubview(subview)
        }
        window.contentView = visualEffect
        
        // we also need to enable "full size content view" and disable resizing
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.remove(.resizable)
        
        // Hide the window's title and title bar
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.level = .floating
        
        // Hide everything but the close button
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true

        // Show the window
        window.makeKeyAndOrderFront(nil)
        
        // For good measure, return the window
        return window
    }
    
    @objc func showAbout(_ sender: AnyObject?) {
        showWindowForView(AboutView())
    }
    
    @objc func showSettings(_ sender: AnyObject?) {
        showWindowForView(SettingsView())
    }
    
    func endCaptureHint() {
        self.removeMonitors()
        self.swcs.forEach({(secretWindow) in
            secretWindow.setHighlightRect(nil);
            secretWindow.close()
        })

    }
    
    /**
     Set up listeners for mouse events. They're used to record the next drag gesture. Once the gesture is recorded, the monitors are removed to keep from intercepting gestures on hints as well.
     */
    func setupMonitors() {
        if (self.mouseDownMonitor == nil) {
            self.mouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { event in
                self.dragStart = NSEvent.mouseLocation
                return event
            }
        }
        
        if (self.mouseDragMonitor == nil) {
            self.mouseDragMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged]) { event in
                let rect = self.getRectForPoints(self.dragStart, NSEvent.mouseLocation);
                
                self.swcs.forEach({(secretWindow) in
                    if secretWindow.isPointInWindowScreen(self.dragStart) {
                        secretWindow.setHighlightRect(rect);
                    } else {
                        secretWindow.setHighlightRect(nil);
                    }
                })
                            
                return event
            }
        }
        
        if (self.mouseUpMonitor == nil) {
            self.mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { event in
                
                let rect = self.getRectForPoints(self.dragStart, NSEvent.mouseLocation);
                let newHint = HintWindowController(rect);
                newHint.showWindow(nil)

                newHint.finishDragging()
                self.hints.append(newHint)
                
                // Clear out closed hints when we add a new one — they currently can't be re-opened once closed.
                self.hints = self.hints.filter({ rect in
                    rect.window?.isVisible ?? false
                })
                newHint.window?.becomeFirstResponder()
                
                self.endCaptureHint()
                return event
            }
        }
        
        if (self.keyDownMonitor == nil) {
            self.keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // If escape is pressed and we are actively capturing a hint,
                // stop capturing that hint.
                if (Int(event.keyCode) == kVK_Escape) {
                    self.endCaptureHint()
                }
                
                return nil
            }
        }
        
    }
        
    /**
     Tear down our mouse event listeners if they're there, and unset them to ensure that we don't double-release them (since this is bad).
     */
    func removeMonitors() {
        if let monitor = self.mouseDownMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = self.mouseUpMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = self.mouseDragMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = self.keyDownMonitor {
            NSEvent.removeMonitor(monitor)
        }

        self.mouseDownMonitor = nil
        self.mouseUpMonitor = nil
        self.mouseDragMonitor = nil
        self.keyDownMonitor = nil
    }
    
}
