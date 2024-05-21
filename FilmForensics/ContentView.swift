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
            TabView {
                FilterControlsView(viewModel: videoPlayerViewModel)
                    .tabItem {
                        Label("Favorite", systemImage: "star")
                    }
                BlurFiltersView(viewModel: videoPlayerViewModel)
                    .tabItem {
                        Label("Blur Filters", systemImage: "drop.fill")
                    }
                ColorAdjustmentFiltersView(viewModel: videoPlayerViewModel)
                    .tabItem {
                        Label("Color Adjustment", systemImage: "paintbrush")
                    }
                // Add more categories here
            }
            VideoControlsView(viewModel: videoPlayerViewModel)
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
            HStack {
                AdjustableSlider(label: "Brightness", value: $viewModel.brightness, range: -1...1)
                AdjustableSlider(label: "Contrast", value: $viewModel.contrast, range: 0...2)
            }
            HStack {
                AdjustableSlider(label: "Saturation", value: $viewModel.saturation, range: 0...2)
                AdjustableSlider(label: "Hue", value: $viewModel.hue, range: -Float(Double.pi)...Float(Double.pi))
            }
        }
        .padding()
    }
}

struct BlurFiltersView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    var body: some View {
        VStack {
            // Add sliders for blur filters here
        }
        .padding()
    }
}

struct ColorAdjustmentFiltersView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    var body: some View {
        VStack {
            HStack {
                AdjustableSlider(label: "Gamma", value: $viewModel.gamma, range: 0...3)
                AdjustableSlider(label: "Vibrance", value: $viewModel.vibrance, range: -1...1)
            }
            // Add more sliders for color adjustment filters here
        }
        .padding()
    }
}

struct AdjustableSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    
    var body: some View {
        VStack {
            Text(label)
            Slider(value: $value, in: range) { _ in
                valueChanged()
            }
            .onChange(of: value) { _ in
                valueChanged()
            }
            Text("\(Int(value * 100))%")
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.2)))
    }
    
    func valueChanged() {
        // This function will be called continuously as the slider is dragged
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

struct VideoControlsView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    var body: some View {
        HStack {
            Button(action: {
                viewModel.playPause()
            }) {
                Image(systemName: viewModel.isPlaying ? "pause.circle" : "play.circle")
                    .resizable()
                    .frame(width: 40, height: 40)
            }
            Button(action: {
                viewModel.loopVideo()
            }) {
                Image(systemName: "repeat.circle")
                    .resizable()
                    .frame(width: 40, height: 40)
            }
            Button(action: {
                viewModel.stepFrame(by: -1)
            }) {
                Image(systemName: "backward.frame")
                    .resizable()
                    .frame(width: 40, height: 40)
            }
            Button(action: {
                viewModel.stepFrame(by: 1)
            }) {
                Image(systemName: "forward.frame")
                    .resizable()
                    .frame(width: 40, height: 40)
            }
        }
        .padding()
    }
}
