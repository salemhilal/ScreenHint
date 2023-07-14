//
//  HintWindow.swift
//  ScreenHint
//
//  Created by Salem Hilal on 6/18/22.
//

import Foundation
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
        self.level = .screenSaver // Put this window on top of everything else
        self.backgroundColor = NSColor.blue
        self.ignoresMouseEvents = false
        self.isMovableByWindowBackground = true
        self.isMovable = true
        self.hasShadow = true // togged in borderless mode
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.borderWidth = 1 // toggled in borderless mode
        self.contentView?.layer?.borderColor = CGColor.init(gray: 1.0, alpha: 0.1)
        self.contentView?.layer?.cornerRadius = 3
        // Causes a fast fade-out (at least at time of writing)
        self.animationBehavior = .utilityWindow
        // Make sure that a hint can't be resized down to oblivion
        self.minSize = NSSize(width: Constants.minHintDimension, height: Constants.minHintDimension)
    }
    
    // This window can receive keyboard commands
    override var canBecomeKey: Bool {
        get { return true }
    }
    
    // But it can _not_ become the main application window
    override var canBecomeMain: Bool {
        get { return false }
    }
    
    /**
     Handle keyboard shortcuts
     */
    override func keyDown(with event: NSEvent) {
        // Cmd + C = copy
        if (event.charactersIgnoringModifiers == "c" && event.modifierFlags.contains(.command)) {
            self.copyDelegate?.shouldCopy()
        }
    }
    
    /**
     Handle mouse events
     */
    override func mouseUp(with event: NSEvent) {
        // If this window is double-clicked (anywhere), close it.
        if event.clickCount >= 2 {
            // TODO: remove self from rects array
            self.windowController?.close();
        }
        super.mouseUp(with: event)
    }
    
    // --- Instance methods ---
    
    /**
     Set whether or not this window should be pinned to one desktop, or should sit on all desktops.
     */
    func shouldPinToDesktop(_ shouldPin: Bool) {
        self.collectionBehavior = shouldPin ? [.managed] : [.canJoinAllSpaces]
    }
    
    /**
     Set whether or not to show borders on this hint. Default is yes, we want a border.
     */
    func setBorderlessMode(_ isEnabled: Bool) {
        self.animateBorderlessMode(isEnabled)
        self.hasShadow = !isEnabled
        self.contentView?.layer?.cornerRadius = isEnabled ? 0 : 3
    }
    
    private func animateBorderlessMode(_ isEnabled: Bool) {
        guard let layer = self.contentView?.layer else { return }

        let borderAnimation = CABasicAnimation(keyPath: "borderWidth")
        let newBorder = isEnabled ? 0.0 : 1.0
        borderAnimation.fromValue = layer.borderWidth
        borderAnimation.toValue = newBorder;
        borderAnimation.duration = 0.15
        layer.borderWidth = newBorder

        layer.add(borderAnimation, forKey: "borderWidthAnimation")
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
