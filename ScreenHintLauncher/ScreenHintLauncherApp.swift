//
//  ScreenHintLauncherApp.swift
//  ScreenHintLauncher
//
//  Created by Salem on 6/14/21.
//
// Huge thanks to https://jogendra.dev/implementing-launch-at-login-feature-in-macos-apps
// for being the only guide modern and clear enough to un-stick
// when I tried to implement Launch-at-login the first time around
//

import Cocoa
import os

class ScreenHintLauncherAppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        let mainAppIdentifier = "io.salem.ScreenHint"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains { $0.bundleIdentifier == mainAppIdentifier }

        // ScreenHint is already running; we can quit.
        if isRunning {
            NSApp.terminate(nil)
        }

        // ScreenHint.app is a few levels up from where the launcher is.
        // We need to peel off:
        //   - ScreenHintLauncher.app
        //   - LoginItems/
        //   - Library/
        //   - Contents/
        var path = Bundle.main.bundlePath as NSString
        for _ in 1...4 {
            path = path.deletingLastPathComponent as NSString
        }
        
        // Give the path a scheme
        path = "file://\(path)" as NSString
        
        // Convert our path to a URL and use it to launch ScreenHint
        guard let url = URL(string: path as String) else { return }
        os_log("ScreenHint - Attenpting to open URL \(url)")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { (_, error) in
            if (error != nil) {
                os_log(.error, "Error opening ScreenHint from ScreenHintLauncher")
            }
            
            NSApp.terminate(nil)
        }
    }
}
