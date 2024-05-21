//
//  ContentView.swift
//  FilmForensics
//
//  Created by Almahdi Morris on 05/20/24.
//

import SwiftUI
import AVKit
import AVFoundation

struct ContentView: View {
    @StateObject private var videoPlayerViewModel = VideoPlayerViewModel()
    
    var body: some View {
        VStack {
            VideoPlayerView(player: videoPlayerViewModel.player)
                .onAppear {
                    videoPlayerViewModel.setupPlayer()
                }
            FilterControlsView(viewModel: videoPlayerViewModel)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct FilterControlsView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    var body: some View {
        VStack {
            Slider(value: $viewModel.brightness, in: -1...1) {
                Text("Brightness")
            }
            Slider(value: $viewModel.contrast, in: 0...2) {
                Text("Contrast")
            }
            Slider(value: $viewModel.saturation, in: 0...2) {
                Text("Saturation")
            }
            Slider(value: $viewModel.red, in: 0...2) {
                Text("Red")
            }
            Slider(value: $viewModel.green, in: 0...2) {
                Text("Green")
            }
            Slider(value: $viewModel.blue, in: 0...2) {
                Text("Blue")
            }
        }
        .padding()
    }
}

struct VideoPlayerView: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.player = player
        playerView.showsFullScreenToggleButton = true
        return playerView
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        // No updates needed
    }
}
