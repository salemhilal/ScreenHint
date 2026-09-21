//
//  SelectionGeometryTests.swift
//  ScreenHintTests
//
//  Deterministic tests for the selection-rect math in ScreenHintAppDelegate: normalizing a
//  drag into a rect, clamping the virtual cursor to the screen union, and the minimum-size
//  guard that decides whether a drag becomes a hint.
//

import AppKit
import Testing
@testable import ScreenHint

@Suite("Selection geometry")
struct SelectionGeometryTests {

    // MARK: - rect(from:to:)

    @Test("rect(from:to:) normalizes all four drag directions", arguments: [
        (NSPoint(x: 0, y: 0), NSPoint(x: 10, y: 20)),   // down-right
        (NSPoint(x: 10, y: 20), NSPoint(x: 0, y: 0)),   // up-left
        (NSPoint(x: 0, y: 20), NSPoint(x: 10, y: 0)),   // down-left... start top
        (NSPoint(x: 10, y: 0), NSPoint(x: 0, y: 20)),   // up-right
    ])
    func rectNormalizesEveryDragDirection(_ points: (NSPoint, NSPoint)) {
        let (a, b) = points
        let rect = ScreenHintAppDelegate.rect(from: a, to: b)
        #expect(rect.minX == 0)
        #expect(rect.minY == 0)
        #expect(rect.width == 10)
        #expect(rect.height == 20)
    }

    @Test("rect(from:to:) for a zero-size drag is a zero rect at the anchor")
    func rectForZeroSizeDrag() {
        let point = NSPoint(x: 5, y: 5)
        let rect = ScreenHintAppDelegate.rect(from: point, to: point)
        #expect(rect == NSRect(x: 5, y: 5, width: 0, height: 0))
    }

    // MARK: - clampToScreens

    @Test("clampToScreens pins points outside the screen union to its edges")
    func clampPinsOutsidePointsToEdges() {
        let delegate = ScreenHintAppDelegate()
        delegate.screensBounds = NSRect(x: 0, y: 0, width: 1000, height: 800)

        #expect(delegate.clampToScreens(NSPoint(x: -50, y: 400)) == NSPoint(x: 0, y: 400))
        #expect(delegate.clampToScreens(NSPoint(x: 1500, y: 400)) == NSPoint(x: 1000, y: 400))
        #expect(delegate.clampToScreens(NSPoint(x: 500, y: -50)) == NSPoint(x: 500, y: 0))
        #expect(delegate.clampToScreens(NSPoint(x: 500, y: 1200)) == NSPoint(x: 500, y: 800))
    }

    @Test("clampToScreens leaves interior points untouched")
    func clampLeavesInteriorPointsUntouched() {
        let delegate = ScreenHintAppDelegate()
        delegate.screensBounds = NSRect(x: 0, y: 0, width: 1000, height: 800)

        let interior = NSPoint(x: 500, y: 400)
        #expect(delegate.clampToScreens(interior) == interior)
    }

    // MARK: - finishSelection's minimum-size guard (reject path only — the accept path

    @Test("finishSelection rejects a nil selection without creating a hint")
    func finishSelectionRejectsNilSelection() {
        let delegate = ScreenHintAppDelegate()
        delegate.finishSelection(nil)
        #expect(delegate.hints.isEmpty)
    }

    @Test("finishSelection rejects selections at or below the minimum dimension", arguments: [
        NSSize(width: Constants.minHintDimension, height: Constants.minHintDimension * 2),
        NSSize(width: Constants.minHintDimension * 2, height: Constants.minHintDimension),
        NSSize(width: 1, height: 1),
    ])
    func finishSelectionRejectsTooSmallSelections(_ size: NSSize) {
        let delegate = ScreenHintAppDelegate()
        let selection = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        // Both dimensions are compared with `>`, so a selection with either dimension at or
        // below the minimum is rejected before any real screen is touched.
        delegate.finishSelection(selection)
        #expect(delegate.hints.isEmpty)
    }
}
