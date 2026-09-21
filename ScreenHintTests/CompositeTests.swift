//
//  CompositeTests.swift
//  ScreenHintTests
//
//  Deterministic tests for HintWindowController.composite: pixel density, region/orientation
//  correctness, and artifact-freeness. No permissions or real display required — every
//  display is a synthetic DisplayCapture.
//

import AppKit
import Testing
@testable import ScreenHint

@Suite("HintWindowController.composite")
struct CompositeTests {

    // MARK: - Pixel density

    @Test("single 2x display produces double-density output")
    func singleDisplay2xDensity() throws {
        let frame = NSRect(x: 0, y: 0, width: 100, height: 50)
        let image = TestImages.solid(width: 200, height: 100, color: TestColor.red)
        let capture = DisplayCapture(frame: frame, scale: 2, colorSpace: nil, image: image)
        let output = try HintWindowController.composite(frame, from: [capture])
        #expect(output.width == 200)
        #expect(output.height == 100)
    }

    @Test("single 1x display keeps 1x density")
    func singleDisplay1xDensity() throws {
        let frame = NSRect(x: 0, y: 0, width: 100, height: 50)
        let image = TestImages.solid(width: 100, height: 50, color: TestColor.red)
        let capture = DisplayCapture(frame: frame, scale: 1, colorSpace: nil, image: image)
        let output = try HintWindowController.composite(frame, from: [capture])
        #expect(output.width == 100)
        #expect(output.height == 50)
    }

    @Test("a selection spanning a 2x and a 1x display uses the higher density")
    func mixedDensitySpanUsesHigherScale() throws {
        let frameA = NSRect(x: 0, y: 0, width: 100, height: 50)   // 2x
        let frameB = NSRect(x: 100, y: 0, width: 100, height: 50) // 1x
        let imageA = TestImages.solid(width: 200, height: 100, color: TestColor.red)
        let imageB = TestImages.solid(width: 100, height: 50, color: TestColor.blue)
        let captures = [
            DisplayCapture(frame: frameA, scale: 2, colorSpace: nil, image: imageA),
            DisplayCapture(frame: frameB, scale: 1, colorSpace: nil, image: imageB),
        ]
        let rect = NSRect(x: 0, y: 0, width: 200, height: 50)
        let output = try HintWindowController.composite(rect, from: captures)
        // outputScale is the max of the two (2), so width = rect.width * 2.
        #expect(output.width == 400)
        #expect(output.height == 100)
    }

    @Test("a fractional selection rounds cleanly with no black seam at the edge")
    func fractionalSelectionRoundsCleanly() throws {
        let frame = NSRect(x: 0, y: 0, width: 400, height: 400)
        let image = TestImages.solid(width: 800, height: 800, color: TestColor.green)
        let capture = DisplayCapture(frame: frame, scale: 2, colorSpace: nil, image: image)
        let rect = NSRect(x: 0, y: 0, width: 100.3, height: 50.7)
        let output = try HintWindowController.composite(rect, from: [capture])
        #expect(output.width == 201)
        #expect(output.height == 101)
        let reader = PixelReader(output)
        #expect(reader.isUniform())
        // The trailing row/column from the fractional rounding is source color, not a
        // transparent or black seam.
        #expect(reader[200, 100] == TestColor.green)
    }

    // MARK: - Region and orientation

    @Test("selecting the top-right quadrant returns the top-right pixels (pins the y-flip)")
    func topRightQuadrantMapsCorrectly() throws {
        let size = 100
        let image = TestImages.quadrants(width: size, height: size,
                                         topLeft: TestColor.red, topRight: TestColor.green,
                                         bottomLeft: TestColor.blue, bottomRight: TestColor.yellow)
        let frame = NSRect(x: 0, y: 0, width: size, height: size)
        let capture = DisplayCapture(frame: frame, scale: 1, colorSpace: nil, image: image)
        let half = CGFloat(size) / 2
        let rect = NSRect(x: half, y: half, width: half, height: half)
        let output = try HintWindowController.composite(rect, from: [capture])
        let reader = PixelReader(output)
        #expect(reader.isUniform())
        #expect(reader[0, 0] == TestColor.green)
    }

    @Test("displays stacked vertically land on the correct side of the seam")
    func stackedDisplaysLandOnCorrectSide() throws {
        let bottomFrame = NSRect(x: 0, y: 0, width: 100, height: 100)
        let topFrame = NSRect(x: 0, y: 100, width: 100, height: 100)
        let bottomImage = TestImages.solid(width: 100, height: 100, color: TestColor.red)
        let topImage = TestImages.solid(width: 100, height: 100, color: TestColor.blue)
        let captures = [
            DisplayCapture(frame: bottomFrame, scale: 1, colorSpace: nil, image: bottomImage),
            DisplayCapture(frame: topFrame, scale: 1, colorSpace: nil, image: topImage),
        ]
        // Straddles the seam: the lower half comes from the bottom (red) display, the
        // upper half from the top (blue) display.
        let rect = NSRect(x: 0, y: 50, width: 100, height: 100)
        let output = try HintWindowController.composite(rect, from: captures)
        let reader = PixelReader(output)
        #expect(reader[50, 10] == TestColor.blue) // near the top of the selection
        #expect(reader[50, 90] == TestColor.red)  // near the bottom of the selection
    }

    @Test("a selection extending past a display edge fills the gap with opaque black")
    func selectionPastEdgeFillsGapWithBlack() throws {
        let frame = NSRect(x: 0, y: 0, width: 100, height: 100)
        let image = TestImages.solid(width: 100, height: 100, color: TestColor.green)
        let capture = DisplayCapture(frame: frame, scale: 1, colorSpace: nil, image: image)
        let rect = NSRect(x: 0, y: 0, width: 150, height: 100)
        let output = try HintWindowController.composite(rect, from: [capture])
        let reader = PixelReader(output)
        #expect(reader[50, 50] == TestColor.green)
        #expect(reader[125, 50] == TestColor.black)
        #expect(reader.isFullyOpaque())
    }

    @Test("a dead corner from unequal display widths is filled with opaque black")
    func deadCornerFromUnequalWidthsIsFilled() throws {
        let bottomFrame = NSRect(x: 0, y: 0, width: 200, height: 100)   // wide
        let topFrame = NSRect(x: 0, y: 100, width: 100, height: 100)   // narrow, left-aligned
        let bottomImage = TestImages.solid(width: 200, height: 100, color: TestColor.magenta)
        let topImage = TestImages.solid(width: 100, height: 100, color: TestColor.cyan)
        let captures = [
            DisplayCapture(frame: bottomFrame, scale: 1, colorSpace: nil, image: bottomImage),
            DisplayCapture(frame: topFrame, scale: 1, colorSpace: nil, image: topImage),
        ]
        let rect = NSRect(x: 0, y: 0, width: 200, height: 200)
        let output = try HintWindowController.composite(rect, from: captures)
        let reader = PixelReader(output)
        #expect(reader[50, 50] == TestColor.cyan)     // top-left: narrow top display
        #expect(reader[150, 50] == TestColor.black)   // top-right: dead corner
        #expect(reader[50, 150] == TestColor.magenta) // bottom half: wide bottom display
        #expect(reader[150, 150] == TestColor.magenta)
        #expect(reader.isFullyOpaque())
    }

    // MARK: - Artifacts

    @Test("the single-display fast path preserves a 1px checkerboard exactly")
    func fastPathPreservesCheckerboardExactly() throws {
        let frame = NSRect(x: 0, y: 0, width: 50, height: 50)
        let image = TestImages.checkerboard(width: 50, height: 50, TestColor.black, TestColor.white)
        let capture = DisplayCapture(frame: frame, scale: 1, colorSpace: nil, image: image)
        let output = try HintWindowController.composite(frame, from: [capture])
        #expect(output.width == 50)
        #expect(output.height == 50)
        let reader = PixelReader(output)
        for y in 0..<50 {
            // PixelReader's y is top-left-origin; TestImages.checkerboard was filled in
            // bottom-left-origin drawing coordinates, so row y here is drawing row (height-1-y).
            let drawingRow = 50 - 1 - y
            for x in 0..<50 {
                let expected = (x + drawingRow) % 2 == 0 ? TestColor.black : TestColor.white
                #expect(reader[x, y] == expected, "checkerboard artifact at (\(x), \(y))")
            }
        }
    }

    @Test("a uniform-color capture composites to a byte-identical image")
    func uniformCaptureCompositesIdentically() throws {
        let frame = NSRect(x: 0, y: 0, width: 100, height: 100)
        let image = TestImages.solid(width: 100, height: 100, color: TestColor.magenta)
        let capture = DisplayCapture(frame: frame, scale: 1, colorSpace: nil, image: image)
        let rect = NSRect(x: 20, y: 20, width: 50, height: 50)
        let output = try HintWindowController.composite(rect, from: [capture])
        let reader = PixelReader(output)
        #expect(reader.isUniform())
        #expect(reader[0, 0] == TestColor.magenta)
    }

    @Test("every composite output is fully opaque")
    func compositeOutputIsAlwaysOpaque() throws {
        // Multi-display path (goes through the CGContext, not the single-display fast path).
        let frameA = NSRect(x: 0, y: 0, width: 100, height: 100)
        let frameB = NSRect(x: 100, y: 0, width: 100, height: 100)
        let imageA = TestImages.solid(width: 100, height: 100, color: TestColor.yellow)
        let imageB = TestImages.solid(width: 100, height: 100, color: TestColor.cyan)
        let captures = [
            DisplayCapture(frame: frameA, scale: 1, colorSpace: nil, image: imageA),
            DisplayCapture(frame: frameB, scale: 1, colorSpace: nil, image: imageB),
        ]
        let rect = NSRect(x: 0, y: 0, width: 200, height: 100)
        let output = try HintWindowController.composite(rect, from: captures)
        #expect(PixelReader(output).isFullyOpaque())
    }

    @Test("a multi-display composite of a single uniform color stays uniform")
    func multiDisplayUniformColorStaysUniform() throws {
        let frameA = NSRect(x: 0, y: 0, width: 100, height: 100)
        let frameB = NSRect(x: 100, y: 0, width: 100, height: 100)
        let imageA = TestImages.solid(width: 100, height: 100, color: TestColor.yellow)
        let imageB = TestImages.solid(width: 100, height: 100, color: TestColor.yellow)
        let captures = [
            DisplayCapture(frame: frameA, scale: 1, colorSpace: nil, image: imageA),
            DisplayCapture(frame: frameB, scale: 1, colorSpace: nil, image: imageB),
        ]
        let rect = NSRect(x: 0, y: 0, width: 200, height: 100)
        let output = try HintWindowController.composite(rect, from: captures)
        #expect(PixelReader(output).isUniform())
    }
}
