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

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        if let url = selectedURL {
            let player = AVPlayer(url: url)
            playerView.player = player
        }
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if let url = selectedURL {
            nsView.player = AVPlayer(url: url)
            nsView.player?.play()
        }
    }
}
