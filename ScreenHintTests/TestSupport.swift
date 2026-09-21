//
//  TestSupport.swift
//  ScreenHintTests
//

import AppKit
import Foundation

/// A pixel's RGBA channels, each 0...255.
struct RGBA: Equatable {
    let r: UInt8
    let g: UInt8
    let b: UInt8
    let a: UInt8

    /// Whether every channel is within `tolerance` of `other`. Useful when a resample or
    /// color-space conversion is expected to introduce a little noise but the pixel should
    /// still read as "the same color."
    func isClose(to other: RGBA, tolerance: Int = 1) -> Bool {
        abs(Int(r) - Int(other.r)) <= tolerance &&
        abs(Int(g) - Int(other.g)) <= tolerance &&
        abs(Int(b) - Int(other.b)) <= tolerance &&
        abs(Int(a) - Int(other.a)) <= tolerance
    }
}

/// Draws a `CGImage` once into a known 8-bit sRGB premultiplied-last buffer with a
/// top-left origin, so pixel assertions never depend on the incoming image's own bitmap
/// layout (which SCScreenshotManager and CGContext.makeImage produce differently).
struct PixelReader {
    let width: Int
    let height: Int
    private let data: [UInt8]

    init(_ image: CGImage) {
        width = image.width
        height = image.height
        let bytesPerRow = width * 4
        var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &buffer,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // Verified empirically (RunCodeSnippet against a two-tone fixture): a CGImage's
        // row 0 already corresponds to its visual top, and CGContext.draw(_:in:) preserves
        // that — no manual flip needed for buffer row 0 to be the image's top row here.
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        data = buffer
    }

    /// Pixel at (x, y) with a top-left origin.
    subscript(x: Int, y: Int) -> RGBA {
        let offset = (y * width + x) * 4
        return RGBA(r: data[offset], g: data[offset + 1], b: data[offset + 2], a: data[offset + 3])
    }

    /// True if every pixel in `rect` (top-left origin, in this image's own pixel grid) is
    /// exactly the same color.
    func isUniform(in rect: CGRect = .infinite) -> Bool {
        let r = rect == .infinite ? CGRect(x: 0, y: 0, width: width, height: height) : rect
        guard let first = firstPixel(in: r) else { return true }
        for y in Int(r.minY)..<Int(r.maxY) {
            for x in Int(r.minX)..<Int(r.maxX) {
                if self[x, y] != first { return false }
            }
        }
        return true
    }

    /// True if no pixel in the image has alpha less than 255.
    func isFullyOpaque() -> Bool {
        for y in 0..<height {
            for x in 0..<width {
                if self[x, y].a < 255 { return false }
            }
        }
        return true
    }

    private func firstPixel(in rect: CGRect) -> RGBA? {
        guard rect.width >= 1, rect.height >= 1 else { return nil }
        return self[Int(rect.minX), Int(rect.minY)]
    }
}

/// Solid, exactly-representable colors (all components 0 or 1) for test fixtures.
/// `context.setFillColor(red:green:blue:alpha:)` sets DeviceRGB directly, and `PixelReader`
/// reads back through a DeviceRGB context too, so with these colors there's no color-space
/// conversion in either direction — pixel assertions can use exact equality.
enum TestColor {
    static let black = RGBA(r: 0, g: 0, b: 0, a: 255)
    static let white = RGBA(r: 255, g: 255, b: 255, a: 255)
    static let red = RGBA(r: 255, g: 0, b: 0, a: 255)
    static let green = RGBA(r: 0, g: 255, b: 0, a: 255)
    static let blue = RGBA(r: 0, g: 0, b: 255, a: 255)
    static let yellow = RGBA(r: 255, g: 255, b: 0, a: 255)
    static let magenta = RGBA(r: 255, g: 0, b: 255, a: 255)
    static let cyan = RGBA(r: 0, g: 255, b: 255, a: 255)

    static func setFill(_ context: CGContext, _ color: RGBA) {
        context.setFillColor(red: CGFloat(color.r) / 255, green: CGFloat(color.g) / 255,
                             blue: CGFloat(color.b) / 255, alpha: CGFloat(color.a) / 255)
    }
}

/// Synthetic image fixtures used to detect resampling, misplacement, and stray overlays.
/// All images are DeviceRGB so pixel values round-trip exactly through `PixelReader`.
enum TestImages {
    static func solid(width: Int, height: Int, color: RGBA) -> CGImage {
        makeImage(width: width, height: height) { context in
            TestColor.setFill(context, color)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    /// Four solid quadrants: top-left, top-right, bottom-left, bottom-right (in Cocoa's
    /// bottom-left-origin sense, matching how these images are later treated as display
    /// captures).
    static func quadrants(width: Int, height: Int,
                          topLeft: RGBA, topRight: RGBA,
                          bottomLeft: RGBA, bottomRight: RGBA) -> CGImage {
        makeImage(width: width, height: height) { context in
            let halfW = CGFloat(width) / 2
            let halfH = CGFloat(height) / 2
            TestColor.setFill(context, bottomLeft)
            context.fill(CGRect(x: 0, y: 0, width: halfW, height: halfH))
            TestColor.setFill(context, bottomRight)
            context.fill(CGRect(x: halfW, y: 0, width: halfW, height: halfH))
            TestColor.setFill(context, topLeft)
            context.fill(CGRect(x: 0, y: halfH, width: halfW, height: halfH))
            TestColor.setFill(context, topRight)
            context.fill(CGRect(x: halfW, y: halfH, width: halfW, height: halfH))
        }
    }

    /// A 1-device-pixel checkerboard. Exact blits preserve pure alternating colors;
    /// anything that resamples the image collapses it toward a flat mid-tone, which makes
    /// this the workhorse artifact/density detector.
    static func checkerboard(width: Int, height: Int, cell: Int = 1,
                             _ a: RGBA, _ b: RGBA) -> CGImage {
        makeImage(width: width, height: height) { context in
            for y in stride(from: 0, to: height, by: cell) {
                for x in stride(from: 0, to: width, by: cell) {
                    let isEven = ((x / cell) + (y / cell)) % 2 == 0
                    TestColor.setFill(context, isEven ? a : b)
                    context.fill(CGRect(x: x, y: y, width: cell, height: cell))
                }
            }
        }
    }

    private static func makeImage(width: Int, height: Int, draw: (CGContext) -> Void) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: nil,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: 0,
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                                          | CGBitmapInfo.byteOrder32Little.rawValue)!
        draw(context)
        return context.makeImage()!
    }
}

/// A borderless, opaque fixture window shown at a known global screen rect, used by the
/// live-capture tests to verify that a real `captureImage` call returns exactly what's on
/// screen — no overlay tint, no stray border, no resampling.
@MainActor final class FixtureWindow {
    let window: NSWindow

    init(rect: NSRect, content: NSView) {
        window = NSWindow(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .normal
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.contentView = content
        window.setFrame(rect, display: true)
    }

    /// Order the window front and wait a beat for the window server to actually composite
    /// it, so a capture taken right after this returns sees real pixels.
    func show() async {
        window.orderFrontRegardless()
        try? await Task.sleep(nanoseconds: 200_000_000)
    }

    func close() {
        window.orderOut(nil)
    }
}

/// Draws a checkerboard plus four distinct solid corner markers, so a single fixture can
/// pin both "did this resample" (checkerboard) and "did this pick up stray overlay pixels"
/// (corners, which are far from the overlay's own drawn edges).
final class FixtureView: NSView {
    var markerSize: CGFloat = 8

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        // NSColor.systemRed/systemGreen/etc. are Apple's muted semantic accent colors, not
        // pure primaries — using them here would make live-capture pixel assertions compare
        // against the wrong expected value. TestColor's setFill sets exact DeviceRGB values
        // directly on the context instead, matching what the deterministic tests compare against.
        TestColor.setFill(context, TestColor.black)
        context.fill(bounds)

        let cell: CGFloat = 1
        for y in stride(from: CGFloat(0), to: bounds.height, by: cell) {
            for x in stride(from: CGFloat(0), to: bounds.width, by: cell) {
                let isEven = (Int(x / cell) + Int(y / cell)) % 2 == 0
                TestColor.setFill(context, isEven ? TestColor.white : TestColor.black)
                context.fill(CGRect(x: x, y: y, width: cell, height: cell))
            }
        }

        TestColor.setFill(context, TestColor.red)
        context.fill(CGRect(x: 0, y: bounds.height - markerSize, width: markerSize, height: markerSize))
        TestColor.setFill(context, TestColor.green)
        context.fill(CGRect(x: bounds.width - markerSize, y: bounds.height - markerSize, width: markerSize, height: markerSize))
        TestColor.setFill(context, TestColor.blue)
        context.fill(CGRect(x: 0, y: 0, width: markerSize, height: markerSize))
        TestColor.setFill(context, TestColor.yellow)
        context.fill(CGRect(x: bounds.width - markerSize, y: 0, width: markerSize, height: markerSize))
    }
}
