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
                        Label("Basic Filters", systemImage: "slider.horizontal.3")
                    }
                CoreImageFilterControlsView(viewModel: videoPlayerViewModel)
                    .tabItem {
                        Label("Advanced Filters", systemImage: "wand.and.stars")
                    }
            }
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
            AdjustableSlider(label: "Brightness", value: $viewModel.brightness, range: -1...1)
            AdjustableSlider(label: "Contrast", value: $viewModel.contrast, range: 0...2)
            AdjustableSlider(label: "Saturation", value: $viewModel.saturation, range: 0...2)
        }
        .padding()
    }
}

struct CoreImageFilterControlsView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    var body: some View {
        VStack {
            AdjustableSlider(label: "Red", value: $viewModel.red, range: 0...2)
            AdjustableSlider(label: "Green", value: $viewModel.green, range: 0...2)
            AdjustableSlider(label: "Blue", value: $viewModel.blue, range: 0...2)
        }
        .padding()
    }
}

struct AdjustableSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    
    var body: some View {
        HStack {
            Text(label)
            Slider(value: $value, in: range)
            Text("\(Int(value * 100))%")
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.2)))
        .focusable()
        .onMoveCommand { direction in
            switch direction {
            case .left:
                value = max(value - 0.01, range.lowerBound)
            case .right:
                value = min(value + 0.01, range.upperBound)
            default:
                break
            }
        }
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
