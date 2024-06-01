//
//  VideoPlayerView.swift
//  FilmForensics
//
//  Created by Almahdi Morris on 05/22/24.
//
import SwiftUI
import AVKit

struct VideoPlayerView: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> NSView {
        let playerView = AVPlayerView()
        playerView.player = player
        playerView.showsFullScreenToggleButton = true
        playerView.controlsStyle = .inline
        return playerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let playerView = nsView as? AVPlayerView {
            playerView.player = player
        }
    }
}
