//
//  SettingsWindowController.swift
//  ScreenHint
//
//  Created by Salem on 6/16/21.
//

import Foundation
import SwiftUI
import AppKit

class SettingsWindowController: NSWindowController, NSWindowDelegate {
    init() {
        let width: CGFloat = 350;
        let height: CGFloat = 180;
        // Unlike in other places, we actually mean the main screen.
        // This window is going to show up wherever the keyboard is focused to,
        // so we want it to render in the center of that.
        let screenFrame = NSScreen.main!.frame;
        
        let settingsRect = NSRect(
            x: screenFrame.width / 2 - (width / 2),
            y: screenFrame.height / 2 - (height / 2),
            width: width,
            height: height
        )
        
        let window = NSWindow(contentRect: settingsRect, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.level = .floating
        window.isMovable = true
        window.title = "Settings"
        
        let settingsView = SettingsView()
        let view = NSHostingView(rootView: settingsView)
        view.frame = NSRect(x: 0, y: 0, width: width, height: height);
        window.setContentSize(view.frame.size)
        window.contentView?.addSubview(view)
        
        super.init(window: window)
        window.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
