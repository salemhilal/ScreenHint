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
struct PermissionsTests {

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

    /// A throwaway defaults domain, so tests never see (or touch) the app's real settings.
    private func freshDefaults() -> UserDefaults {
        let name = "PermissionsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("a permission that's never been asked for gets the system request first")
    func firstPressRequests() {
        let fake = FakeSystem()
        let model = PermissionsModel(system: fake.system, defaults: freshDefaults())
        #expect(model.state(of: .accessibility) == .notRequested)

        model.requestOrOpenSettings(.accessibility)

        #expect(fake.requests == [.accessibility])
        #expect(fake.settingsOpened.isEmpty)
        // We can't tell whether a prompt appeared, so the next press goes to System Settings.
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
