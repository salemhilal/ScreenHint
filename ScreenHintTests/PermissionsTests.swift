//
//  PermissionsTests.swift
//  ScreenHintTests
//
//  The Permissions window's logic, with the system calls stubbed out: no real prompts appear
//  and System Settings never opens.
//

import Foundation
import Testing
@testable import ScreenHint

@Suite("Permissions")
final class PermissionsTests {

    /// Stand-ins for the system calls, recording what the model asked for.
    final class FakeSystem {
        var granted: Set<Permission> = []
        var requests: [Permission] = []
        var settingsOpened: [Permission] = []

        var system: PermissionsModel.System {
            PermissionsModel.System(
                isGranted: { [unowned self] in self.granted.contains($0) },
                request: { [unowned self] in self.requests.append($0) },
                openSettings: { [unowned self] in self.settingsOpened.append($0) })
        }
    }

    /// The throwaway defaults domains made by `freshDefaults()`, removed when the test ends
    /// (Swift Testing makes a new instance per test) so they don't pile up on disk.
    private var suiteNames: [String] = []

    deinit {
        for name in suiteNames {
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
    }

    /// A throwaway defaults domain, so tests never see (or touch) the app's real settings.
    private func freshDefaults() -> UserDefaults {
        let name = "PermissionsTests-\(UUID().uuidString)"
        suiteNames.append(name)
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("Screen Recording, which does prompt, gets the system request first")
    func firstPressRequests() {
        let fake = FakeSystem()
        let model = PermissionsModel(system: fake.system, defaults: freshDefaults())
        #expect(model.state(of: .screenRecording) == .notRequested)

        model.requestOrOpenSettings(.screenRecording)

        #expect(fake.requests == [.screenRecording])
        #expect(fake.settingsOpened.isEmpty)
        // We can't tell whether a prompt appeared, so the next press goes to System Settings.
        #expect(model.state(of: .screenRecording) == .requestedButMissing)
    }

    @Test("Accessibility, whose prompt never appears, goes straight to System Settings on the first press")
    func accessibilityFirstPressOpensSettings() {
        let fake = FakeSystem()
        let model = PermissionsModel(system: fake.system, defaults: freshDefaults())

        model.requestOrOpenSettings(.accessibility)

        #expect(fake.requests.isEmpty)
        #expect(fake.settingsOpened == [.accessibility])
        #expect(model.state(of: .accessibility) == .requestedButMissing)
    }

    @Test("once requested and still missing, the button opens System Settings instead")
    func laterPressesOpenSettings() {
        let fake = FakeSystem()
        let defaults = freshDefaults()
        PermissionsModel(system: fake.system, defaults: defaults).requestOrOpenSettings(.screenRecording)

        // A new model (e.g. after relaunching) remembers that it already asked.
        let model = PermissionsModel(system: fake.system, defaults: defaults)
        #expect(model.state(of: .screenRecording) == .requestedButMissing)
        model.requestOrOpenSettings(.screenRecording)

        #expect(fake.requests == [.screenRecording])
        #expect(fake.settingsOpened == [.screenRecording])
    }

    @Test("a granted permission shows as granted and its button does nothing")
    func grantedIsGranted() {
        let fake = FakeSystem()
        fake.granted = [.screenRecording]
        let model = PermissionsModel(system: fake.system, defaults: freshDefaults())

        #expect(model.state(of: .screenRecording) == .granted)
        #expect(!model.allGranted)
        model.requestOrOpenSettings(.screenRecording)
        #expect(fake.requests.isEmpty && fake.settingsOpened.isEmpty)
    }

    @Test("granting in System Settings is picked up on the next refresh")
    func refreshPicksUpGrants() {
        let fake = FakeSystem()
        let model = PermissionsModel(system: fake.system, defaults: freshDefaults())
        model.requestOrOpenSettings(.accessibility)
        model.requestOrOpenSettings(.screenRecording)
        #expect(!model.allGranted)

        fake.granted = [.accessibility, .screenRecording]
        model.refresh()

        #expect(model.allGranted)
    }

    @Test("each permission points at the right System Settings pane")
    func settingsURLs() {
        #expect(Permission.accessibility.settingsURL.absoluteString.hasSuffix("Privacy_Accessibility"))
        #expect(Permission.screenRecording.settingsURL.absoluteString.hasSuffix("Privacy_ScreenCapture"))
    }
}
