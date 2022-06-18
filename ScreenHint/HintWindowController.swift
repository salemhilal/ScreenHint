//
//  HintWindowController.swift
//  ScreenHint
//
//  Created by Salem on 6/13/21.
//

import Foundation
import AppKit
import SwiftUI
import Vision


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
    
    func setBorderlessMode(_ isEnabled: Bool) {
        if isEnabled {
            self.hasShadow = false
            self.contentView?.layer?.borderWidth = 0
        } else {
            self.hasShadow = true
            self.contentView?.layer?.borderWidth = 1
        }
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
    
    var hintWindow: HintWindow
    var screenshot: CGImage?
    
    var allDesktopsMenuItem: NSMenuItem?
    var borderlessModeMenuItem: NSMenuItem?
    
    @AppStorage("pinToScreen") private var pinToScreen = false
    var isBorderless = false
        
    init(_ rect: NSRect) {
        let window = HintWindow(contentRect: rect, styleMask: [.resizable], backing: .buffered, defer: false)
    
        self.hintWindow = window
        super.init(window: window)
        
        if (self.pinToScreen) {
            window.collectionBehavior = [.managed]
        } else {
            window.collectionBehavior = [.canJoinAllSpaces]
        }
        
        window.setBorderlessMode(self.isBorderless)
        
        window.delegate = self
        window.copyDelegate = self
        let menu = NSMenu()
        
        let copyItem = menu.addItem(withTitle: "Copy", action:#selector(self.menuCopyHandler(_:)), keyEquivalent: "")
        copyItem.keyEquivalentModifierMask = [.command]
        copyItem.target = self
        
        let copyTextItem = menu.addItem(withTitle: "Copy Text", action:#selector(self.menuCopyTextHandler(_:)), keyEquivalent: "")
        copyTextItem.keyEquivalentModifierMask = [.command]
        copyTextItem.target = self
        
        let borderlessModeItem = menu.addItem(withTitle: "Borderless Mode", action:#selector(self.borderlessModeHandler(_:)), keyEquivalent: "")
        borderlessModeItem.keyEquivalentModifierMask = [.command]
        borderlessModeItem.target = self
        borderlessModeItem.state = self.isBorderless ? .on : .off
        self.borderlessModeMenuItem = borderlessModeItem

                                              
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
    
    // --- Handlers ---
    
    @objc func menuCopyTextHandler(_ sender: AnyObject?) {
        self.shouldCopyText()
    }
    
    @objc func menuCopyHandler(_ sender: AnyObject?) {
        self.shouldCopy()
    }
                                              
    @objc func borderlessModeHandler(_ sender: AnyObject?) {
        self.shouldToggleBorderlessMode()
    }
    
    @objc func menuShowOnAllDesktopsHandler(_ sender: AnyObject?) {
        self.shouldToggleAllDesktops()
    }
    
    @objc func menuCloseHandler(_ sender: AnyObject?) {
        self.close()
    }
    
    
    func shouldToggleBorderlessMode() {
        self.isBorderless = !self.isBorderless
        self.hintWindow.setBorderlessMode(self.isBorderless)
        self.borderlessModeMenuItem?.state = self.isBorderless ? .on : .off
    }
    
    func shouldCopy() {
        guard let screenshot = self.screenshot else {
            return
        }
        
        let image = NSImage.init(cgImage: screenshot, size: self.window!.frame.size)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }
    
    func shouldToggleAllDesktops() {
        let oldState = self.allDesktopsMenuItem?.state;
        let newState: NSControl.StateValue = oldState == .on ? .off : .on;
        self.allDesktopsMenuItem?.state = newState;
        
        if let hintWindow = self.window as? HintWindow {
            hintWindow.shouldPinToDesktop(newState != .on)
        }
    }
    
    func shouldCopyText() {
        guard let cgImage = self.screenshot else { return }
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        do {
            try requestHandler.perform([request])
        } catch {
            print("Unable to perform the requests: \(error).")
        }
    }
    
    func recognizeTextHandler(request: VNRequest, error: Error?) {
        guard let observations =
                request.results as? [VNRecognizedTextObservation] else {
            return
        }
        let recognizedStrings = observations.compactMap { observation in
            // Return the string of the top VNRecognizedText instance.
            return observation.topCandidates(1).first?.string
        }
        
        // Process the recognized strings.
        print(recognizedStrings)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(recognizedStrings.joined(separator: "\n"), forType: .string)

    }

    override func rightMouseUp(with event: NSEvent) {
        let point = NSEvent.mouseLocation;
        self.window!.menu?.popUp(positioning: nil, at: point, in: nil)
    }
    
    func setRect(_ rect: NSRect) {
        self.window?.setFrame(rect, display: true, animate: false)
    }
    
    /**
     Take a screenshot of the area under the hint window.
     */
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
            
            // Make an image and an imageview to put the screenshot in
            let image = NSImage(cgImage:screenshot, size: .zero)
            image.resizingMode = .stretch
            let imageView = WindowDraggableImageView(frame: NSRect(origin: .zero, size: self.window!.frame.size))
            imageView.image = image
            
            // Make sure the imageView fills the window
            imageView.autoresizingMask = [.height, .width]
            // and that it will scale larger than its original size
            imageView.imageScaling = .scaleProportionallyUpOrDown
            
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

