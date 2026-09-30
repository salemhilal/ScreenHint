//
//  OnboardingTests.swift
//  ScreenHintTests
//
//  The product tour plays the same demo video as screenhint.com. These check that the video
//  actually ships in the app bundle, that it's playable, and that its shape matches what the
//  tour lays out for it.
//

import AVFoundation
import Testing
@testable import ScreenHint

@Suite("Onboarding")
struct OnboardingTests {

    @Test("the demo video ships in the app and plays through")
    func demoVideoIsBundledAndPlayable() async throws {
        let url = try #require(Bundle.main.url(forResource: "Onboarding.Demo", withExtension: "mp4"))
        let asset = AVURLAsset(url: url)

        #expect(try await asset.load(.isPlayable))
        let duration = try await asset.load(.duration).seconds
        #expect(duration > 10 && duration < 14)

        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let size = try await track.load(.naturalSize)
        #expect(abs(size.width / size.height - DemoVideoView.aspectRatio) < 0.01)
    }
}
