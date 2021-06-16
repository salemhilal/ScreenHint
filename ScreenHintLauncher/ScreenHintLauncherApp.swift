//
//  ScreenHintLauncherApp.swift
//  ScreenHintLauncher
//
//  Created by Salem on 6/14/21.
//

import Cocoa

extension Notification.Name {
    static let killScreenHintLauncher = Notification.Name("killScreenHintLauncher")
}

class ScreenHintLauncherAppDelegate: NSObject, NSApplicationDelegate {
    
    func logToFile(_ text: String) {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        let logPath = documentsDirectory.appending("/console.log")
        let cstr = URL(fileURLWithPath: logPath)
        do {
            try text.write(to: cstr, atomically: true, encoding: .utf8)
        } catch {
            print("Oh no: \(error)")
        }
    }


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
            components.append("ScreenHint")
            
            let newPath = NSString.path(withComponents: components)
            logToFile("Screenhint - Path to ScreenHint launcher is \(newPath)")
            
            NSWorkspace.shared.launchApplication(newPath)
            /*
            
            guard let newUrl = URL.init(string:newPath) else {
                // URL is invalid; launch at login won't work, but that's not the end of the world.
                NSLog("Screenhint - Path to ScreenHint launcher is invalid: \(newPath)")
                return
            }
            let config = NSWorkspace.OpenConfiguration.init()

            NSLog("Screenhint - Launching ScreenHint: \(newUrl)")
            NSWorkspace.shared.openApplication(at: newUrl, configuration: config) { (app, error) in
                // Something went wrong launching ScreenHint
                if let e = error {
                    NSLog("Screenhint - Oh shit: \(e)")
                    
                }
                self.terminate()

            }
 */
        }
        
        logToFile("Screenhint - Turning off")
        self.terminate()

    }
    
    @objc func terminate() {
        NSApp.terminate(nil)
    }
}
