//
//  ScreenHintLauncherApp.swift
//  ScreenHintLauncher
//
//  Created by Salem on 6/14/21.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject {

    @objc func terminate() {
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let killScreenHintLauncher = Notification.Name("killScreenHintLauncher")
}

extension AppDelegate: NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        let mainAppIdentifier = "io.salem.ScreenHint"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == mainAppIdentifier }.isEmpty

        if !isRunning {
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(self.terminate), name: .killScreenHintLauncher, object: mainAppIdentifier)

            let path = Bundle.main.bundlePath as NSString
            var components = path.pathComponents
            components.removeLast()
            components.removeLast()
            components.removeLast()
            components.append("MacOS")
            components.append("ScreenHint") //main app name

            let newPath = NSString.path(withComponents: components)
            guard let newUrl = URL.init(string:newPath) else {
                // URL is invalid; launch at login won't work, but that's not the end of the world.
                return
            }
            let config = NSWorkspace.OpenConfiguration.init()

//            NSWorkspace.shared.launchApplication(newPath)
            NSWorkspace.shared.openApplication(at: newUrl, configuration: config)
        }
        else {
            self.terminate()
        }
    }
}
