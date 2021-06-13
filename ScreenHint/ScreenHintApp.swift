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

/**
 This is an image view that passes drag events up to its parent window.
 */
class WindowDraggableImageView: NSImageView {
    
    // Without this, you have to focus on the parent window before this view
    // can be used to drag the window.
    override var mouseDownCanMoveWindow: Bool {
        get {
            return true
        }
    }
    
    override public func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
    
    override public func mouseDragged(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}



class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    
    // Views
    var statusBarItem: NSStatusItem!
    var swcs: [SecretWindowController] = []
    var about: AboutWindowController?
    
    // Mouse drag state
    var dragStart: NSPoint = NSPoint.init(x: 0, y: 0)
    var activeRect: HintWindowController?
    var hotKey: HotKey?
    
    // Mouse event monitors
    var mouseDownMonitor: Any?
    var mouseUpMonitor: Any?
    var mouseDragMonitor: Any?
    var keyDownMonitor: Any?

    
    @Published var rects: [HintWindowController] = []
    
    func generateSecretWindows() {
        // Remove existing screens
        self.swcs.forEach { swc in
            swc.close()
        }
        // TODO: Make sure monitors are unbound here
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
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        let hasScreenAccess = CGPreflightScreenCaptureAccess();
        
        // Ask for recording access if we don't have it
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
            self.generateSecretWindows()
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
                                                          object: nil,
                                                          queue: OperationQueue.main) { notification -> Void in
            // TODO: hide secret window when space is transitioning
        }
        
        // Global hotkey (hardcoded to cmd + shift + 2 for now)
        // TODO: Make this modifiable
        let hotKey = HotKey(key: .two, modifiers: [.command, .shift])
        hotKey.keyDownHandler = {
            self.captureHint(nil)
        }
        self.hotKey = hotKey
        
        // Set up the status bar menu
        let menu = NSMenu()
        menu.addItem(withTitle: "ScreenHint v1.0", action: nil, keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            withTitle: "New Hint",
            action: #selector(captureHint(_:)),
            keyEquivalent: "2"
        ).keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(
            withTitle: "Clear All Hints",
            action: #selector(clearHints(_:)),
            keyEquivalent: ""
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            withTitle: "About...",
            action: #selector(showAbout(_:)),
            keyEquivalent: ""
        )
        menu.addItem(
            withTitle: "Quit",
            action: #selector(gameOver(_:)),
            keyEquivalent: ""
        )
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
        self.swcs.forEach({ $0.showWindow(nil); })
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
        self.rects.forEach({(rect) in
            rect.window?.close()
        })
        self.rects = []
    }
    
    @objc func showAbout(_ sender: AnyObject?) {
        if (self.about == nil) {
            self.about = AboutWindowController.init()
        }
        let about = self.about!
        about.showWindow(nil)
    }
    
    func endCaptureHint() {
        self.activeRect = nil
        self.swcs.forEach({ $0.close() })
        self.removeMonitors()
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
                if (self.activeRect == nil) {
                    self.activeRect = HintWindowController(rect);
                    self.activeRect!.showWindow(nil)
                }
                self.activeRect!.setRect(rect)
                            
                return event
            }
        }
        
        if (self.mouseUpMonitor == nil) {
            self.mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { event in
                
                let rect = self.getRectForPoints(self.dragStart, NSEvent.mouseLocation);
                if (self.activeRect != nil) {
                    self.activeRect!.setRect(rect)
                    self.activeRect!.finishDragging()
                    self.rects.append(self.activeRect!)
                    
                    // Clear out closed hints when we add a new one — they currently can't be re-opened once closed.
                    self.rects = self.rects.filter({ rect in
                        rect.window?.isVisible ?? false
                    })
                    self.activeRect!.window?.becomeFirstResponder()
                    
                }
                self.endCaptureHint()
                return event
            }
        }
        
        if (self.keyDownMonitor == nil) {
            self.keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // If escape is pressed and we are actively capturing a hint,
                // stop capturing that hint.
                if (Int(event.keyCode) == kVK_Escape) {
                    self.activeRect?.close()
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

@main
struct ScreenHintApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
