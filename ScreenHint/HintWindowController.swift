//
//  HintWindowController.swift
//  ScreenHint
//
//  Created by Salem on 6/13/21.
//

import Foundation
import AppKit
import SwiftUI
import Vision
import UniformTypeIdentifiers
import ScreenCaptureKit

class HintWindowController:  NSWindowController, NSWindowDelegate, CopyDelegate, NSMenuDelegate {
    
    var hintWindow: HintWindow
    var screenshot: CGImage?
    
    // Menu items we need to hold a reference to (they need to have their checkmark state changed depending
    // on the state of the hint)
    var allDesktopsMenuItem: NSMenuItem?
    var borderlessModeMenuItem: NSMenuItem?
    
    // Hint state
    @AppStorage("pinToScreen") private var defaultPinToDesktop = false
    var pinToDesktop = false
    var isBorderless = false
        
    init(_ rect: NSRect, screenshot: CGImage) {
        let window = HintWindow(contentRect: rect, styleMask: [.resizable], backing: .buffered, defer: false)

        self.hintWindow = window
        self.screenshot = screenshot
        super.init(window: window)

        // TODO: use instance method to initialize this
        self.pinToDesktop = defaultPinToDesktop;
        if (self.pinToDesktop) {
            window.collectionBehavior = [.managed]
        } else {
            window.collectionBehavior = [.canJoinAllSpaces]
        }
        
        self.shouldSetBorderlessMode(self.isBorderless);
        
        window.delegate = self
        window.copyDelegate = self
        
        // Initialize the menu
        // TODO: put this in its own method
        let menu = NSMenu()
        
        ///
        /// These menu items are commands that can be taken on the hint
        ///
        
        let copyItem = menu.addItem(withTitle: "Copy", action:#selector(self.menuCopyHandler(_:)), keyEquivalent: "C")
        copyItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        copyItem.keyEquivalentModifierMask = [.command]
        copyItem.target = self
        
        let copyTextItem = menu.addItem(withTitle: "Copy Text", action:#selector(self.menuCopyTextHandler(_:)), keyEquivalent: "X")
        copyTextItem.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: nil)
        copyTextItem.keyEquivalentModifierMask = [.command]
        copyTextItem.target = self
        
        menu.addItem(NSMenuItem.separator())
        
        ///
        /// These menu items represent per-hint settings that can be toggled on and off.
        ///
        
        let borderlessModeItem = menu.addItem(withTitle: "Hide Borders", action:#selector(self.borderlessModeHandler(_:)), keyEquivalent: "B")
        borderlessModeItem.image = NSImage(systemSymbolName: "square.dashed.inset.fill", accessibilityDescription: nil)
        borderlessModeItem.target = self
        borderlessModeItem.state = self.isBorderless ? .on : .off
        self.borderlessModeMenuItem = borderlessModeItem

        let showItem = menu.addItem(withTitle: "Show On All Desktops", action:#selector(self.menuShowOnAllDesktopsHandler(_:)), keyEquivalent: "")
        showItem.image = NSImage(systemSymbolName: "lock.open.desktopcomputer", accessibilityDescription: nil)
        showItem.state = self.pinToDesktop ? .off : .on
        showItem.target = self
        self.allDesktopsMenuItem = showItem
        
        menu.addItem(NSMenuItem.separator())
        
        ///
        /// These menu items are for using the hint elsewhere (saving, exporting, etc.)
        ///
        
        let saveAsItem = menu.addItem(withTitle: "Save As...", action:#selector(self.menuSaveAsHandler(_:)), keyEquivalent: "")
        saveAsItem.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: nil)
        saveAsItem.target = self;
        
        let openInPreviewItem = menu.addItem(withTitle: "Open", action:#selector(self.menuOpenWithPreviewHandler(_:)), keyEquivalent: "")
        openInPreviewItem.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: nil)
        openInPreviewItem.target = self;
        
        menu.addItem(NSMenuItem.separator())
        
        ///
        /// The "close" menu item lives a little separate, just to avoid accidental clicks
        ///
        let closeItem = menu.addItem(withTitle: "Delete Hint", action: #selector(self.menuCloseHandler(_:)), keyEquivalent: "");
        closeItem.image =  NSImage(systemSymbolName: "minus.circle", accessibilityDescription: nil)
        closeItem.target = self


        window.menu = menu

        // Put the captured image into the window.
        self.renderScreenshot()
    }

    //
    // --- Handlers ---
    //
    
    
    @objc func menuCopyTextHandler(_ sender: AnyObject?) {
        self.shouldCopyText()
    }
    
    @objc func menuCopyHandler(_ sender: AnyObject?) {
        self.shouldCopy()
    }
                                              
    @objc func borderlessModeHandler(_ sender: AnyObject?) {
        self.shouldSetBorderlessMode(!self.isBorderless)
    }
    
    @objc func menuShowOnAllDesktopsHandler(_ sender: AnyObject?) {
        self.shouldPinToDesktop(!self.pinToDesktop)
    }
    
    @objc func menuCloseHandler(_ sender: AnyObject?) {
        self.close()
    }
    
    @objc func menuSaveAsHandler(_ sender: AnyObject?) {
        self.shouldSaveImage();
    }
    
    @objc func menuOpenWithPreviewHandler(_ sender: AnyObject?) {
        self.shouldOpenImageInPreview()
    }
    
    //
    // -- Delegate methods
    //
    
    func windowDidBecomeKey(_ notification: Notification) {
        // If it's borderless, leave the hint alone.
        if (self.isBorderless) { return }
        
        // Otherwise, bolden the border when the window becomes key.
        self.animateBorderColor(for: self.hintWindow, to: CGColor.black)

    }
    
    func windowDidResignKey(_ notification: Notification) {
        // If it's borderless, leave the hint alone.
        if (self.isBorderless) { return }
        
        // Otherwise, reset the border when it resigns key
        self.animateBorderColor(for: self.hintWindow, to: CGColor.init(gray: 1.0, alpha: 0.1))
    }

    
    //
    // --- Instance methods
    //
    
    
    /**
     A utility to animate the border color of a window
     */
    private func animateBorderColor(for window: NSWindow, to color: CGColor, duration: CFTimeInterval = 0.15) {
        guard let layer = (window as? HintWindow)?.imageViewLayer else { return }

        let colorAnimation = CABasicAnimation(keyPath: "borderColor")
        colorAnimation.fromValue = layer.borderColor
        colorAnimation.toValue = color
        colorAnimation.duration = duration
        layer.borderColor = color

        layer.add(colorAnimation, forKey: "borderColorAnimation")
    }

    
    /**
     Sets whether or not the hint is in borderless mode (border and drop shadow are both hidden).
     */
    func shouldSetBorderlessMode(_ isBorderless: Bool) {
        self.isBorderless = isBorderless
        self.hintWindow.setBorderlessMode(isBorderless)
        self.borderlessModeMenuItem?.state = self.isBorderless ? .on : .off
    }
    
    /**
     Copies the current screenshot to the clipboard.
     */
    func shouldCopy() {
        guard let screenshot = self.screenshot else {
            return
        }
        
        let image = NSImage.init(cgImage: screenshot, size: self.window!.frame.size)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }
    
    /**
     Sets whether or not this hint should be pinned to the current desktop or not.
     */
    func shouldPinToDesktop(_ shouldPinToDesktop: Bool) {
        self.pinToDesktop = shouldPinToDesktop
        let newState: NSControl.StateValue = shouldPinToDesktop ? .on : .off;
        self.allDesktopsMenuItem?.state = newState;
        self.hintWindow.shouldPinToDesktop(shouldPinToDesktop)
    }
    
    /**
     Attempts to extract text from the current screenshot and then copies it to the clipboard (in `handleRecognizeText`).
     */
    func shouldCopyText() {
        guard let cgImage = self.screenshot else { return }
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest(completionHandler: handleRecognizeText)
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        do {
            try requestHandler.perform([request])
        } catch {
            print("Unable to perform the requests: \(error).")
        }
    }
    
    /**
     Allow the user to save the screenshot to disk
     */
    func shouldSaveImage() {
        guard let image = self.screenshot else { return }
        let savePanel = NSSavePanel()
        savePanel.level = .screenSaver
        savePanel.allowedContentTypes = [.png]
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        let time =  formatter.string(from: Date())
        savePanel.nameFieldStringValue = "ScreenHint - \(time)"

        
        savePanel.begin(completionHandler: { (result) in
            if result == .OK, let url = savePanel.url {
                guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
                    return
                }
                CGImageDestinationAddImage(dest, image, nil)
                CGImageDestinationFinalize(dest)
            }
        })
    }
    
    func shouldOpenImageInPreview() {
        guard let image = self.screenshot else { return }
        let nsImage = NSImage(cgImage: image, size: NSZeroSize)
        guard let tiffData = nsImage.tiffRepresentation else { return }
        let temporaryFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp_image.tiff")

        do {
            try tiffData.write(to: temporaryFileURL)
        } catch {
            // Handle error if write fails
            return
        }
        
        // Try to open the file locally with the default app
        NSWorkspace.shared.open(temporaryFileURL)
    }
    
    
    /**
     Callback for VisionKit's text recognition process.
     */
    func handleRecognizeText(request: VNRequest, error: Error?) {
        guard let observations =
                request.results as? [VNRecognizedTextObservation] else {
            return
        }
        let recognizedStrings = observations.compactMap { observation in
            // Return the string of the top VNRecognizedText instance.
            return observation.topCandidates(1).first?.string
        }
        
        // Process the recognized strings.
        print(recognizedStrings)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(recognizedStrings.joined(separator: "\n"), forType: .string)

    }

    override func rightMouseUp(with event: NSEvent) {
        let point = NSEvent.mouseLocation;
        self.window!.menu?.popUp(positioning: nil, at: point, in: nil)
    }
    
    /**
     Capture the region described by `rect` (in global, bottom-left-origin screen
     coordinates).

     The selection can span more than one display (e.g. a laptop screen with an external
     monitor stacked above it), so we capture every display the rect touches and composite
     the pieces into a single image that is exactly `rect`-sized. Capturing only one
     display and cropping would yield an image smaller than the hint window, which the
     window then stretches to fit.

     This uses ScreenCaptureKit and excludes ScreenHint's own windows from the capture,
     so neither the dimmed overlay nor the (not-yet-populated) hint window land in the
     image. Because we exclude by application, the capture can run while the overlay is
     still up and the app underneath is still starved of mouse events — which means the
     hover-triggered UI the user was pointing at is genuinely still on screen at capture
     time.
     */
    static func captureImage(of rect: NSRect, exceptingWindowIDs: [CGWindowID] = []) async throws -> CGImage {
        // Every display the selection touches, not just the one it started on.
        let screens = NSScreen.screens.filter { $0.frame.intersects(rect) }
        guard !screens.isEmpty else {
            throw CaptureError.displayNotFound
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        // Exclude our own process so the overlay chrome never shows up in the shot, but
        // make exceptions for existing hint windows so they can be captured inside new hints.
        let ourApp = content.applications.first {
            $0.processID == ProcessInfo.processInfo.processIdentifier
        }
        let exceptedWindows = content.windows.filter { exceptingWindowIDs.contains($0.windowID) }

        var captures: [DisplayCapture] = []

        for screen in screens {
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
                  let display = content.displays.first(where: { $0.displayID == displayID }) else {
                continue
            }

            let filter = SCContentFilter(display: display,
                                         excludingApplications: ourApp.map { [$0] } ?? [],
                                         exceptingWindows: exceptedWindows)

            let screenFrame = screen.frame
            let scale = screen.backingScaleFactor

            // Capture the full display at native pixel resolution (no sourceRect), then crop
            // in software. This sidesteps any ambiguity in how SCKit interprets sourceRect
            // coordinates and guarantees a native-density image.
            let config = SCStreamConfiguration()
            config.width = Int(screenFrame.width * scale)
            config.height = Int(screenFrame.height * scale)
            config.scalesToFit = false
            config.showsCursor = false

            let fullImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            captures.append(DisplayCapture(frame: screenFrame,
                                           scale: scale,
                                           colorSpace: screen.colorSpace?.cgColorSpace,
                                           image: fullImage))
        }

        guard !captures.isEmpty else {
            throw CaptureError.displayNotFound
        }

        return try Self.composite(rect, from: captures)
    }

    /**
     Composite the given per-display captures into a single `rect`-sized image, in global
     (bottom-left-origin) screen coordinates. Pure pixel math — no ScreenCaptureKit, no
     `NSScreen` — so it can be exercised with synthetic displays in tests.
     */
    static func composite(_ rect: NSRect, from captures: [DisplayCapture]) throws -> CGImage {
        guard !captures.isEmpty else {
            throw CaptureError.displayNotFound
        }

        // Composite at the highest density in play, so a Retina slice of the selection
        // isn't downsampled to match a 1x monitor sitting next to it. A 1x slice does get
        // upscaled, but that only invents detail it never had — the alternative throws
        // real pixels away.
        let outputScale = captures.map { $0.scale }.max() ?? 2.0
        let outputWidth = Int((rect.width * outputScale).rounded())
        let outputHeight = Int((rect.height * outputScale).rounded())
        guard outputWidth > 0, outputHeight > 0 else {
            throw CaptureError.compositeFailed
        }

        // Capture each display's slice of the selection, paired with where that slice
        // belongs in the finished image.
        var pieces: [(image: CGImage, destination: CGRect)] = []

        for capture in captures {
            let screenFrame = capture.frame
            let scale = capture.scale
            let fullImage = capture.image

            // The part of the selection that actually lives on this display.
            let slice = screenFrame.intersection(rect)
            guard !slice.isNull, slice.width >= 1, slice.height >= 1 else { continue }

            // Source pixels. CGImage.cropping takes pixel coordinates with a top-left
            // origin, so flip the Cocoa rect. Snap to whole pixels ourselves (cropping
            // would quantize anyway) and clamp, so the destination below can be derived
            // from the pixels we actually got.
            let imageBounds = CGRect(x: 0, y: 0, width: fullImage.width, height: fullImage.height)
            let crop = CGRect(x: ((slice.minX - screenFrame.minX) * scale).rounded(),
                              y: ((screenFrame.maxY - slice.maxY) * scale).rounded(),
                              width: (slice.width * scale).rounded(),
                              height: (slice.height * scale).rounded())
                .intersection(imageBounds)
            guard !crop.isNull, crop.width >= 1, crop.height >= 1,
                  let piece = fullImage.cropping(to: crop) else { continue }

            // Destination pixels, snapped to the composite's own grid. The selection rect
            // comes from cursor positions and is rarely on a whole point, so an unsnapped
            // destination would land off-grid and make CoreGraphics resample every slice —
            // which reads as the whole hint being softer than the screen it came from.
            // Snapped, a display whose scale matches outputScale blits 1:1 and is resampled
            // not at all.
            let ratio = outputScale / scale
            let destination = CGRect(x: ((slice.minX - rect.minX) * outputScale).rounded(),
                                     y: ((slice.minY - rect.minY) * outputScale).rounded(),
                                     width: (CGFloat(piece.width) * ratio).rounded(),
                                     height: (CGFloat(piece.height) * ratio).rounded())
            pieces.append((piece, destination))
        }

        guard !pieces.isEmpty else {
            throw CaptureError.displayNotFound
        }

        // Single display — by far the common case. The crop already is the whole selection
        // at native density, so hand back those exact pixels rather than blitting them
        // through a context where they could pick up a resample.
        if pieces.count == 1,
           pieces[0].destination.origin == .zero,
           pieces[0].image.width == outputWidth,
           pieces[0].image.height == outputHeight {
            return pieces[0].image
        }

        let colorSpace = captures.first?.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil,
                                      width: outputWidth,
                                      height: outputHeight,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                                                | CGBitmapInfo.byteOrder32Little.rawValue) else {
            throw CaptureError.compositeFailed
        }

        // Displays needn't tile perfectly — stacked screens of different widths leave dead
        // space inside a spanning selection. Fill it rather than leaving it undefined.
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))

        // The context has a bottom-left origin, matching Cocoa screen coordinates.
        for piece in pieces {
            let isOneToOne = Int(piece.destination.width) == piece.image.width
                          && Int(piece.destination.height) == piece.image.height
            context.interpolationQuality = isOneToOne ? .none : .high
            context.draw(piece.image, in: piece.destination)
        }

        guard let composite = context.makeImage() else {
            throw CaptureError.compositeFailed
        }
        return composite
    }

    /**
     Put the already-captured screenshot into the hint window and finish styling it.
     */
    private func renderScreenshot() {
        guard let screenshot = self.screenshot, let window = self.window else {
            return
        }

        // Make sure the window keeps its aspect ratio when resizing
        window.aspectRatio = window.frame.size

        // Use the content view's actual bounds so the image view always fills it exactly,
        // with no 1px gaps from window-frame vs content-view coordinate differences.
        let contentBounds = window.contentView?.bounds ?? NSRect(origin: .zero, size: window.frame.size)

        // Setting the NSImage size to the content area in points (not .zero) tells AppKit
        // the pixel data is 2x on Retina, so it renders at native density.
        let image = NSImage(cgImage: screenshot, size: contentBounds.size)
        image.resizingMode = .stretch
        let imageView = WindowDraggableImageView(frame: contentBounds)
        imageView.image = image
        imageView.autoresizingMask = [.height, .width]
        imageView.imageScaling = .scaleProportionallyUpOrDown

        // Apply visual styling to the image view layer so the content view stays
        // rectangular and fully covers the window background (no corner bleed-through).
        imageView.wantsLayer = true
        imageView.layer?.borderWidth = 1
        imageView.layer?.borderColor = CGColor(gray: 1.0, alpha: 0.1)

        window.level = .floating
        window.isOpaque = true
        window.contentView?.addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

enum CaptureError: Error {
    /// The screen the selection was drawn on couldn't be matched to a capturable display.
    case displayNotFound
    /// The per-display captures succeeded but compositing them into one image failed.
    case compositeFailed
}

/// One display's contribution to a capture: where it sits in global (bottom-left origin)
/// screen coordinates, its backing scale, and a full-display image at native pixel density.
struct DisplayCapture {
    let frame: NSRect
    let scale: CGFloat
    let colorSpace: CGColorSpace?
    let image: CGImage
}

