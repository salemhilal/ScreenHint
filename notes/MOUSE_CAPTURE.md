# Capturing hover UI: how ScreenHint preserves mouse-hover state

ScreenHint can screenshot UI that only exists while the mouse is hovering — tooltips,
`:hover` styles, popovers, hover menus, video player controls. This document explains why
that's hard, the approaches that **don't** work (we tried them), and the approach that does.

## The problem

Hover state is **edge-triggered and latched**: an app enters a hover state when it
processes a mouse-moved event landing on an element, and leaves it when it processes a
later event landing elsewhere. It's also torn down when the app is deactivated or its
window resigns key (many web/Electron apps drop `:hover`/controls on `blur`).

So the moment you press the shortcut and start dragging out a selection, a naive tool
destroys the very thing you're trying to capture: the mouse moves off the element, or our
app steals focus, and the hover UI vanishes before the screenshot is taken.

The goal: from the instant the shortcut fires until the capture completes, the app
underneath must believe **nothing happened** — same cursor position, still frontmost,
still key.

## Approaches that do NOT work

We validated each of these empirically; they're recorded here so nobody reinvents them.

1. **Full-screen overlay window that intercepts the mouse (`ignoresMouseEvents = false`).**
   The intuition ("cover the screen so the app below gets no mouse events") is right for
   the *drag*, but wrong for the *appearance*: the instant a window is layered over the
   cursor, the window server hands the app underneath a synthesized **mouse-exit**, which
   clears hover immediately. This happens regardless of activation, key status, or whether
   the cursor is moving.

2. **Transparent overlay that ignores mouse events (`ignoresMouseEvents = true`).**
   Appears cleanly (no exit), but now the app underneath *does* receive subsequent moves,
   so hover follows the cursor off the element as you drag. It also can't consume clicks —
   they leak through to the app below.

3. **Toggling `ignoresMouseEvents` at runtime** (appear transparent, then flip to
   intercepting). The flip doesn't reliably take effect for hit-testing, so it never
   starts starving moves.

4. **Pinning the cursor with `CGAssociateMouseAndMouseCursorPosition(false)`.** Freezes the
   on-screen cursor, which helps the *move* case, but does **not** stop the appearance-time
   mouse-exit, and the disassociation is not durable when toggled repeatedly (the system
   re-associates). Also risky: a crash while disassociated strands the pointer until logout.

The takeaway: **no combination of window properties** gets clean appearance, starved moves,
and consumed clicks at the same time.

## The approach that works: a swallowing `CGEventTap`

Move interception off the window entirely and down to the event stream:

- The overlay is **cosmetic only** — transparent, non-activating, non-key, and
  `ignoresMouseEvents = true`. It never disturbs the app below. It just draws the dimming,
  the selection rectangle, and our own crosshair.
- A **session-level `CGEventTap`** (`.cgSessionEventTap`, `.defaultTap`) intercepts mouse
  events and returns `nil` to **swallow** them (`mouseMoved`, `leftMouseDown`,
  `leftMouseDragged`, `leftMouseUp`).

Because the tap swallows every mouse event before it reaches any other process, the app
underneath receives **nothing** from the moment the tap goes live. Its cursor position, from
its point of view, is frozen exactly where it was when the shortcut fired, so its hover
state stays latched for as long as the tap runs. No window is layered into hit-testing, so
there's no appearance-exit. We never activate our app or take key focus, so there's no
`blur`/deactivation either.

### The virtual cursor

Swallowing mouse-moved events also freezes the **real** on-screen cursor (the window server
moves the cursor as part of delivering the event we're consuming). That's actually required
— a frozen real cursor is what keeps the app's hover pinned. So we:

1. Read `mouseEventDeltaX` / `mouseEventDeltaY` off each swallowed event and integrate them
   into a **virtual cursor** position (clamped to the union of all screens). Note CGEvent's
   delta-Y is top-left-origin (down positive) while Cocoa is bottom-left-origin, so we
   subtract it.
2. Warp the real cursor to that virtual position with `CGWarpMouseCursorPosition` so it
   visibly follows the mouse. Warping repositions the cursor **without posting a mouse
   event**, so the app underneath still sees no movement and keeps its hover state — while
   the user still sees a normal, moving cursor.
3. Interpret down → drag → up as the selection. Clicks never leak because we swallowed them.

(We warp the real cursor rather than hide it and draw a synthetic crosshair — either works;
warping keeps the familiar system cursor and needs no teardown to restore it.)

### Capture

When the drag ends we capture the selected region with `SCScreenshotManager`
(ScreenCaptureKit, macOS 14+), using an `SCContentFilter` that **excludes our own app** so
the overlay chrome never lands in the image. Capture runs while the tap is still active, so
the app below is still frozen and its hover UI is genuinely still on screen. Then we tear
everything down.

## Permissions

- **Screen Recording** — to capture pixels (already required by ScreenHint).
- **Accessibility** — required to create a *swallowing* event tap. macOS surfaces this as
  "allow ScreenHint to control this computer / other apps." We gate on
  `AXIsProcessTrustedWithOptions(prompt: true)`, which shows the system prompt when it's
  missing.

No new entitlements are needed, and — importantly — this works **inside the App Sandbox**,
so ScreenHint remains eligible for the Mac App Store. (Verified: a sandboxed build can both
receive and swallow other apps' mouse events once Accessibility is granted.)

## Safety

A stuck cursor or a permanently-swallowing tap is the dangerous failure mode, so teardown
runs on **every** exit path (finish, cancel, error, app termination) and always:

- disables and removes the tap,
- calls `CGDisplayShowCursor`,
- orders out the overlays.

In addition:

- `.tapDisabledByTimeout` / `.tapDisabledByUserInput` callbacks re-enable the tap (macOS
  disables taps it thinks are too slow).
- A **watchdog timer** force-ends the capture if it runs too long.
- **Escape** cancels, via a Carbon hotkey that doesn't depend on the tap or key focus.

## Known limitation

Timer-driven auto-hide UI still fades — e.g. YouTube's control bar hides after its ~3s idle
timeout because we're swallowing the moves that would reset it. Three seconds is plenty of
time to drag a selection, and Apple's own Screenshot tool behaves the same way, so this is
accepted rather than worked around.

## Where this lives in the code

- `ScreenHint/SecretWindowController.swift` — the cosmetic overlay panel + `OverlayView`
  drawing (dim, selection punch-out, crosshair).
- `ScreenHint/ScreenHintApp.swift` — the event tap lifecycle (`startEventTap`,
  `handleTapEvent`, virtual-cursor integration, `finishSelection`, `endCaptureHint`) and the
  Accessibility check.
- `ScreenHint/HintWindowController.swift` — `captureImage(of:on:)` (ScreenCaptureKit).
