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
        guard let layer = window.contentView?.layer else { return }

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
     coordinates) on the given screen.

     This uses ScreenCaptureKit and excludes ScreenHint's own windows from the capture,
     so neither the dimmed overlay nor the (not-yet-populated) hint window land in the
     image. Because we exclude by application, the capture can run while the overlay is
     still up and the app underneath is still starved of mouse events — which means the
     hover-triggered UI the user was pointing at is genuinely still on screen at capture
     time.
     */
    static func captureImage(of rect: NSRect, on screen: NSScreen) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.displayNotFound
        }

        // Exclude our own process so the overlay/hint chrome never shows up in the shot.
        let ourApp = content.applications.first {
            $0.processID == ProcessInfo.processInfo.processIdentifier
        }
        let filter = SCContentFilter(display: display,
                                     excludingApplications: ourApp.map { [$0] } ?? [],
                                     exceptingWindows: [])

        // sourceRect wants points in the display's coordinate space (top-left origin),
        // so flip the global (bottom-left origin) rect within its screen.
        let screenFrame = screen.frame
        let sourceRect = CGRect(x: rect.minX - screenFrame.minX,
                                y: screenFrame.maxY - rect.maxY,
                                width: rect.width,
                                height: rect.height)

        let scale = screen.backingScaleFactor
        let config = SCStreamConfiguration()
        config.sourceRect = sourceRect
        // width/height are in pixels, so scale the points up by the display's backing factor.
        config.width = Int(rect.width * scale)
        config.height = Int(rect.height * scale)
        config.scalesToFit = false
        config.showsCursor = false
        config.captureResolution = .best

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
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

        // Make an image and an imageview to put the screenshot in
        let image = NSImage(cgImage: screenshot, size: .zero)
        image.resizingMode = .stretch
        let imageView = WindowDraggableImageView(frame: NSRect(origin: .zero, size: window.frame.size))
        imageView.image = image

        // Make sure the imageView fills the window
        imageView.autoresizingMask = [.height, .width]
        // and that it will scale larger than its original size
        imageView.imageScaling = .scaleProportionallyUpOrDown

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
}

