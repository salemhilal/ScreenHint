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

class SecretWindowController: NSWindowController, NSWindowDelegate {
    init() {
        let secretWindow = NSWindow(contentRect: NSScreen.main!.frame, styleMask: .borderless, backing: .buffered, defer: false)
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
        // TODO: the image in the window isn't stretching to fit
        // TODO: the window isn't sticking to its initial aspect ratio
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
        
        window.alphaValue = 0.0
        window.backgroundColor = NSColor.clear
        window.display()
        
        // Wait a split second for the window's blue background to be removed
        // before taking the screenshot
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let screenshot = CGWindowListCreateImage(screenshotRect, CGWindowListOption.optionAll, kCGNullWindowID, CGWindowImageOption.bestResolution)!
            let image = NSImage(cgImage:screenshot, size: .zero)
            let imageView = WindowDraggableImageView(frame: NSRect(origin: .zero, size: self.window!.frame.size))
            imageView.image = image
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
    var wc: SecretWindowController!
    
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
        self.wc = SecretWindowController()
        
        let hotKey = HotKey(key: .six, modifiers: [.command, .option])
        hotKey.keyDownHandler = {
            print("Got hotkey at \(Date())")
            // TODO : show a secret window on every monitor
            // TODO : capture mouse events and keep them from propagating
            self.wc.showWindow(nil)
            self.setupMonitors()
            
        }
        self.hotKey = hotKey
        
        
        let contentView = ContentView().environmentObject(self)
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        self.popover = popover
        
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        
        if let button = self.statusBarItem.button {
            button.image = NSImage(named: "Icon")
            button.action = #selector(togglePopover(_:))
        }
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
     Set up listeners for mouse events. They're used to record the next drag gesture, after which
     point, they are removed.
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
            self.wc.close()
            
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
