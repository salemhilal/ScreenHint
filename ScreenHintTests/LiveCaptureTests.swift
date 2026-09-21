//
//  LiveCaptureTests.swift
//  ScreenHintTests
//
//  Tests that exercise a real screen and real ScreenCaptureKit calls. Because
//  ScreenHintTests' TEST_HOST is ScreenHint.app, these run inside the actual app process and
//  inherit its Screen Recording / Accessibility grants — but they still need a real display
//  and real permission, so the whole suite is skipped when Screen Recording or a display is
//  missing.
//
//  A window created by this test process belongs to the same running application as
//  ScreenHint.app itself (same PID), so captureImage's own-app exclusion applies to our
//  fixture windows too, exactly as it would to a real hint window — every capture below has
//  to explicitly except the fixture's window ID to see it at all, which is itself part of
//  what's under test.
//
//  There's no live hover-preservation test here. The production tap protects hover in OTHER
//  processes' windows sitting under the overlay (Safari, Finder, etc.) — a same-process
//  fixture can't stand in for that, since a process's own NSApplication run loop receives
//  its own windows' events via a direct path from the window server, independent of what its
//  own CGEventTap does with the spy copy of that stream. Validating the real cross-process
//  guarantee would need a genuinely separate helper process with its own window plus an IPC
//  channel to report its hover state — out of proportion for this suite. The swallowing
//  mechanism itself (every mouse event type returns nil from handleTapEvent) is covered
//  deterministically by EventTapTests; treat actual hover preservation as a manual check
//  before each release.
//

import AppKit
import Testing
@testable import ScreenHint

@Suite("Live capture", .enabled(if: CGPreflightScreenCaptureAccess() && !NSScreen.screens.isEmpty))
struct LiveCaptureTests {

    /// A rect roughly centered on the main screen, away from the menu bar and Dock.
    private static func fixtureRect() -> NSRect {
        let screen = NSScreen.screens.first!.frame
        let size = NSSize(width: 240, height: 180)
        return NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2,
                     width: size.width, height: size.height)
    }

    @Test("a real capture matches the screen's density, avoids resampling, and respects window exceptions")
    @MainActor
    func captureReflectsRealScreenContent() async throws {
        let rect = Self.fixtureRect()
        let view = FixtureView(frame: NSRect(origin: .zero, size: rect.size))
        let fixture = FixtureWindow(rect: rect, content: view)
        defer { fixture.close() }
        await fixture.show()

        let fixtureID = CGWindowID(fixture.window.windowNumber)
        let scale = NSScreen.screens.first!.backingScaleFactor

        // Default exclusion: our own window (this test process shares ScreenHint.app's PID)
        // is excluded, so the capture shows whatever's actually behind it, not the fixture.
        let excludedImage = try await HintWindowController.captureImage(of: rect)
        let excludedReader = PixelReader(excludedImage)

        // Explicit exception: the fixture becomes visible in the capture.
        let includedImage = try await HintWindowController.captureImage(of: rect, exceptingWindowIDs: [fixtureID])
        let includedReader = PixelReader(includedImage)

        #expect(includedImage.width == Int((rect.width * scale).rounded()))
        #expect(includedImage.height == Int((rect.height * scale).rounded()))

        // Corner markers: close to the exact fill color (a real capture can pick up a few
        // units of display color-management noise, unlike the byte-exact synthetic tests),
        // and definitely no resampling or stray overlay tint.
        let markerPixels = Int(view.markerSize * scale) - 1
        let w = includedReader.width, h = includedReader.height
        #expect(includedReader[markerPixels / 2, markerPixels / 2].isClose(to: TestColor.red, tolerance: 8))
        #expect(includedReader[w - 1 - markerPixels / 2, markerPixels / 2].isClose(to: TestColor.green, tolerance: 8))
        #expect(includedReader[markerPixels / 2, h - 1 - markerPixels / 2].isClose(to: TestColor.blue, tolerance: 8))
        #expect(includedReader[w - 1 - markerPixels / 2, h - 1 - markerPixels / 2].isClose(to: TestColor.yellow, tolerance: 8))

        // Whatever the "excluded" capture shows, it isn't all four of our markers — proof
        // the default exclusion actually removed our window rather than no-oping.
        let excludedMatchesAllMarkers =
            excludedReader[markerPixels / 2, markerPixels / 2].isClose(to: TestColor.red, tolerance: 8) &&
            excludedReader[w - 1 - markerPixels / 2, markerPixels / 2].isClose(to: TestColor.green, tolerance: 8) &&
            excludedReader[markerPixels / 2, h - 1 - markerPixels / 2].isClose(to: TestColor.blue, tolerance: 8) &&
            excludedReader[w - 1 - markerPixels / 2, h - 1 - markerPixels / 2].isClose(to: TestColor.yellow, tolerance: 8)
        #expect(!excludedMatchesAllMarkers)
    }

    @Test("the dimming overlay never leaks into a capture even while it's on screen")
    @MainActor
    func overlayNeverLeaksIntoCapture() async throws {
        let rect = Self.fixtureRect()
        let view = FixtureView(frame: NSRect(origin: .zero, size: rect.size))
        let fixture = FixtureWindow(rect: rect, content: view)
        defer { fixture.close() }
        await fixture.show()
        let fixtureID = CGWindowID(fixture.window.windowNumber)

        // Show the real dimming overlay over the fixture's screen, with its selection
        // rect matching the fixture exactly (worst case: the overlay's white stroke sits
        // right on the fixture's own edge).
        let swc = SecretWindowController(NSScreen.screens.first!)
        defer { swc.close() }
        swc.present()
        swc.update(selection: rect)
        try await Task.sleep(nanoseconds: 200_000_000)

        let image = try await HintWindowController.captureImage(of: rect, exceptingWindowIDs: [fixtureID])
        let reader = PixelReader(image)
        let scale = NSScreen.screens.first!.backingScaleFactor
        let markerPixels = Int(view.markerSize * scale) - 1

        // If the overlay leaked in, these would read as blue-tinted (systemBlue @ 0.4) or
        // show the white selection stroke instead of the fixture's marker colors — either
        // would blow well past this tolerance, which only accounts for ordinary capture noise.
        #expect(reader[markerPixels / 2, markerPixels / 2].isClose(to: TestColor.red, tolerance: 8))
        #expect(reader[reader.width - 1 - markerPixels / 2, markerPixels / 2].isClose(to: TestColor.green, tolerance: 8))
    }
}
