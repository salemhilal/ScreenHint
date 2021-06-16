//
//  main.swift
//  ScreenHintLauncher
//
//  Created by Salem on 6/16/21.
//

import Cocoa

let delegate = ScreenHintLauncherAppDelegate()
NSApplication.shared.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
