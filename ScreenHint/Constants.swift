//
//  Constants.swift
//  ScreenHint
//
//  Created by Salem Hilal on 12/24/21.
//

import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let createNewHint = Self("createNewHint")
}

struct AppStorageKeys {
    static let openAtLogin = "openAtLogin"
    static let isFirstLaunch = "isFirstLaunch"
}

struct AppIds {
    static let launcher = "io.salem.ScreenHintLauncher"
}

struct Constants {
    static let minHintDimension: CGFloat = 10
}
