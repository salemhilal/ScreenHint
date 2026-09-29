//
//  CopyFeedbackTests.swift
//  ScreenHintTests
//
//  Copying a hint (or its text) used to happen silently, and Copy Text could fail silently
//  too: Vision's `.accurate` mode returns nothing at all for some image sizes, and an empty
//  result would still clear the clipboard. These tests cover the recognition fallback, the
//  clipboard staying intact when there's no text, the confirmation badge, and the context
//  menu's keyboard shortcuts actually firing.
//

import AppKit
import Testing
@testable import ScreenHint

@Suite("Copy feedback")
@MainActor
struct CopyFeedbackTests {

    /// Black lines of text on white, like a hint of a document.
    private func textImage(width: Int, height: Int, lines: Int, fontSize: CGFloat = 24) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        for i in 0..<lines {
            let y = height - Int(fontSize * 2) * (i + 1)
            ("Line \(i) remember the milk" as NSString).draw(
                at: NSPoint(x: 20, y: y),
                withAttributes: [.font: NSFont.systemFont(ofSize: fontSize), .foregroundColor: NSColor.black])
        }
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()!
    }

    private func keyEvent(_ characters: String, _ modifiers: NSEvent.ModifierFlags, in window: NSWindow) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
                         windowNumber: window.windowNumber, context: nil, characters: characters,
                         charactersIgnoringModifiers: characters, isARepeat: false, keyCode: 0)!
    }

    @Test("text is recognized even at a size where Vision's accurate mode returns nothing")
    func recognizesTextWhereAccurateModeComesUpEmpty() {
        // 2400x1500 is one of the sizes where `.accurate` silently finds no text.
        let image = textImage(width: 2400, height: 1500, lines: 20)
        let lines = HintWindowController.recognizeText(in: image)
        #expect(lines.count == 20)
        #expect(lines.first?.contains("remember the milk") == true)
    }

    @Test("recognizing a blank image finds no text")
    func blankImageHasNoText() {
        let image = TestImages.solid(width: 400, height: 300, color: TestColor.white)
        #expect(HintWindowController.recognizeText(in: image).isEmpty)
    }

    @Test("copying no text leaves the clipboard alone and says so")
    func emptyTextLeavesClipboardAlone() {
        let controller = HintWindowController(NSRect(x: 0, y: 0, width: 200, height: 100),
                                              screenshot: TestImages.solid(width: 400, height: 200, color: TestColor.white))
        defer { controller.window?.close() }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("something the user copied earlier", forType: .string)

        #expect(controller.copyText([]) == false)
        #expect(NSPasteboard.general.string(forType: .string) == "something the user copied earlier")
        #expect(controller.hintWindow.badge?.label.stringValue == "No text found")
    }

    @Test("copying text puts the lines on the clipboard and confirms it")
    func copyingTextConfirms() {
        let controller = HintWindowController(NSRect(x: 0, y: 0, width: 200, height: 100),
                                              screenshot: TestImages.solid(width: 400, height: 200, color: TestColor.white))
        defer { controller.window?.close() }

        #expect(controller.copyText(["first line", "second line"]) == true)
        #expect(NSPasteboard.general.string(forType: .string) == "first line\nsecond line")
        #expect(controller.hintWindow.badge?.label.stringValue == "Text copied")
    }

    @Test("copying the hint shows a badge that doesn't get in the way")
    func copyShowsBadge() {
        let controller = HintWindowController(NSRect(x: 0, y: 0, width: 200, height: 100),
                                              screenshot: TestImages.solid(width: 400, height: 200, color: TestColor.red))
        defer { controller.window?.close() }

        controller.shouldCopy()

        let badge = controller.hintWindow.badge
        #expect(badge?.label.stringValue == "Copied")
        // Clicks and drags go straight through to the hint.
        #expect(badge?.hitTest(NSPoint(x: 5, y: 5)) == nil)
        // The badge sits above the image, which stays the first subview (borderless mode relies on that).
        #expect(controller.hintWindow.imageViewLayer != nil)
        #expect(controller.hintWindow.contentView?.subviews.last === badge)
    }

    @Test("showing a second badge replaces the first")
    func newBadgeReplacesOld() {
        let controller = HintWindowController(NSRect(x: 0, y: 0, width: 200, height: 100),
                                              screenshot: TestImages.solid(width: 400, height: 200, color: TestColor.red))
        defer { controller.window?.close() }

        controller.hintWindow.showBadge("Copied")
        controller.hintWindow.showBadge("Text copied")

        let badges = controller.hintWindow.contentView?.subviews.compactMap { $0 as? HintBadgeView } ?? []
        #expect(badges.count == 1)
        #expect(badges.first?.label.stringValue == "Text copied")
    }

    @Test("the context menu's shortcuts work from the keyboard")
    func contextMenuShortcutsFire() {
        let controller = HintWindowController(NSRect(x: 0, y: 0, width: 200, height: 100),
                                              screenshot: TestImages.solid(width: 400, height: 200, color: TestColor.red))
        defer { controller.window?.close() }
        let window = controller.hintWindow

        // Hide Borders is listed as ⇧⌘B.
        #expect(window.performKeyEquivalent(with: keyEvent("B", [.command, .shift], in: window)))
        #expect(controller.isBorderless == true)

        // Copy is listed as ⌘C.
        #expect(window.performKeyEquivalent(with: keyEvent("c", [.command], in: window)))
        #expect(window.badge?.label.stringValue == "Copied")
    }
}
