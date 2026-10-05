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
import ScreenCaptureKit

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

    /// Whether the system request reliably shows a prompt. The Accessibility prompt doesn't
    /// appear for ScreenHint (sandboxed), so for Accessibility the request is made and System
    /// Settings opened in one step.
    var systemPromptAppears: Bool {
        self == .screenRecording
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
        case .notRequested where permission.systemPromptAppears:
            defaults.set(true, forKey: permission.requestedKey)
            system.request(permission)
        case .notRequested:
            // No prompt would appear, so go straight to System Settings (which requests first,
            // putting ScreenHint in the pane's list).
            defaults.set(true, forKey: permission.requestedKey)
            system.openSettings(permission)
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
                // Accessibility is what the switch in System Settings sets, and AXIsProcessTrusted()
                // asks the system afresh each time, so flipping it shows up right away.
                // (CGPreflightPostEventAccess() looks related but answers from a cache, and can say
                // yes long after the switch is turned off.)
                return AXIsProcessTrusted()
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
        // CGRequestScreenCaptureAccess() only asks the system once per launch; later calls
        // return without registering anything, so after a reset ScreenHint could be missing
        // from the pane. Asking ScreenCaptureKit for shareable content checks with the system
        // every time, which lists ScreenHint (switched off) if it isn't already.
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { _, _ in }
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
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Permission.allCases) { permission in
                PermissionRow(permission: permission, state: model.state(of: permission)) {
                    model.requestOrOpenSettings(permission)
                }
            }
        }
        // macOS doesn't announce permission changes, and they happen outside the app (in System
        // Settings, or with tccutil), so keep checking while this is up, granted or not. It's
        // cheap once everything's granted: two quick system calls.
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            model.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refresh()
        }
    }
}

/// One permission as a card: what it's for, whether it's allowed, and (when it isn't) where to
/// find it in System Settings plus a button to get it.
struct PermissionRow: View {
    let permission: Permission
    let state: PermissionsModel.State
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: permission.systemImage)
                    .foregroundStyle(.secondary)
                Text(permission.title)
                    .font(.headline)
                Spacer(minLength: 8)
                // Only the symbol is tinted; colored text on the light card is too low-contrast.
                if state == .granted {
                    Label {
                        Text("Allowed")
                    } icon: {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                } else {
                    Label {
                        Text("Not allowed").foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                    }
                }
            }

            Text(permission.explanation)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if state != .granted {
                HStack(alignment: .bottom) {
                    Text("In System Settings, it's under Privacy & Security → \(permission.paneName).")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 12)
                    Button(state == .notRequested && permission.systemPromptAppears
                           ? "Request Access" : "Open System Settings…", action: action)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.12), lineWidth: 1))
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
