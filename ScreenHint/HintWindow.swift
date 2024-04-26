//
//  HintWindow.swift
//  ScreenHint
//
//  Created by Salem Hilal on 6/18/22.
//

import Foundation
import SwiftUI

// should we consider having one delegate?
protocol CopyDelegate {
    func shouldCopy()
    func shouldCopyText()
}

protocol BorderDelegate {
    func shouldSetBorder()
}


/**
 This is a window that closes when you doubleclick it.
 */
class HintWindow: NSWindow {
    
    var copyDelegate: CopyDelegate?
    var borderDelegate: BorderDelegate?
    var screenshot: CGImage? = nil
    private var screenshotOpacity: Double = 1.0
    private var screenshotMinOpacity: Double = 0.2
    private var screenshotOpacityStep: Double = 0.05

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect:contentRect, styleMask:style, backing:backingStoreType, defer: flag)
        self.level = .screenSaver // Put this window on top of everything else
        self.backgroundColor = NSColor.blue
        self.ignoresMouseEvents = false
        self.isMovableByWindowBackground = true
        self.isMovable = true
        self.hasShadow = true // togged in borderless mode
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.borderWidth = 1 // toggled in borderless mode
        self.contentView?.layer?.borderColor = CGColor.init(gray: 1.0, alpha: 0.1)
        self.contentView?.layer?.cornerRadius = 3
        // Causes a fast fade-out (at least at time of writing)
        self.animationBehavior = .utilityWindow
    }
    
    // This window can receive keyboard commands
    override var canBecomeKey: Bool {
        get { return true }
    }
    
    // But it can _not_ become the main application window
    override var canBecomeMain: Bool {
        get { return false }
    }
    
    /**
     Handle keyboard shortcuts
     */
    override func keyDown(with event: NSEvent) {
      // Cmd +
      if event.modifierFlags.contains(.command) {
        // Shift +
        if event.modifierFlags.contains(.shift) {
          if event.charactersIgnoringModifiers == "C" { // C - copy
            copyDelegate?.shouldCopy()
          } else if event.charactersIgnoringModifiers == "B" { // B - border
            borderDelegate?.shouldSetBorder()
          } else if event.charactersIgnoringModifiers == "O" { // O - opacity
            showOpacitySlider()
          } else if event.charactersIgnoringModifiers == "X" { // X - copy text
            copyDelegate?.shouldCopyText()
          } else {
            switch event.keyCode {
            case 125: // down - opacity down
              screenshotOpacity = max(screenshotMinOpacity, (screenshotOpacity - screenshotOpacityStep))
              applyOpacity(screenshotOpacity)
            case 126: // up - opacity up
              screenshotOpacity = min(1, (screenshotOpacity + screenshotOpacityStep))
              applyOpacity(screenshotOpacity)
            default:
              break
            }
          }
        } else {
          switch event.keyCode {
          case 123: // left - move left
            setFrameOrigin(.init(x: frame.origin.x - 1, y: frame.origin.y))
          case 124: // right - move right
            setFrameOrigin(.init(x: frame.origin.x + 1, y: frame.origin.y))
          case 125: // down - move down
            setFrameOrigin(.init(x: frame.origin.x, y: frame.origin.y - 1))
          case 126: // up - move up
            setFrameOrigin(.init(x: frame.origin.x, y: frame.origin.y + 1))
          default:
            break
          }
        }
      }
    }
    
    /**
     Handle mouse events
     */
    override func mouseUp(with event: NSEvent) {
        // If this window is double-clicked (anywhere), close it.
        if event.clickCount >= 2 {
            // TODO: remove self from rects array
            self.windowController?.close();
        }
        super.mouseUp(with: event)
    }
    
    // --- Instance methods ---
    
    /**
     Set whether or not this window should be pinned to one desktop, or should sit on all desktops.
     */
    func shouldPinToDesktop(_ shouldPin: Bool) {
        self.collectionBehavior = shouldPin ? [.managed] : [.canJoinAllSpaces]
    }
    
    /**
     Set whether or not to show borders on this hint. Default is yes, we want a border.
     */
    func setBorderlessMode(_ isEnabled: Bool) {
        self.animateBorderlessMode(isEnabled)
        self.hasShadow = !isEnabled
        self.contentView?.layer?.cornerRadius = isEnabled ? 0 : 3
    }
  
    func showOpacitySlider() {
      guard let contentView else { return }
      let blurViewSize = CGSize(width: min(200, contentView.frame.width - 20), height: 30)
      
      let blurView = NSVisualEffectView()
      blurView.material = .popover
      blurView.blendingMode = .withinWindow
      blurView.state = .active
      blurView.wantsLayer = true
      blurView.layer?.cornerRadius = 4
      blurView.layer?.masksToBounds = true
      blurView.translatesAutoresizingMaskIntoConstraints = false
      contentView.addSubview(blurView)
      
      NSLayoutConstraint.activate([
        blurView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        blurView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        blurView.widthAnchor.constraint(equalToConstant: blurViewSize.width),
        blurView.heightAnchor.constraint(equalToConstant: blurViewSize.height)
      ])
      
      let sliderView = OpacitySlider(
        value: screenshotOpacity,
        minValue: screenshotMinOpacity,
        maxValue: 1.0,
        target: self,
        action: #selector(opacitySliderValueChanged)
      )
      sliderView.isContinuous = true
      sliderView.translatesAutoresizingMaskIntoConstraints = false
      sliderView.onRelease = { [weak self] value in
        self?.screenshotOpacity = value
        blurView.removeFromSuperview()
      }
      blurView.addSubview(sliderView)
      
      NSLayoutConstraint.activate([
        sliderView.centerXAnchor.constraint(equalTo: blurView.centerXAnchor),
        sliderView.centerYAnchor.constraint(equalTo: blurView.centerYAnchor),
        sliderView.widthAnchor.constraint(equalToConstant: blurViewSize.width - 20),
        sliderView.heightAnchor.constraint(equalToConstant: blurViewSize.height - 20)
      ])
    }
    
    private func animateBorderlessMode(_ isEnabled: Bool) {
        guard let layer = self.contentView?.layer else { return }

        let borderAnimation = CABasicAnimation(keyPath: "borderWidth")
        let newBorder = isEnabled ? 0.0 : 1.0
        borderAnimation.fromValue = layer.borderWidth
        borderAnimation.toValue = newBorder;
        borderAnimation.duration = 0.15
        layer.borderWidth = newBorder

        layer.add(borderAnimation, forKey: "borderWidthAnimation")
    }
}


/**
 This is an image view that passes drag events up to its parent window.
 */
class WindowDraggableImageView: NSImageView {
    
    // Without this, you have to focus on the parent window before this view
    // can be used to drag the window.
    override var mouseDownCanMoveWindow: Bool {
        get {
            return true
        }
    }
    
    override public func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
    
    override public func mouseDragged(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

// MARK: - Private Methods
private extension HintWindow {
  @objc func opacitySliderValueChanged(_ sender: NSSlider) {
    applyOpacity(sender.doubleValue)
  }
  
  class OpacitySlider: NSSlider {
    var onRelease: ((Double) -> Void)?
    
    override func mouseDown(with event: NSEvent) {
      super.mouseDown(with: event)
      onRelease?(doubleValue)
    }
  }
  
  func applyOpacity(_ value: Double) {
    contentView?.subviews.first { $0 is WindowDraggableImageView }?.layer?.opacity = Float(value)
  }
}
