//
//  HintWindowController.swift
//  ScreenHint
//
//  Created by Salem on 6/13/21.
//

import Foundation
import AppKit
import SwiftUI


protocol CopyDelegate {
    func shouldCopy();
}


/**
 This is a window that closes when you doubleclick it.
 */
class HintWindow: NSWindow {
    
    var copyDelegate: CopyDelegate?
    var screenshot: CGImage? = nil

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect:contentRect, styleMask:style, backing:backingStoreType, defer: flag)
        self.isOpaque = false
        self.level = .screenSaver
        self.backgroundColor = NSColor.blue
        self.alphaValue = 0.2
        self.alphaValue = 0.0
        self.ignoresMouseEvents = false
        self.isMovableByWindowBackground = true
        self.isMovable = true
        self.hasShadow = true
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.borderWidth = 1
        self.contentView?.layer?.borderColor = CGColor.black
        // Causes a fast fade-out (at least at time of writing)
        self.animationBehavior = .utilityWindow

    }
    
    override var canBecomeKey: Bool {
        get {
            return true
        }
    }
    
    override var canBecomeMain: Bool {
        get {
            return false
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
            // TODO: remove self from rects array
            self.windowController?.close();
        }
        super.mouseUp(with: event)
    }
    
    func shouldPinToDesktop(_ shouldPin: Bool) {
        self.collectionBehavior = shouldPin ? [.managed] : [.canJoinAllSpaces]
    }
}


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

class HintWindowController:  NSWindowController, NSWindowDelegate, CopyDelegate, NSMenuDelegate {
    
    var allDesktopsMenuItem: NSMenuItem?
    var screenshot: CGImage?
    @AppStorage("pinToScreen") private var pinToScreen = false
        
    init(_ rect: NSRect) {
        // TODO: when the window's origin changes (i.e. when dragging from top-right
        //       to bottom-left), the window jitters sliglty.
        let window = HintWindow(contentRect: rect, styleMask: [.resizable], backing: .buffered, defer: false)
    
        super.init(window: window)
        
        if (self.pinToScreen) {
            window.collectionBehavior = [.managed]
        } else {
            window.collectionBehavior = [.canJoinAllSpaces]
        }
        
        window.delegate = self
        window.copyDelegate = self
        let menu = NSMenu()
        
        let copyItem = menu.addItem(withTitle: "Copy", action:#selector(self.menuCopyHandler(_:)), keyEquivalent: "")
        copyItem.keyEquivalentModifierMask = [.command]
        copyItem.target = self
        
        
        let showItem = menu.addItem(withTitle: "Show On All Desktops", action:#selector(self.menuShowOnAllDesktopsHandler(_:)),
                                                keyEquivalent: "")
        showItem.state = self.pinToScreen ? .off : .on
        showItem.target = self
        self.allDesktopsMenuItem = showItem
        
        menu.addItem(NSMenuItem.separator())
        
        let closeItem = menu.addItem(withTitle: "Close", action: #selector(self.menuCloseHandler(_:)), keyEquivalent: "");
        closeItem.target = self

        
        window.menu = menu
    }
    
    func shouldCopy() {
        guard let screenshot = self.screenshot else {
            return
        }
        
        let image = NSImage.init(cgImage: screenshot, size: self.window!.frame.size)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }
    
    @objc func menuCopyHandler(_ sender: AnyObject?) {
        self.shouldCopy()
    }
    
    @objc func menuShowOnAllDesktopsHandler(_ sender: AnyObject?) {
        let oldState = self.allDesktopsMenuItem?.state;
        let newState: NSControl.StateValue = oldState == .on ? .off : .on;
        self.allDesktopsMenuItem?.state = newState;
        
        if let hintWindow = self.window as? HintWindow {
            hintWindow.shouldPinToDesktop(newState != .on)
        }
    }
    
    @objc func menuCloseHandler(_ sender: AnyObject?) {
        self.close()
    }
    
    
    override func rightMouseUp(with event: NSEvent) {
        let point = NSEvent.mouseLocation;
        self.window!.menu?.popUp(positioning: nil, at: point, in: nil)
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

