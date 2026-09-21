//
//  HintRenderingTests.swift
//  ScreenHintTests
//
//  A correctly captured, correctly composited screenshot can still render soft or
//  mis-cropped if HintWindowController wraps it wrong. These tests check the other half of
//  "correct pixel density": how the already-captured CGImage gets turned into what's on
//  screen and what ends up on the pasteboard.
//

import AppKit
import Testing
@testable import ScreenHint

// HintWindowController creates a real NSWindow, which AppKit requires happen on the main
// thread — Swift Testing otherwise runs test functions in parallel on background threads.
@Suite("Hint rendering")
@MainActor
struct HintRenderingTests {

    @Test("the rendered image's logical size matches the window's content in points, not pixels")
    func renderedImageUsesPointSizeNotPixelSize() {
        let rect = NSRect(x: 0, y: 0, width: 100, height: 50)
        let screenshot = TestImages.solid(width: 200, height: 100, color: TestColor.red) // 2x
        let controller = HintWindowController(rect, screenshot: screenshot)
        defer { controller.window?.close() }

        // AppKit renders an NSImage at native (Retina) density only when its logical `.size`
        // is set in points, not pixels — this is what makes the 2x screenshot actually render
        // at 2x instead of being treated as a 200x100-point image and shown twice too large.
        let imageView = controller.hintWindow.contentView?.subviews.first as? NSImageView
        #expect(imageView?.image?.size == NSSize(width: 100, height: 50))
    }

    @Test("window aspect ratio and image aspect ratio stay close for a fractional selection")
    func aspectRatioStaysCloseForFractionalSelection() {
        let rect = NSRect(x: 0, y: 0, width: 257.6, height: 143.2)
        let scale: CGFloat = 2
        let outputWidth = Int((rect.width * scale).rounded())
        let outputHeight = Int((rect.height * scale).rounded())
        let screenshot = TestImages.solid(width: outputWidth, height: outputHeight, color: TestColor.blue)
        let controller = HintWindowController(rect, screenshot: screenshot)
        defer { controller.window?.close() }

        let windowAspect = controller.window!.aspectRatio
        let windowRatio = windowAspect.width / windowAspect.height
        let imageRatio = CGFloat(screenshot.width) / CGFloat(screenshot.height)

        // outputWidth and outputHeight round independently in composite(_:from:), so a
        // fractional selection can produce an image whose aspect ratio isn't exactly the
        // window's. `.scaleProportionallyUpOrDown` resolves any mismatch by letterboxing, so
        // if this drifts past a barely-perceptible tolerance, treat it as a real finding
        // rather than a too-strict test.
        #expect(abs(windowRatio - imageRatio) < 0.01)
    }

    @Test("borderless mode toggles the image layer's border and the window's shadow")
    func borderlessModeTogglesBorderAndShadow() {
        let rect = NSRect(x: 0, y: 0, width: 100, height: 50)
        let screenshot = TestImages.solid(width: 100, height: 50, color: TestColor.green)
        let controller = HintWindowController(rect, screenshot: screenshot)
        defer { controller.window?.close() }

        #expect(controller.hintWindow.imageViewLayer?.borderWidth == 1)
        #expect(controller.hintWindow.hasShadow == true)

        controller.shouldSetBorderlessMode(true)
        #expect(controller.hintWindow.imageViewLayer?.borderWidth == 0)
        #expect(controller.hintWindow.hasShadow == false)

        controller.shouldSetBorderlessMode(false)
        #expect(controller.hintWindow.imageViewLayer?.borderWidth == 1)
        #expect(controller.hintWindow.hasShadow == true)
    }

    @Test("copy puts the screenshot's real pixel dimensions on the pasteboard, not the window's point size")
    func copyPreservesPixelDimensions() {
        let rect = NSRect(x: 0, y: 0, width: 100, height: 50)
        let screenshot = TestImages.solid(width: 300, height: 150, color: TestColor.yellow) // 3x
        let controller = HintWindowController(rect, screenshot: screenshot)
        defer { controller.window?.close() }

        controller.shouldCopy()

        let pasted = NSImage(pasteboard: .general)
        let rep = pasted?.representations.first
        #expect(rep?.pixelsWide == 300)
        #expect(rep?.pixelsHigh == 150)
    }
}
