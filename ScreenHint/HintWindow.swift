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
     Route the context menu's shortcuts (Copy Text, Hide Borders, ...). AppKit only matches key
     equivalents against the main menu, and as a menu-bar app we don't have one, so without this
     the shortcuts listed in a hint's menu never fire.
     */
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if self.menu?.performKeyEquivalent(with: event) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
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
    }

    private func animateBorderlessMode(_ isEnabled: Bool) {
        guard let layer = imageViewLayer else { return }

        let borderAnimation = CABasicAnimation(keyPath: "borderWidth")
        let newBorder = isEnabled ? 0.0 : 1.0
        borderAnimation.fromValue = layer.borderWidth
        borderAnimation.toValue = newBorder
        borderAnimation.duration = 0.15
        layer.borderWidth = newBorder

        layer.add(borderAnimation, forKey: "borderWidthAnimation")
    }

    var imageViewLayer: CALayer? {
        (contentView?.subviews.first as? WindowDraggableImageView)?.layer
    }

    /// The badge currently on screen, if any.
    private(set) var badge: HintBadgeView?

    /**
     Briefly show a small badge (e.g. "Copied") in the middle of the hint, then fade it out.
     Showing a new badge replaces any that's still visible.
     */
    func showBadge(_ text: String, duration: TimeInterval = 1.2) {
        guard let contentView = self.contentView else { return }
        self.badge?.removeFromSuperview()

        let badge = HintBadgeView(text: text)
        badge.setFrameOrigin(NSPoint(x: (contentView.bounds.width - badge.frame.width) / 2,
                                     y: (contentView.bounds.height - badge.frame.height) / 2))
        // Stay centered if the hint is resized while the badge is up.
        badge.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        contentView.addSubview(badge)
        self.badge = badge

        // VoiceOver users can't see the badge, so say it too.
        NSAccessibility.post(element: self,
                             notification: .announcementRequested,
                             userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let fade: TimeInterval = reduceMotion ? 0 : 0.15
        badge.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fade
            badge.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self, weak badge] in
            guard let badge = badge else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = fade
                badge.animator().alphaValue = 0
            }, completionHandler: {
                badge.removeFromSuperview()
                if self?.badge === badge { self?.badge = nil }
            })
        }
    }
}


/**
 A small dark label with a line of text, used for brief confirmations like "Copied". It ignores
 the mouse so dragging and right-clicking the hint work straight through it.
 */
class HintBadgeView: NSView {

    let label: NSTextField

    init(text: String) {
        self.label = NSTextField(labelWithString: text)
        self.label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        self.label.textColor = .white
        self.label.sizeToFit()

        let padding = NSSize(width: 8, height: 5)
        let size = NSSize(width: ceil(self.label.frame.width) + padding.width * 2,
                          height: ceil(self.label.frame.height) + padding.height * 2)
        super.init(frame: NSRect(origin: .zero, size: size))

        self.wantsLayer = true
        self.layer?.backgroundColor = CGColor(gray: 0, alpha: 0.75)
        // Squared-off with slightly rounded corners, like the box around "hint" in the logo.
        self.layer?.cornerRadius = 3
        // A faint light edge keeps the badge visible on dark hints.
        self.layer?.borderWidth = 1
        self.layer?.borderColor = CGColor(gray: 1, alpha: 0.25)
        self.label.setFrameOrigin(NSPoint(x: padding.width, y: padding.height))
        self.addSubview(self.label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
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
