//
//  EventTapTests.swift
//  ScreenHintTests
//
//  Hover preservation depends entirely on handleTapEvent swallowing every mouse event
//  (returning nil) while a capture is in progress — if a single event type leaked through
//  to the tap, it would reach the app underneath and could dismiss its hover UI. These
//  tests drive handleTapEvent with synthetic CGEvents (no real tap, no Accessibility
//  permission needed to construct or read a CGEvent) and assert on what it returns and
//  what selection state it produces.
//

import AppKit
import Testing
@testable import ScreenHint

@Suite("Event tap dispatch")
struct EventTapTests {

    private func mouseEvent(_ type: CGEventType, at location: CGPoint = .zero) -> CGEvent {
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: location, mouseButton: .left)!
    }

    private func makeDelegate() -> ScreenHintAppDelegate {
        let delegate = ScreenHintAppDelegate()
        // Generous bounds so clampToScreens never clips the synthetic coordinates below,
        // regardless of what real displays (if any) are attached to this machine.
        delegate.screensBounds = NSRect(x: -100_000, y: -100_000, width: 200_000, height: 200_000)
        return delegate
    }

    // MARK: - Swallowing

    @Test("mouse move, drag, down, and up are all swallowed", arguments: [
        CGEventType.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp,
    ])
    func mouseEventsAreSwallowed(_ type: CGEventType) {
        let delegate = makeDelegate()
        let result = delegate.handleTapEvent(type: type, event: mouseEvent(type))
        #expect(result == nil, "\(type) must be swallowed or the app underneath sees it and its hover UI can be dismissed")
    }

    @Test("an unhandled event type passes through untouched")
    func unhandledEventPassesThrough() {
        let delegate = makeDelegate()
        let event = mouseEvent(.rightMouseDown)
        let result = delegate.handleTapEvent(type: .rightMouseDown, event: event)
        #expect(result != nil)
    }

    // MARK: - Selection geometry through the tap

    @Test("a down-then-drag sequence produces the correctly flipped and normalized selection")
    func downThenDragProducesExpectedSelection() {
        let delegate = makeDelegate()

        // CGEvent locations are top-left-origin; handleTapEvent flips them to Cocoa's
        // bottom-left origin using the main display's height.
        let mainH = CGDisplayBounds(CGMainDisplayID()).height
        let downLocation = CGPoint(x: 100, y: 200)
        let dragLocation = CGPoint(x: 300, y: 250)
        let expectedAnchor = NSPoint(x: 100, y: mainH - 200)
        let expectedDragPoint = NSPoint(x: 300, y: mainH - 250)
        let expectedSelection = ScreenHintAppDelegate.rect(from: expectedAnchor, to: expectedDragPoint)

        // Seed the virtual cursor at the anchor before the button goes down — mirrors the
        // real sequence (move, then down, then drag).
        _ = delegate.handleTapEvent(type: .mouseMoved, event: mouseEvent(.mouseMoved, at: downLocation))
        _ = delegate.handleTapEvent(type: .leftMouseDown, event: mouseEvent(.leftMouseDown, at: downLocation))
        #expect(delegate.dragAnchor == expectedAnchor)

        _ = delegate.handleTapEvent(type: .leftMouseDragged, event: mouseEvent(.leftMouseDragged, at: dragLocation))
        #expect(delegate.currentSelection == expectedSelection)
    }

    @Test("mouse-up clears the drag anchor")
    func mouseUpClearsDragAnchor() {
        let delegate = makeDelegate()
        _ = delegate.handleTapEvent(type: .leftMouseDown, event: mouseEvent(.leftMouseDown))
        #expect(delegate.dragAnchor != nil)

        // The selection this produces is zero-sized (anchor == virtualCursor, both untouched
        // since we never moved), so finishSelection's guard rejects it synchronously without
        // touching a real screen — safe to let the async dispatch inside leftMouseUp run.
        _ = delegate.handleTapEvent(type: .leftMouseUp, event: mouseEvent(.leftMouseUp))
        #expect(delegate.dragAnchor == nil)
    }

    // MARK: - Tap-disabled dispatch

    // Whether a disabled tap is actually re-enabled depends on a live CFMachPort tap, which
    // isn't something a deterministic test can fabricate. These just confirm the dispatch
    // for this case doesn't crash and passes the event through either way; the "only
    // re-enable while a capture is active" guard is the load-bearing bit, exercised
    // qualitatively via the watchdog/Escape-hotkey safety design rather than this test.
    @Test("tap-disabled events pass through regardless of capture state", arguments: [
        (CGEventType.tapDisabledByTimeout, true),
        (CGEventType.tapDisabledByTimeout, false),
        (CGEventType.tapDisabledByUserInput, true),
        (CGEventType.tapDisabledByUserInput, false),
    ])
    func tapDisabledEventsPassThrough(_ args: (CGEventType, Bool)) {
        let (type, captureActive) = args
        let delegate = makeDelegate()
        delegate.captureActive = captureActive
        let result = delegate.handleTapEvent(type: type, event: mouseEvent(.mouseMoved))
        #expect(result != nil)
    }
}
