//
//  SecretWindowController.swift
//  ScreenHint
//
//  Created by Salem on 6/13/21.
//

import Foundation
import AppKit

/**
 A borderless, non-activating, transparent panel shown over a single screen while the
 user is drawing a hint.

 It is purely cosmetic: `ignoresMouseEvents = true`, so it never takes over hit-testing
 and never disturbs the app underneath (which is what preserves that app's hover UI).
 All input is handled by a `CGEventTap` in the app delegate — see
 `hover-preserving-capture` — and this window just draws the dimming, the selection
 rectangle, and our own crosshair (the real cursor is frozen while the tap swallows moves).
 */
class SecretWindow: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/**
 Drawing-only content view for a `SecretWindow`. It's told, in global screen coordinates,
 where the current selection and virtual cursor are, and renders them.
 */
final class OverlayView: NSView {

    /// The global (bottom-left origin) frame of the screen this overlay covers.
    var screenFrame: NSRect = .zero

    /// Current selection in global screen coordinates, or nil if none yet.
    private var selection: NSRect?

    override var isOpaque: Bool { false }
    override var mouseDownCanMoveWindow: Bool { false }

    /// Update what we draw. `selection` is in global screen coordinates.
    func update(selection: NSRect?) {
        self.selection = selection
        needsDisplay = true
    }

    /// Convert a global screen rect into this view's local coordinates.
    private func toLocal(_ rect: NSRect) -> NSRect {
        NSRect(x: rect.minX - screenFrame.minX,
               y: rect.minY - screenFrame.minY,
               width: rect.width,
               height: rect.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Dim the whole screen so the selection stands out.
        context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.4).cgColor)
        context.fill(bounds)

        // Punch the selection out so the live content underneath shows through, and
        // outline it.
        if let selection, selection.width >= 1, selection.height >= 1 {
            let localSelection = toLocal(selection)
            context.setBlendMode(.clear)
            context.fill(localSelection)
            context.setBlendMode(.normal)

            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(1)
            context.stroke(localSelection.insetBy(dx: 0.5, dy: 0.5))
        }

    }
}

/**
 Owns a `SecretWindow` overlay for a single screen and forwards drawing updates to it.
 */
class SecretWindowController: NSWindowController {

    private let overlayView: OverlayView

    init(_ screen: NSScreen) {
        let secretWindow = SecretWindow(contentRect: screen.frame,
                                        styleMask: [.borderless, .nonactivatingPanel],
                                        backing: .buffered,
                                        defer: false)

        secretWindow.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        secretWindow.isOpaque = false
        secretWindow.backgroundColor = .clear
        secretWindow.hasShadow = false

        // Cosmetic overlay only: never intercept mouse events at the window level (that
        // would disturb the app below's hover). The CGEventTap handles all input.
        secretWindow.ignoresMouseEvents = true

        secretWindow.hidesOnDeactivate = false
        secretWindow.isMovable = false
        secretWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        // Keep this window out of the screenshots we (and other apps) take.
        secretWindow.sharingType = .none

        let overlayView = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
        overlayView.screenFrame = screen.frame
        secretWindow.contentView = overlayView
        self.overlayView = overlayView

        super.init(window: secretWindow)
    }

    /// Show the overlay without activating ScreenHint or taking key focus.
    func present() {
        window?.orderFrontRegardless()
    }

    /// Update the drawn selection (global screen coordinates).
    func update(selection: NSRect?) {
        overlayView.update(selection: selection)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
