//
//  AboutWindowController.swift
//  ScreenHint
//
//  Created by Salem on 6/13/21.
//

import Foundation
import AppKit
import SwiftUI

class AboutWindowController: NSWindowController, NSWindowDelegate {
    init() {
        let width: CGFloat = 324;
        let height: CGFloat = 200;
        // Unlike in other places, we actually mean the main screen.
        // This window is going to show up wherever the keyboard is focused to,
        // so we want it to render in the center of that.
        let screenFrame = NSScreen.main!.frame;
        
        let aboutRect = NSRect(
            x: screenFrame.width / 2 - (width / 2),
            y: screenFrame.height / 2 - (height / 2),
            width: width,
            height: height
        )
        let window = NSWindow(contentRect: aboutRect, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.level = .floating
        window.isMovable = true
        
        let contentView = AboutView()
        let view = NSHostingView(rootView: contentView)
        view.frame = NSRect(x: 0, y: 0, width: width, height: height);
        window.contentView?.addSubview(view)
        
        super.init(window: window)
        window.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
