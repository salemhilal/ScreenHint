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
class WindowDraggableImageView: NSImageView{
    override public func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

protocol CopyDelegate {
    func shouldCopy();
}

/**
 This is a window that closes when you doubleclick it.
 */
class HintWindow: NSWindow {
    
    var copyDelegate: CopyDelegate?
    var screenshot: CGImage? = nil
    
    override var canBecomeKey: Bool {
        get {
            return true
        }
    }
    
    override var canBecomeMain: Bool {
        get {
            return true
        }
    }
    
    override func keyDown(with event: NSEvent) {
        if (event.charactersIgnoringModifiers == "c" && event.modifierFlags.contains(.command)) {
            self.copyDelegate?.shouldCopy()
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        // If this window is double-clicked (anywhere), close it.
        if event.clickCount >= 2 {
            self.close()
        }
        super.mouseUp(with: event)
    }
}

class AboutWindowController: NSWindowController, NSWindowDelegate {
    init() {
        let width: CGFloat = 324;
        let height: CGFloat = 200;
        // Unlike in other places, we actually mean the main screen.
        // This window is going to show up wherever the keyboard is focused to,
        // so we want it to render in the center of that.
        let screenFrame = NSScreen.main!.frame;
        
        let aboutRect = NSRect(
            x: screenFrame.width / 2 - (width / 2),
            y: screenFrame.height / 2 - (height / 2),
            width: width,
            height: height
        )
        let window = NSWindow(contentRect: aboutRect, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.level = .floating
        window.isMovable = true
        
        let contentView = AboutView()
        let view = NSHostingView(rootView: contentView)
        view.frame = NSRect(x: 0, y: 0, width: width, height: height);
        window.contentView?.addSubview(view)
        
        super.init(window: window)
        window.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/**
 This is a hidden window that we display on every screen when the global shortcut is pressed.
 It captures mouse events so that you don't highlight or drag stuff when making a hint.
 */
class SecretWindowController: NSWindowController, NSWindowDelegate {
    init(_ screen: NSScreen) {
        let secretWindow = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        secretWindow.backgroundColor = NSColor.blue
        secretWindow.isOpaque = false
        secretWindow.alphaValue = 0.2
        secretWindow.level = .screenSaver
        secretWindow.ignoresMouseEvents = false
        secretWindow.isMovable = false
        secretWindow.collectionBehavior = [.stationary, .transient, .canJoinAllSpaces]
        
        super.init(window: secretWindow)
        secretWindow.delegate = self
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

class HintWindowController:  NSWindowController, NSWindowDelegate, CopyDelegate {
    func shouldCopy() {
        guard let screenshot = self.screenshot else {
            return
        }
        
        let image = NSImage.init(cgImage: screenshot, size: self.window!.frame.size)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }
    
    var screenshot: CGImage?
        
    init(_ rect: NSRect) {
        // TODO: when the window's origin changes (i.e. when dragging from top-right
        //       to bottom-left), the window jitters sliglty.
        let window = HintWindow(contentRect: rect, styleMask: [.resizable], backing: .buffered, defer: false)
        window.isOpaque = false
        window.level = .screenSaver
        window.backgroundColor = NSColor.blue
        window.alphaValue = 0.2
        window.ignoresMouseEvents = false
        window.isMovableByWindowBackground = true
        window.isMovable = true
        window.hasShadow = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.borderWidth = 1
        window.contentView?.layer?.borderColor = CGColor.black
        
        // TODO: Make this configurable
        window.collectionBehavior = [.canJoinAllSpaces]

        super.init(window: window)
        window.delegate = self
        window.copyDelegate = self
    }
    
    override func keyDown(with event: NSEvent) {
        if (event.charactersIgnoringModifiers == "c" && event.modifierFlags.contains(.command)) {
            print("WINDOW CONTROLLER TIME \(event.modifierFlags)")
        }
    }
    
    func setRect(_ rect: NSRect) {
        self.window?.setFrame(rect, display: true, animate: false)
    }
    
    func finishDragging() {
        // "The origin point of a rectangle is at its bottom left in Quartz/Cocoa on OS X."
        // but that's not true for the rect passed to CGWindowListCreateImage
        // https://stackoverflow.com/a/12438416/444912
        guard let window = self.window else {
            return;
        }
        
        // omg this was so dumb but the main screen is NOT the first screen.
        // the coordinates are all relative to the _first_ screen. jesus f christ lol
        // TODO: this, in its own function, with tests.
        let screen = NSScreen.screens[0];
        let screenHeight = screen.frame.height
        let windowRect = window.frame;
        let screenshotRect = NSRect(
            x: windowRect.minX,
            y: screenHeight - windowRect.minY - windowRect.height,
            width: windowRect.width,
            height: windowRect.height)
        
        
        // Make sure the window keeps its aspect ratio when resizing
        window.aspectRatio = window.frame.size
        window.alphaValue = 0.0
        window.backgroundColor = NSColor.clear
        
        // Wait a split second for the hint's blue background to be removed
        // before taking the screenshot
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let screenshot = CGWindowListCreateImage(screenshotRect,
                                                     CGWindowListOption.optionAll,
                                                     kCGNullWindowID,
                                                     CGWindowImageOption.bestResolution)!
            
            let image = NSImage(cgImage:screenshot, size: .zero)
            let imageView = WindowDraggableImageView(frame: NSRect(origin: .zero, size: self.window!.frame.size))
            imageView.image = image
            // Make sure the image fills the window
            imageView.autoresizingMask = [.height, .width]
            
            self.window?.alphaValue = 1.0
            self.window?.level = .floating
            self.window?.isOpaque = true
            self.window?.contentView?.addSubview(imageView)
            self.screenshot = screenshot
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

func getRectForPoints(_ first: NSPoint, _ second: NSPoint) -> NSRect {
    let x = min(first.x, second.x)
    let y = min(first.y, second.y)
    let width = abs(first.x - second.x)
    let height = abs(first.y - second.y)
    
    return NSRect.init(x:x, y:y, width:width, height:height)
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
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // Generate secret windows, now and any time the screen configuration changes
        self.generateSecretWindows()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: NSApplication.shared,
                                               queue: OperationQueue.main) {
            notification -> Void in
            print("screen parameters changed")
            self.generateSecretWindows()
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
                                                          object: nil,
                                                          queue: OperationQueue.main) { notification -> Void in
            // TODO: hide secret window when space is transitioning
        }
        
        // Global hotkey (hardcoded to cmd + shift + 1 for now)
        // TODO: Make this modifiable
        let hotKey = HotKey(key: .one, modifiers: [.command, .shift])
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
            keyEquivalent: "1"
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
     Enter the "capture hint" mode. In this mode, we show a tinted NSWindow over every screen, and we watch for a drag gesture. The gesture marks the bounds of a rectangle which we use to make a hint. Once the gesture is done, the event monitors tear themselves down.
     */
    @objc func captureHint(_ sender: AnyObject?) {
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
                let rect = getRectForPoints(self.dragStart, NSEvent.mouseLocation);
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
                
                let rect = getRectForPoints(self.dragStart, NSEvent.mouseLocation);
                if (self.activeRect != nil) {
                    self.activeRect!.setRect(rect)
                    self.activeRect!.finishDragging()
                    self.rects.append(self.activeRect!)
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
                print("CAPTURED \(event.keyCode)")
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
