//
//  OnboardingView.swift
//  ScreenHint
//
//  Created by Salem Hilal on 7/8/23.
//

import SwiftUI
import SwiftUIPager
import AVFoundation
import KeyboardShortcuts

enum OnboardingPage: CaseIterable {
    case welcome, permissions, makeHint, useHint, settings, thanks
}

/// Width of each tour page's text and illustration column.
private let onboardingContentWidth: CGFloat = 480

struct OnboardingWelcomeView: View {
    @ObservedObject var page: Page
    
    var body: some View {
        VStack {
            Spacer()
            Text("Welcome to ScreenHint.")
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.semibold)
                .padding(.bottom)
            Text("""
                This guide will walk you through the basics of making and using hints.
                
                If you already know how to use ScreenHint, or if you would rather show yourself around, you can close this guide and access it later from the toolbar menu.
                """)
                .font(.system(.title3))
                .frame(width: onboardingContentWidth)
            Spacer()
            Spacer()
            HStack {
                Button(action: {
                    NSApplication.shared.keyWindow?.close()
                }) {
                    Text("Maybe later")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.link)
                .controlSize(.large)
                Spacer()
                Button(action: { withAnimation {
                    self.page.update(.next)
                }}) {
                    Text("Next")
                        .frame(minWidth: 100)
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                
            }
            .padding()
        }
    }
}

/// The same permission rows as the Permissions window and Settings, as a tour step.
struct OnboardingPermissionsView: View {
    @ObservedObject var page: Page
    @StateObject private var permissions = PermissionsModel()

    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                Text("First, two permissions.")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.semibold)
                    .padding(.vertical)

                Text("Hints are screenshots you select with your mouse, so ScreenHint needs to see your screen and follow your mouse while you select.")
                    .font(.system(.title3))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom)

                PermissionsList(model: permissions)
                    .font(.system(.body))
                    .padding(.vertical)

                if permissions.allGranted {
                    Label("You're all set.", systemImage: "checkmark.circle.fill")
                        .font(.system(.title3))
                        .foregroundStyle(.green)
                }
            }
            .frame(width: onboardingContentWidth)

            Spacer()

            HStack {
                Button(action: { withAnimation {
                    self.page.update(.previous)
                }}) {
                    Text("Back").frame(minWidth: 100)
                }
                .buttonStyle(.link)
                .controlSize(.large)
                Spacer()
                Button(action: { withAnimation {
                    self.page.update(.next)
                }}) {
                    Text("Next").frame(minWidth: 100)
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }
}

struct OnboardingMakeHintView: View {
    @ObservedObject var page: Page
    
    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                
                DemoVideoView(isActive: page.index == OnboardingPage.allCases.firstIndex(of: .makeHint))
                    .aspectRatio(DemoVideoView.aspectRatio, contentMode: .fit)
                    .padding(.vertical)
                
                Text("A hint is a floating screenshot.")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.semibold)
                    .padding(.bottom)
                
                Text("""
                    Create a hint by selecting **"New Hint"** from ScreenHint's menu bar icon, and then clicking and dragging to select a portion of your screen.
                    
                    You can **move** hints by dragging them around.
                    
                    You can **resize** hints by dragging their edges.
                    """)
                    .font(.system(.title3))
                    .padding(.bottom)

                // Starts the same flow as "New Hint" in the menu and the global shortcut.
                Button(action: {
                    (NSApp.delegate as? ScreenHintAppDelegate)?.captureHint(nil)
                }) {
                    Label("Click here to make a Hint", systemImage: "rectangle.dashed")
                }
                .controlSize(.large)
            }
            .frame(width: onboardingContentWidth)
            
            Spacer()
            
            HStack {
                Button(action: { withAnimation {
                    self.page.update(.previous)
                }}) {
                    Text("Back")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.link)
                .controlSize(.large)
                Spacer()
                Button(action: { withAnimation {
                    self.page.update(.next)
                }}) {
                    Text("Next")
                        .frame(minWidth: 100)
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                
            }
            .padding()
        }
    }
}

/**
 The demo video from screenhint.com's home page: making a hint, dragging it aside, and double-clicking
 it away. It has no controls. It plays once each time its page comes into view (unless Reduce Motion
 is on) and stops on its last frame, which matches the first; clicking it plays it again.
 */
struct DemoVideoView: NSViewRepresentable {
    static let aspectRatio: CGFloat = 800 / 464

    var isActive: Bool

    func makeNSView(context: Context) -> DemoVideoPlayerView {
        DemoVideoPlayerView()
    }

    func updateNSView(_ view: DemoVideoPlayerView, context: Context) {
        view.setActive(isActive)
    }
}

final class DemoVideoPlayerView: NSView {
    private let player: AVPlayer?
    private var isActive = false

    init() {
        if let url = Bundle.main.url(forResource: "Onboarding.Demo", withExtension: "mp4") {
            player = AVPlayer(url: url)
        } else {
            player = nil
        }
        super.init(frame: .zero)

        player?.isMuted = true
        player?.actionAtItemEnd = .pause

        // Layer-hosting view: a plain container holding the player layer, rounded and outlined to
        // match the tour's other illustrations. The video ignores cornerRadius/masksToBounds
        // clipping (on the player layer or the container), so the corners come from a mask.
        let container = CALayer()
        container.borderWidth = 1
        container.borderColor = NSColor.gray.cgColor
        container.cornerRadius = 5
        container.mask = cornerMask

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        container.addSublayer(playerLayer)

        layer = container
        wantsLayer = true

        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Demo video")
        setAccessibilityHelp("A keyboard shortcut dims the screen, part of the Weather app is selected and becomes a floating hint, the hint is dragged aside, and a double-click closes it. Press to play it again.")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Rounds the video's corners; sized to the view in `layout()`.
    private let cornerMask = CAShapeLayer()

    override func layout() {
        super.layout()
        cornerMask.frame = bounds
        cornerMask.path = CGPath(roundedRect: bounds, cornerWidth: 5, cornerHeight: 5, transform: nil)
    }

    /// Play from the start when the page comes into view, and pause when it leaves.
    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        if active {
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                playFromStart()
            }
        } else {
            player?.pause()
        }
    }

    private func playFromStart() {
        player?.seek(to: .zero)
        player?.play()
    }

    private var isPlaying: Bool {
        (player?.rate ?? 0) != 0
    }

    /// Click: pause if playing, otherwise play (from the start if it has finished).
    func togglePlayback() {
        if isPlaying {
            player?.pause()
        } else if let item = player?.currentItem, item.currentTime() >= item.duration {
            playFromStart()
        } else {
            player?.play()
        }
    }

    override func mouseDown(with event: NSEvent) {
        togglePlayback()
    }

    // Keyboard: focusable (only while its page is showing, so Tab can't land on it from another
    // page), and Space plays or pauses. Return is left to the page's default button.
    override var acceptsFirstResponder: Bool { isActive }

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " " {
            togglePlayback()
        } else {
            super.keyDown(with: event)
        }
    }

    override var focusRingMaskBounds: NSRect { bounds }

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5).fill()
    }

    override func accessibilityPerformPress() -> Bool {
        togglePlayback()
        return true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

struct OnboardingUseHintView: View {
    @ObservedObject var page: Page
    
    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                
                Image("Onboarding.CopyHint")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray, lineWidth:1))
                    .padding(.vertical)

                Text("You can do a lot with hints.")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.semibold)
                    .padding(.bottom)
                
                Text("""
                    Hints can be copied, saved, collaged, and can even have identifiable text extracted.
                    
                    **Right-click** a hint to see all of the available actions.
                    
                    When you're done, **double-click** a hint to close it.
                    """)
                    .font(.system(.title3))
                
            }
            .frame(width: onboardingContentWidth)
            
            Spacer()
            
            HStack {
                Button(action: { withAnimation {
                    self.page.update(.previous)
                }}) {
                    Text("Back").frame(minWidth: 100)
                }
                .buttonStyle(.link)
                .controlSize(.large)
                
                Spacer()
                
                Button(action: { withAnimation {
                    self.page.update(.next)
                }}) {
                    Text("Next").frame(minWidth: 100)
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                
            }
            .padding()
        }
    }
}

/// A single keyboard key, drawn as a small key cap.
struct KeyCap: View {
    let symbol: String

    init(_ symbol: String) {
        self.symbol = symbol
    }

    var body: some View {
        Text(symbol)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .frame(minWidth: 14)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
    }
}

/// The shortcut recorder at a larger size, as the centerpiece of the tour's shortcut page. It's the
/// same control as in Settings, and both edit the one stored shortcut.
struct LargeShortcutRecorder: NSViewRepresentable {
    func makeNSView(context: Context) -> KeyboardShortcuts.RecorderCocoa {
        let recorder = KeyboardShortcuts.RecorderCocoa(for: .createNewHint)
        recorder.controlSize = .large
        recorder.font = .systemFont(ofSize: NSFont.systemFontSize(for: .large))
        // The recorder reports a fixed 130pt width; let SwiftUI stretch it to the frame it's given.
        recorder.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return recorder
    }

    func updateNSView(_ recorder: KeyboardShortcuts.RecorderCocoa, context: Context) {}
}

struct OnboardingSettingsView: View {
    @ObservedObject var page: Page

    private var isCurrentPage: Bool {
        page.index == OnboardingPage.allCases.firstIndex(of: .settings)
    }
    
    var body: some View {
        VStack {
            VStack(alignment: .leading) {

                Text("Set a global keyboard shortcut.")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.semibold)
                    .padding(.vertical)
                
                Text("""
                    ScreenHint works best when it's close at hand.
                    
                    Set a global keyboard shortcut right here, or later from **"Settings..."** in ScreenHint's menu bar icon.
                    """)
                    .font(.system(.title3))
                    .padding(.bottom)

                // The suggested shortcut, drawn as key caps in the order macOS shows modifiers.
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("If you need a suggestion,")
                    HStack(spacing: 3) {
                        KeyCap("⇧")
                        KeyCap("⌘")
                        KeyCap("2")
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Shift Command 2")
                    Text("works really well.")
                }
                .font(.system(.title3))

                // The recorder is this page's centerpiece, below the text that introduces it.
                VStack(spacing: 12) {
                    Text("Set it here:")
                        .font(.system(.title3))
                    // Only in the view tree while this page is showing. The pager keeps other
                    // pages in the window, and a recorder on a page you can't see could still take
                    // keyboard focus (Tab) and silently record or clear the shortcut.
                    Group {
                        if isCurrentPage {
                            LargeShortcutRecorder()
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: 240, height: 30)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray, lineWidth: 1))
                .padding(.top)
            }
            .frame(width: onboardingContentWidth)
            
            Spacer()
            
            HStack {
                Button(action: { withAnimation {
                    self.page.update(.previous)
                }}) {
                    Text("Back").frame(minWidth: 100)
                }
                .buttonStyle(.link)
                .controlSize(.large)
                Spacer()
                Button(action: { withAnimation {
                    self.page.update(.next)
                }}) {
                    Text("Next").frame(minWidth: 100)
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                
            }
            .padding()
        }
    }
}
                    
struct OnboardingThanksView: View {
    @ObservedObject var page: Page
    
    var body: some View {
        VStack {
            Spacer()
            Text("That's it!")
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.semibold)
                .padding(.bottom)
            Text("""
                We hope you love using ScreenHint as much as we do.
                
                If you have questions, thoughts, or suggestions, you can find us at [screenhint@salem.io](mailto:screenhint@salem.io).
                """)
                .font(.system(.title3))
                .frame(width: onboardingContentWidth)
            Spacer()
            Spacer()
            HStack {
                Button(action: {withAnimation {
                    self.page.update(.previous)
                }}) {
                    Text("Back")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.link)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button(action: { withAnimation {
                    NSApplication.shared.keyWindow?.close()
                }}) {
                    Text("Let's go!")
                        .frame(minWidth: 100)
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }
}



struct OnboardingView: View {
    
    @StateObject var page: Page = .first()
    
    var body: some View {
        
        VStack{
            Pager(page: self.page,
                  data: OnboardingPage.allCases,
                  id: \.self) {p in
                Group {
                    switch (p) {
                    case .welcome:
                        OnboardingWelcomeView(page: page)
                    case .permissions:
                        OnboardingPermissionsView(page: page)
                    case .makeHint:
                        OnboardingMakeHintView(page: page)
                    case .useHint:
                        OnboardingUseHintView(page: page)
                    case .settings:
                        OnboardingSettingsView(page: page)
                    case .thanks:
                        OnboardingThanksView(page: page)
                    }
                }
                // ...but the controls on each page keep their focus rings.
                .focusEffectDisabled(false)
                // The pager keeps every page in the window. Only the page that's showing gets live
                // controls: otherwise every page's default button answers Return (and "Let's go!"
                // would close the tour from the first page), and Tab reaches buttons you can't see.
                .disabled(page.index != OnboardingPage.allCases.firstIndex(of: p))
            }
            .background(.clear)
            // SwiftUIPager makes the page stack focusable on macOS so the arrow keys can flip pages
            // (that's inside the library, so it can't be turned off from here). Don't draw a focus
            // ring around the whole tour for it...
            .focusEffectDisabled()
            
            
            
            
        }.padding(.vertical).frame(width: 600, height: 640)
        
    }
    
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
