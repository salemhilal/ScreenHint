//
//  ScreenHintApp.swift
//  ScreenHint
//
//  Created by Salem on 5/1/21.
//

import SwiftUI
import AppKit
import HotKey

/**
 This is an image view that passes drag events up to its parent window.
 */
class WindowDraggableImageView: NSImageView{
    override public func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

/**
 This is a window that closes when you doubleclick it.
 */
class HintWindow: NSWindow {
    override func mouseUp(with event: NSEvent) {
        // If this window is double-clicked (anywhere), close it.
        if event.clickCount >= 2 {
            self.close()
        }
        super.mouseUp(with: event)
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
        secretWindow.level = .floating
        secretWindow.ignoresMouseEvents = false
        secretWindow.isMovable = false
        
        super.init(window: secretWindow)
        secretWindow.delegate = self
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class RectController:  NSWindowController, NSWindowDelegate {
    
    init(_ rect: NSRect) {
        // TODO: when the window's origin changes (i.e. when dragging from top-right
        //       to bottom-left), the window jitters sliglty.
        let window = HintWindow(contentRect: rect, styleMask: [.resizable, .docModalWindow], backing: .buffered, defer: false)
        window.isOpaque = false
        window.level = .floating
        window.backgroundColor = NSColor.blue
        window.alphaValue = 0.2
        window.ignoresMouseEvents = false
        window.isMovableByWindowBackground = true
        window.isMovable = true
        window.hasShadow = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.borderWidth = 1
        window.contentView?.layer?.borderColor = CGColor.black
        
        super.init(window: window)
        window.delegate = self
    }
    
    func setRect(_ rect: NSRect) {
        self.window?.setFrame(rect, display: true)
    }
    
    func finishDragging() {
        // "The origin point of a rectangle is at its bottom left in Quartz/Cocoa on OS X."
        // but that's not true for the rect passed to CGWindowListCreateImage
        // https://stackoverflow.com/a/12438416/444912
        guard let window = self.window else {
            return;
        }
        let screenHeight = NSScreen.main!.frame.height
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
        window.display()
        
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
            // Make sure the image fills the iwndow
            imageView.autoresizingMask = [.height, .width]
            
            self.window?.alphaValue = 1.0
            self.window?.isOpaque = true
            self.window?.contentView?.addSubview(imageView)
            
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

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    
    // Views
    var popover: NSPopover!
    var statusBarItem: NSStatusItem!
    var swcs: [SecretWindowController] = []
    
    // Mouse drag state
    var dragStart: NSPoint = NSPoint.init(x: 0, y: 0)
    var activeRect: RectController?
    var hotKey: HotKey?
    
    // Mouse event monitors
    var mouseDownMonitor: Any?
    var mouseUpMonitor: Any?
    var mouseDragMonitor: Any?
    
    @Published var rects: [RectController] = []
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // make a secret window for each screen. These will
        // capture mouse events for us when making a new hint.
        NSScreen.screens.forEach { screen in
            self.swcs.append(SecretWindowController(screen))
        }
        
        // Global hotkey (hardcoded to cmd + opt + 6 for now)
        // TODO: Make this modifiable
        let hotKey = HotKey(key: .six, modifiers: [.command, .option])
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
            keyEquivalent: ""
        )
        menu.addItem(
            withTitle: "Clear All Hints",
            action: #selector(clearHints(_:)),
            keyEquivalent: ""
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            withTitle: "About...",
            action: #selector(doMenuItem(_:)),
            keyEquivalent: ""
        )
        menu.addItem(
            withTitle: "Quit",
            action: #selector(gameOver(_:)),
            keyEquivalent: ""
        )

        self.statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusBarItem.menu = menu
        
        if let button = self.statusBarItem.button {
            button.image = NSImage(named: "Icon")
        }
    }
    
    @objc func doMenuItem(_ sender: AnyObject?) {
        print("HEYOOO")
    }
    
    /**
     Displays or hides the status bar popover.
     */
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = self.statusBarItem.button {
            if self.popover.isShown {
                self.popover.performClose(sender)
            } else {
                self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                self.popover.contentViewController?.view.window?.becomeKey()
            }
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
    
    /**
     Set up listeners for mouse events. They're used to record the next drag gesture. Once the gesture is recorded, the monitors are removed to keep from intercepting gestures on hints as well.
     */
    func setupMonitors() {
        self.mouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { event in
            self.dragStart = NSEvent.mouseLocation
            return event
        }
        self.mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { event in
            
            let rect = getRectForPoints(self.dragStart, NSEvent.mouseLocation);
            if (self.activeRect != nil) {
                self.activeRect!.setRect(rect)
                self.activeRect!.finishDragging()
                self.rects.append(self.activeRect!)
                
            }
            self.activeRect = nil
            self.swcs.forEach({$0.close()})
            
            // Release monitors, making sure not to double-release them
            // (since apparently that's bad)
            if (self.mouseDownMonitor != nil) {
                NSEvent.removeMonitor(self.mouseDownMonitor!)
                self.mouseDownMonitor = nil
            }
            if (self.mouseUpMonitor != nil) {
                NSEvent.removeMonitor(self.mouseUpMonitor!)
                self.mouseUpMonitor = nil
            }
            if (self.mouseDragMonitor != nil) {
                NSEvent.removeMonitor(self.mouseDragMonitor!)
                self.mouseDragMonitor = nil
            }
            return event
        }
        self.mouseDragMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged]) { event in
            // TODO: Because we use .floating for everything, the nav bar can't
            // be screenshot (since the rect we are drawng can't be put in front of the menu bar).
            // We either have to somehow include the menu bar _or_ factor that in when calculating
            // this rect.
            let menuBarHeigth = NSApplication.shared.mainMenu?.menuBarHeight ?? 0
            let rect = getRectForPoints(self.dragStart, NSEvent.mouseLocation);
            if (self.activeRect == nil) {
                self.activeRect = RectController(rect);
                self.activeRect!.showWindow(nil)
            }
            self.activeRect!.setRect(rect)
            return event
        }
        
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
