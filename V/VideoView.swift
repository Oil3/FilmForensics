import SwiftUI
import AVKit

struct VideoView: NSViewRepresentable {
    @Binding var selectedURL: URL?
//    @Binding var showBoundingBoxes: Bool
//    @Binding var logDetections: Bool

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        if let url = selectedURL {
            let player = AVPlayer(url: url)
            playerView.player = player
            context.coordinator.setupDetectionOverlay()
            context.coordinator.setupPlayerView(playerView)
            context.coordinator.updatePlayerView(playerView, with: url)
        }
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if let url = selectedURL, nsView.player?.currentItem?.asset != AVAsset(url: url) {
            let player = AVPlayer(url: url)
            nsView.player = player
            context.coordinator.updatePlayerView(nsView, with: url)
            player.play()
        }
    }

    func makeCoordinator() -> Coordinator {
      Coordinator()
    }
}
