//
//  PermissionsView.swift
//  ScreenHint
//
//  Walks through the two permissions ScreenHint needs: Screen Recording (to take the
//  screenshot) and Accessibility (for the event tap that follows the mouse during a capture
//  without disturbing the app underneath).
//

import SwiftUI
import AppKit
import ApplicationServices

enum Permission: CaseIterable, Identifiable {
    case screenRecording, accessibility

    var id: Self { self }

    /// The row's title: the pane's name in System Settings, so the two match.
    var title: String { paneName }

    var explanation: String {
        switch self {
        case .screenRecording:
            "Lets ScreenHint take the screenshot that becomes a hint."
        case .accessibility:
            "Lets ScreenHint follow your mouse while you select part of the screen, without disturbing the app underneath."
        }
    }

    var systemImage: String {
        switch self {
        case .screenRecording: "rectangle.dashed.badge.record"
        case .accessibility: "cursorarrow.motionlines"
        }
    }

    /// The pane's name in System Settings → Privacy & Security, which has changed across releases.
    var paneName: String {
        let os = ProcessInfo.processInfo
        switch self {
        case .screenRecording:
            let isMacOS15 = os.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0))
            return isMacOS15 ? "Screen & System Audio Recording" : "Screen Recording"
        case .accessibility:
            let isMacOS27 = os.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0))
            return isMacOS27 ? "Device Control and Data Access" : "Accessibility"
        }
    }

    var settingsURL: URL {
        switch self {
        case .screenRecording: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        case .accessibility: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        }
    }

    /// UserDefaults key recording that we've asked for this permission at least once.
    var requestedKey: String {
        switch self {
        case .screenRecording: "requestedScreenRecordingPermission"
        case .accessibility: "requestedAccessibilityPermission"
        }
    }
}

/**
 Tracks each permission's state and asks for it. A permission is either granted, not yet
 requested (so the system request can be tried), or requested before and still missing.

 In that last case the system won't ask again (macOS shows each prompt at most once, and the
 Accessibility prompt doesn't appear at all in the sandboxed App Store build), so the only way
 forward is System Settings, where ScreenHint is listed because it has asked. That's also why a
 request flips straight to "requested": we can't tell whether a prompt actually appeared.

 The system calls are injected so the logic can be tested without real prompts.
 */
final class PermissionsModel: ObservableObject {
    enum State: Equatable {
        case granted, notRequested, requestedButMissing
    }

    struct System {
        var isGranted: (Permission) -> Bool
        var request: (Permission) -> Void
        var openSettings: (Permission) -> Void
    }

    @Published private(set) var states: [Permission: State] = [:]

    private let system: System
    private let defaults: UserDefaults

    init(system: System = .live, defaults: UserDefaults = .standard) {
        self.system = system
        self.defaults = defaults
        refresh()
    }

    var allGranted: Bool {
        Permission.allCases.allSatisfy { states[$0] == .granted }
    }

    func state(of permission: Permission) -> State {
        states[permission] ?? .notRequested
    }

    func refresh() {
        var updated: [Permission: State] = [:]
        for permission in Permission.allCases {
            if system.isGranted(permission) {
                updated[permission] = .granted
            } else if defaults.bool(forKey: permission.requestedKey) {
                updated[permission] = .requestedButMissing
            } else {
                updated[permission] = .notRequested
            }
        }
        if updated != states {
            states = updated
        }
    }

    /// The button's action: ask the system the first time, otherwise open System Settings.
    func requestOrOpenSettings(_ permission: Permission) {
        switch state(of: permission) {
        case .granted:
            return
        case .notRequested:
            defaults.set(true, forKey: permission.requestedKey)
            system.request(permission)
        case .requestedButMissing:
            system.openSettings(permission)
        }
        refresh()
    }
}

extension PermissionsModel.System {
    static let live = PermissionsModel.System(
        isGranted: { permission in
            switch permission {
            case .screenRecording:
                return CGPreflightScreenCaptureAccess()
            case .accessibility:
                // AXIsProcessTrusted() can read false even when the event tap works (e.g. under
                // Xcode), so a tap that can be created counts as granted too.
                if AXIsProcessTrusted() { return true }
                return (NSApp.delegate as? ScreenHintAppDelegate)?.canCreateEventTap() ?? false
            }
        },
        request: { permission in
            NSApp.activate(ignoringOtherApps: true)
            requestFromSystem(permission)
        },
        openSettings: { permission in
            // Ask again first: it's what adds ScreenHint to the pane's list, so there's a switch
            // to turn on, and it does nothing if the system has already recorded the request.
            requestFromSystem(permission)
            NSWorkspace.shared.open(permission.settingsURL)
        }
    )
}

/// Ask the system for a permission. Each call shows a prompt only if the system hasn't asked
/// before, and none may appear at all (the Accessibility prompt doesn't in the App Store build).
private func requestFromSystem(_ permission: Permission) {
    switch permission {
    case .screenRecording:
        CGRequestScreenCaptureAccess()
    case .accessibility:
        // Two ways of asking for the same Accessibility grant; the event-posting one is the
        // dedicated API and the more reliable of the two at getting ScreenHint listed.
        CGRequestPostEventAccess()
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}

/// One row per permission: what it's for, and either "Allowed" or a button to get it.
struct PermissionsList: View {
    @ObservedObject var model: PermissionsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Permission.allCases) { permission in
                PermissionRow(permission: permission, state: model.state(of: permission)) {
                    model.requestOrOpenSettings(permission)
                }
            }
        }
        // Grants happen in System Settings, outside the app, so keep checking while this is up.
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            model.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refresh()
        }
    }
}

struct PermissionRow: View {
    let permission: Permission
    let state: PermissionsModel.State
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: permission.systemImage)
                .font(.system(size: 20))
                .frame(width: 28)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(permission.title)
                    .font(.headline)
                Text(permission.explanation)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if state != .granted {
                    Text("In System Settings, it's under Privacy & Security → \(permission.paneName).")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            .frame(maxWidth: .infinity, alignment: .leading)

            // Fixed width, so the text beside it doesn't reflow when the label changes.
            Group {
                switch state {
                case .granted:
                    Label("Allowed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .notRequested:
                    Button("Request Access", action: action)
                case .requestedButMissing:
                    Button("Open System Settings…", action: action)
                }
            }
            .frame(width: 190, alignment: .trailing)
        }
        .accessibilityElement(children: .contain)
    }
}

/// The standalone Permissions window, shown at launch when something's missing and when a
/// capture is blocked by a missing permission.
struct PermissionsView: View {
    @StateObject private var model = PermissionsModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("ScreenHint needs two permissions")
                .font(.system(.title, design: .rounded))
                .fontWeight(.semibold)
            Text("Hints are screenshots you select with your mouse, so ScreenHint needs to see your screen and follow your mouse while you select.")
                .font(.system(.title3))
                .fixedSize(horizontal: false, vertical: true)

            PermissionsList(model: model)

            HStack {
                Spacer()
                Button(model.allGranted ? "Done" : "Later") {
                    NSApp.keyWindow?.close()
                }
                .controlSize(.large)
                .keyboardShortcut(model.allGranted ? .defaultAction : .cancelAction)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 36)
        .padding(.bottom, 24)
        .frame(width: 600)
    }
}
