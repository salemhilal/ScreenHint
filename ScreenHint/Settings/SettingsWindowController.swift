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
        let vc = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: vc)
        
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.makeKeyAndOrderFront(nil)
        window.level = .floating
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.styleMask.remove(.resizable)



        super.init(window: window)
        window.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
