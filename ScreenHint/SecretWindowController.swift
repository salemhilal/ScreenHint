//
//  SecretWindowController.swift
//  ScreenHint
//
//  Created by Salem on 6/13/21.
//

import Foundation
import AppKit


class SecretWindow: NSWindow {
    override var canBecomeKey: Bool {
        return false
    }
    override var canBecomeMain: Bool {
        return false
    }
}

/**
 This is a translucent window that we display on every screen when the global shortcut is pressed.
 It captures mouse events so that you don't highlight or drag stuff when making a hint.
 */
class SecretWindowController: NSWindowController, NSWindowDelegate {
    
    var highlightRect: NSView;
    
    init(_ screen: NSScreen) {
        let secretWindow = SecretWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        
        // Make sure we can see through it
        secretWindow.backgroundColor = NSColor.systemBlue
        secretWindow.isOpaque = false
        secretWindow.alphaValue = 0.4
        
        // Make sure it's above everything and captures mouse movement
        secretWindow.level = .screenSaver
        secretWindow.isMovable = false
        secretWindow.collectionBehavior = [.stationary, .transient, .canJoinAllSpaces]
        
        // Make sure this window doesn't make it into the screenshots we take.
        secretWindow.sharingType = .none
        
        // Draw the portion of the screen we're gonna be highlighting.
        let highlightRect = NSView.init(frame: CGRect.zero)
        highlightRect.isHidden = true;
        highlightRect.wantsLayer = true
        highlightRect.layer?.backgroundColor = CGColor.white
        highlightRect.layer?.opacity = 0.8
        highlightRect.layer?.borderWidth = 1.0
        highlightRect.layer?.borderColor = CGColor.black
        
        // Add the view to the window
        secretWindow.contentView?.addSubview(highlightRect)
        
        // Keep a reference to the highlight rect
        self.highlightRect = highlightRect;
        
        super.init(window: secretWindow)
        secretWindow.delegate = self
    }
    
    func isPointInWindowScreen(_ point: CGPoint) -> Bool {
        // Each secret window is supposed to cover a whole screen.
        // Let's get the screen's frame and figure out if our point is in it.
        guard let frame = self.window?.screen?.frame else { return false }
        
        
        let isInScreen = frame.minX <= point.x &&
            frame.maxX >= point.x &&
            frame.minY <= point.y &&
            frame.maxY >= point.y
        
        return isInScreen
    }
    
    func setHighlightRect(_ rect: CGRect?) {
        // If nil is passed, unrender the child rectangle
        guard let highlightFrame = rect else {
            
            self.highlightRect.isHidden = true
            return;
        }
        
        guard let convertedFrame = self.window?.convertFromScreen(highlightFrame) else {
            return
        }
        
        self.highlightRect.frame = convertedFrame
        self.highlightRect.isHidden = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
