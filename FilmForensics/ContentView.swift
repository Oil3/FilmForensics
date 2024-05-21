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
            VideoImageView(player: videoPlayerViewModel.player, ciImage: $videoPlayerViewModel.ciImage)
                .onAppear {
                    videoPlayerViewModel.setupPlayer()
                }
            FilterControlsView(viewModel: videoPlayerViewModel)
            Button("Open Video or Image") {
                videoPlayerViewModel.openFilePicker()
            }
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

struct VideoImageView: NSViewRepresentable {
    let player: AVPlayer
    @Binding var ciImage: CIImage?
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        
        let playerView = AVPlayerView()
        playerView.player = player
        playerView.showsFullScreenToggleButton = true
        playerView.autoresizingMask = [.width, .height]
        playerView.translatesAutoresizingMaskIntoConstraints = true
        playerView.frame = containerView.bounds
        
        containerView.addSubview(playerView)
        
        let imageView = NSImageView()
        imageView.autoresizingMask = [.width, .height]
        imageView.translatesAutoresizingMaskIntoConstraints = true
        imageView.imageScaling = .scaleAxesIndependently
        imageView.frame = containerView.bounds
        
        containerView.addSubview(imageView)
        context.coordinator.imageView = imageView
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let ciImage = ciImage {
            let rep = NSCIImageRep(ciImage: ciImage)
            let nsImage = NSImage(size: rep.size)
            nsImage.addRepresentation(rep)
            context.coordinator.imageView?.image = nsImage
            context.coordinator.imageView?.isHidden = false
        } else {
            context.coordinator.imageView?.isHidden = true
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    class Coordinator: NSObject {
        var imageView: NSImageView?
    }
}
