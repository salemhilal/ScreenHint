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
import ApplicationServices
import os


class ScreenHintAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    
    // Status bar item
    var statusBarItem: NSStatusItem!
    
    // Secret Windows
    var swcs: [SecretWindowController] = []
    
    // Held so the menu can pause the (legacy) HotKey binding while it's open.
    var hotKey: HotKey?

    // Carbon hotkey used to cancel an in-progress capture with the Escape key. We use a
    // Carbon hotkey (rather than an NSEvent monitor or a key window) because it's
    // consumed system-wide without our overlay taking key focus — taking key focus would
    // dismiss the very hover UI we're trying to preserve.
    private var escapeHotKeyRef: EventHotKeyRef?
    private var escapeHandlerRef: EventHandlerRef?
    private let escapeHotKeySignature: OSType = 0x53_48_45_53 // 'SHES'

    // Event-tap capture state. The tap swallows mouse events so the app underneath keeps
    // its hover UI; we drive a virtual cursor + selection from the swallowed deltas. See
    // the hover-preserving-capture note for why this (not a window overlay) is required.
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var captureWatchdog: Timer?

    // Scales the raw (unaccelerated) tap deltas into cursor movement. Tune to taste;
    // lower feels slower. 1.0 is raw device speed (very fast).
    private static let cursorSensitivity: CGFloat = 0.5

    // Selection state, all in global (bottom-left origin) screen coordinates.
    private var virtualCursor: NSPoint = .zero
    private var dragAnchor: NSPoint?
    private var currentSelection: NSRect?

    // Union of all screen frames, used to clamp the virtual cursor.
    private var screensBounds: NSRect = .zero

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
//        self.generateSecretWindows()
//        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
//                                               object: NSApplication.shared,
//                                               queue: OperationQueue.main) {
//            notification -> Void in
//            // TODO: Don't do this, just make secret windows when someone presses the shortcut. this seems to be called all the time.
//            self.generateSecretWindows()
//        }
        
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
                                                          object: nil,
                                                          queue: OperationQueue.main) { notification -> Void in
            // TODO: Cancel getting hint when changing spaces
        }
        
        // Bind global keyboard shortcut for making hints
        KeyboardShortcuts.onKeyUp(for: .createNewHint) { [self] in
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
     Enter "capture hint" mode.

     We show a transparent, click-through overlay on each screen and install a
     session-level `CGEventTap` that *swallows* mouse events. Because the app underneath
     then receives no mouse events, it keeps its hover UI (tooltips, `:hover`, popovers)
     exactly as it was when the shortcut fired. Swallowing moves also freezes the real
     cursor, so we integrate the swallowed deltas into a virtual cursor and draw our own
     crosshair; the drag's mouse-up defines the region we capture.
     */
    @objc func captureHint(_ sender: AnyObject?) {
        // If we don't have recording permissions, bail.
        if (!self.checkForPermissions()) {
            return
        }

        // Don't start a second capture on top of one already in progress.
        guard self.swcs.isEmpty else {
            return
        }

        // Preserving hover requires a swallowing event tap, which needs Accessibility.
        // Don't gate on AXIsProcessTrusted() — it can read false even when the tap works
        // (e.g. under Xcode). Instead, try to create the tap; if that fails, prompt for
        // Accessibility and bail.
        guard self.startEventTap() else {
            _ = self.hasAccessibilityPermission(prompt: true)
            return
        }

        // Seed the virtual cursor at the real cursor and reset selection state.
        self.virtualCursor = NSEvent.mouseLocation
        self.dragAnchor = nil
        self.currentSelection = nil
        self.screensBounds = NSScreen.screens.reduce(NSRect.zero) { $0.union($1.frame) }

        // Show a cosmetic overlay on each screen.
        NSScreen.screens.forEach { screen in
            let swc = SecretWindowController(screen)
            self.swcs.append(swc)
            swc.present()
        }
        self.updateOverlays()

        // Escape cancels; a watchdog force-ends if the tap ever wedges, so input can't be
        // swallowed indefinitely. It's generous so it never interrupts a real selection.
        self.registerEscapeHotKey()
        self.captureWatchdog = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in
            self?.endCaptureHint()
        }
    }

    /// Whether the app is trusted for Accessibility. When `prompt` is true and it isn't,
    /// the system shows its own "grant Accessibility" dialog.
    private func hasAccessibilityPermission(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    /// Install and enable the swallowing session event tap. Returns false if it couldn't
    /// be created.
    private func startEventTap() -> Bool {
        let mask: CGEventMask =
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let delegate = Unmanaged<ScreenHintAppDelegate>.fromOpaque(userInfo).takeUnretainedValue()
            return delegate.handleTapEvent(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .defaultTap,
                                          eventsOfInterest: mask,
                                          callback: callback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.eventTap = tap
        self.eventTapSource = source
        return true
    }

    /**
     Handle one event from the tap (runs on the main thread, since the tap's run-loop
     source is on the main run loop). Returns nil to swallow the event, or the event to
     let it pass. Mouse move/drag/down/up are swallowed and drive the selection.
     */
    private func handleTapEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // The system can disable a slow/hijacked tap; re-enable it.
            if let tap = self.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)

        case .mouseMoved, .leftMouseDragged:
            // The cursor is frozen while we swallow moves, so event.location doesn't
            // advance — we have to integrate the deltas ourselves. These deltas are raw
            // (unaccelerated), so scale them down or the cursor feels hypersensitive.
            let dx = event.getDoubleValueField(.mouseEventDeltaX) * Self.cursorSensitivity
            let dy = event.getDoubleValueField(.mouseEventDeltaY) * Self.cursorSensitivity
            // CGEvent deltaY is top-left-origin (down positive); Cocoa y is bottom-left.
            self.virtualCursor = self.clampToScreens(NSPoint(x: self.virtualCursor.x + dx,
                                                             y: self.virtualCursor.y - dy))
            // Move the (otherwise frozen) real cursor to follow. Warping doesn't post a
            // mouse event, so the app underneath still sees no movement and keeps hover.
            CGWarpMouseCursorPosition(self.cgPoint(fromCocoa: self.virtualCursor))
            if let anchor = self.dragAnchor {
                self.currentSelection = Self.rect(from: anchor, to: self.virtualCursor)
            }
            self.updateOverlays()
            return nil

        case .leftMouseDown:
            self.dragAnchor = self.virtualCursor
            self.currentSelection = .zero
            self.updateOverlays()
            return nil

        case .leftMouseUp:
            let anchor = self.dragAnchor
            self.dragAnchor = nil
            let selection = anchor.map { Self.rect(from: $0, to: self.virtualCursor) }
            // Do the capture/teardown on the next run-loop turn so we don't remove the
            // tap's own source from inside its callback.
            DispatchQueue.main.async { self.finishSelection(selection) }
            return nil

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    /// Push the current selection to every overlay for drawing.
    private func updateOverlays() {
        let selection = self.currentSelection
        self.swcs.forEach { $0.update(selection: selection) }
    }

    /// Convert a global Cocoa point (bottom-left origin) to Core Graphics global
    /// coordinates (top-left origin), for cursor warping.
    private func cgPoint(fromCocoa point: NSPoint) -> CGPoint {
        let mainHeight = CGDisplayBounds(CGMainDisplayID()).height
        return CGPoint(x: point.x, y: mainHeight - point.y)
    }

    private func clampToScreens(_ point: NSPoint) -> NSPoint {
        let bounds = self.screensBounds
        return NSPoint(x: min(max(point.x, bounds.minX), bounds.maxX),
                       y: min(max(point.y, bounds.minY), bounds.maxY))
    }

    private static func rect(from a: NSPoint, to b: NSPoint) -> NSRect {
        NSRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    /**
     Finish a selection: if it's big enough, capture that region into a hint. Capture runs
     while the tap is still active (so the app below is still frozen and its hover UI is
     intact), then we tear everything down.
     */
    private func finishSelection(_ selection: NSRect?) {
        guard let selection,
              selection.width > Constants.minHintDimension,
              selection.height > Constants.minHintDimension,
              let screen = NSScreen.screens.first(where: { $0.frame.contains(NSPoint(x: selection.midX, y: selection.midY)) })
                        ?? NSScreen.screens.first(where: { $0.frame.intersects(selection) }) else {
            self.endCaptureHint()
            return
        }

        Task { @MainActor in
            defer { self.endCaptureHint() }
            do {
                let image = try await HintWindowController.captureImage(of: selection, on: screen)
                let hint = HintWindowController(selection, screenshot: image)
                hint.showWindow(nil)
                hint.window?.becomeFirstResponder()
                self.hints.append(hint)
                // Drop any hints that have since been closed — they can't be reopened.
                self.hints = self.hints.filter { $0.window?.isVisible ?? false }
            } catch {
                print("Failed to capture screenshot: \(error)")
            }
        }
    }

    /**
     Register a system-wide Escape hotkey that cancels the current capture. It's consumed
     while registered (so the app underneath doesn't see the Escape either) and torn down
     in `endCaptureHint`.
     */
    private func registerEscapeHotKey() {
        guard self.escapeHotKeyRef == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData, let event else { return noErr }

            // Only respond to our own Escape hotkey, not any other Carbon hotkey.
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)

            let delegate = Unmanaged<ScreenHintAppDelegate>.fromOpaque(userData).takeUnretainedValue()
            if hotKeyID.signature == delegate.escapeHotKeySignature {
                DispatchQueue.main.async { delegate.endCaptureHint() }
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &self.escapeHandlerRef)

        let hotKeyID = EventHotKeyID(signature: self.escapeHotKeySignature, id: 1)
        RegisterEventHotKey(UInt32(kVK_Escape), 0, hotKeyID,
                            GetApplicationEventTarget(), 0, &self.escapeHotKeyRef)
    }

    private func unregisterEscapeHotKey() {
        if let ref = self.escapeHotKeyRef {
            UnregisterEventHotKey(ref)
            self.escapeHotKeyRef = nil
        }
        if let handler = self.escapeHandlerRef {
            RemoveEventHandler(handler)
            self.escapeHandlerRef = nil
        }
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
        // As of the macOS 14 SDK, NSHostingController no longer sizes its window from the
        // SwiftUI content unless we ask it to. Without this the window collapses to ~0pt.
        vc.sizingOptions = [.preferredContentSize]

        let window = NSWindow(contentViewController: vc)

        // The size the SwiftUI content wants; fall back to a sane default if it's empty.
        var contentSize = vc.view.fittingSize
        if contentSize.width < 1 || contentSize.height < 1 {
            contentSize = NSSize(width: 420, height: 320)
        }

        // Translucent window effect time wooo
        let visualEffect = NSVisualEffectView(frame: NSRect(origin: .zero, size: contentSize))
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .underWindowBackground
        // ...which means we need to insert them into the view hierarchy
        if let subview = window.contentView {
            subview.frame = visualEffect.bounds
            subview.autoresizingMask = [.width, .height]
            visualEffect.addSubview(subview)
        }
        window.contentView = visualEffect
        window.setContentSize(contentSize)

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

        // Show the window. An accessory (menu-bar) app has to activate to bring a normal
        // window to the front.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        // For good measure, return the window
        return window
    }

    @objc func showAbout(_ sender: AnyObject?) {
        showWindowForView(AboutView())
    }

    @objc func showSettings(_ sender: AnyObject?) {
        showWindowForView(SettingsView())
    }
    
    /**
     Tear down a capture: disable and remove the event tap, restore the cursor, order out
     the overlays, and clear state. Safe to call more than once and from any exit path
     (finish, cancel, watchdog, termination).
     */
    func endCaptureHint() {
        self.captureWatchdog?.invalidate()
        self.captureWatchdog = nil

        if let tap = self.eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = self.eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        self.eventTap = nil
        self.eventTapSource = nil

        self.unregisterEscapeHotKey()

        self.swcs.forEach { $0.close() }
        self.swcs = []

        self.dragAnchor = nil
        self.currentSelection = nil
    }

    // Belt-and-suspenders: never leave the cursor hidden or the tap live on quit.
    func applicationWillTerminate(_ notification: Notification) {
        self.endCaptureHint()
    }

}
