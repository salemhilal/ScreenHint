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
 This is a hidden window that we display on every screen when the global shortcut is pressed.
 It captures mouse events so that you don't highlight or drag stuff when making a hint.
 */
class SecretWindowController: NSWindowController, NSWindowDelegate {
    init(_ screen: NSScreen) {
        let secretWindow = SecretWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
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
