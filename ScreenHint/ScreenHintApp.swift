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

class RectController:  NSWindowController, NSWindowDelegate {
    // TODO: Get rid of this, derive it from the window's frame if we need it
    var rect: NSRect
    
    init(_ rect: NSRect) {
        self.rect = rect
        let window = HintWindow(contentRect: rect, styleMask: [.resizable, .docModalWindow], backing: .buffered, defer: false)
        window.isOpaque = false
        window.level = .floating
        window.backgroundColor = NSColor.blue
        window.alphaValue = 0.2
        window.ignoresMouseEvents = false
        window.isMovableByWindowBackground = true
        window.isMovable = true
        window.hasShadow = true
        super.init(window: window)
        window.delegate = self
    }
    
    func setRect(_ rect: NSRect) {
        self.rect = rect
        self.window?.setFrame(rect, display: true)
    }
    
    func finishDragging() {
        // "The origin point of a rectangle is at its bottom left in Quartz/Cocoa on OS X."
        // but that's not true for the rect passed to CGWindowListCreateImage
        // https://stackoverflow.com/a/12438416/444912
        let screenHeight = NSScreen.main!.frame.height
        let rect = NSRect(
            x: self.rect.minX,
            y: screenHeight - self.rect.minY - self.rect.height,
            width: self.rect.width,
            height: self.rect.height)
        
        self.window?.alphaValue = 0.0
        self.window?.backgroundColor = NSColor.clear
        self.window?.display()
        
        // Wait a split second for the window's blue background to be removed
        // before taking the screenshot
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let screenshot = CGWindowListCreateImage(rect, CGWindowListOption.optionAll, kCGNullWindowID, CGWindowImageOption.bestResolution)!
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
    
    var popover: NSPopover!
    var statusBarItem: NSStatusItem!
    var mouseLocation: NSPoint = NSPoint.init(x: 0, y: 0)
    var isDragging = false
    var dragStart: NSPoint = NSPoint.init(x: 0, y: 0)
    var dragEnd: NSPoint = NSPoint.init(x: 0, y: 0)
    var activeRect: RectController?
    var hotKey: HotKey?
    @Published var rects: [RectController] = []
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { _ in
            self.mouseLocation = NSEvent.mouseLocation
            self.dragStart = NSEvent.mouseLocation
        }
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { _ in
            self.mouseLocation = NSEvent.mouseLocation
            self.dragEnd = NSEvent.mouseLocation
            
            let rect = getRectForPoints(self.dragStart, self.dragEnd);
            if (self.activeRect != nil) {
                self.activeRect!.setRect(rect)
                self.activeRect!.finishDragging()
                self.rects.append(self.activeRect!)
                
            }
            self.activeRect = nil
        }
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { _ in
            self.mouseLocation = NSEvent.mouseLocation
            let rect = getRectForPoints(self.dragStart, self.mouseLocation);
            if (self.activeRect == nil) {
                self.activeRect = RectController(rect);
                self.activeRect!.showWindow(nil)
            }
            self.activeRect!.setRect(rect)
        }
        
        let hotKey = HotKey(key: .six, modifiers: [.command, .option])
        hotKey.keyDownHandler = {
            print("Got hotkey at \(Date())")
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
