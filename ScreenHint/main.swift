//
//  main.swift
//  ScreenHint
//
//  Created by Salem on 6/18/21.
//

import Cocoa

let delegate = ScreenHintAppDelegate()
NSApplication.shared.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
