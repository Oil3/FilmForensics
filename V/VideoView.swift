//
//  VideoView.swift
//  V
//
// Copyright Almahdi Morris - 4/6/24.
//
import SwiftUI
import AVKit

struct VideoView: NSViewRepresentable {
    @Binding var selectedURL: URL?
    
 @State var showBoundingBoxes: Bool = true
   @State   var logDetections: Bool = true

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        if let url = selectedURL {
            let player = AVPlayer(url: url)
            playerView.player = player
            context.coordinator.setupDetection(player: player, showBoundingBoxes: showBoundingBoxes, logDetections: logDetections)
        }
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if let url = selectedURL, nsView.player?.currentItem?.asset != AVAsset(url: url) {
            let player = AVPlayer(url: url)
            nsView.player = player
            player.play()
            context.coordinator.setupDetection(player: player, showBoundingBoxes: showBoundingBoxes, logDetections: logDetections)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        func setupDetection(player: AVPlayer, showBoundingBoxes: Bool, logDetections: Bool) {
            // Setup video output, display link, and Vision requests
        }
    }
}
