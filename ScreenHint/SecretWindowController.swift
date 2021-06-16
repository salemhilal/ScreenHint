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
        return true
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
        secretWindow.backgroundColor = NSColor.blue
        secretWindow.isOpaque = false
        secretWindow.alphaValue = 0.2
        secretWindow.level = .screenSaver
        secretWindow.ignoresMouseEvents = false
        secretWindow.isMovable = false
        secretWindow.collectionBehavior = [.stationary, .transient, .canJoinAllSpaces]
        
        
        let highlightRect = NSView.init(frame: CGRect.zero)
        highlightRect.isHidden = true;
        highlightRect.wantsLayer = true
        highlightRect.layer?.backgroundColor = CGColor.white
        highlightRect.layer?.opacity = 0.5
        highlightRect.layer?.borderWidth = 1.0
        highlightRect.layer?.borderColor = CGColor.black
        secretWindow.contentView?.addSubview(highlightRect)
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
    
    func setActive(_ isActive: Bool) {
        self.window?.alphaValue = isActive ? 0.1 : 0.2
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
