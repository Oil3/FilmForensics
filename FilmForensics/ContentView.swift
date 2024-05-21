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
                FavoriteFiltersView(viewModel: videoPlayerViewModel)
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
                ColorEffectFiltersView(viewModel: videoPlayerViewModel)
                    .tabItem {
                        Label("Color Effects", systemImage: "sparkles")
                    }
                ReductionFiltersView(viewModel: videoPlayerViewModel)
                    .tabItem {
                        Label("Reduction Filters", systemImage: "chart.bar.xaxis")
                    }
            }
            FilterControls(viewModel: videoPlayerViewModel)
            VideoControlsView(viewModel: videoPlayerViewModel)
            Button("Open Video or Image") {
                videoPlayerViewModel.openFilePicker()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct FavoriteFiltersView: View {
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
            Text("Apply blurs, simulate motion and zoom effects, reduce noise, and erode and dilate image regions.")
                .padding()
            HStack {
                AdjustableSlider(label: "Gaussian Blur", value: $viewModel.gaussianBlur, range: 0...10)
                AdjustableSlider(label: "Motion Blur", value: $viewModel.motionBlur, range: 0...10)
            }
            HStack {
                AdjustableSlider(label: "Zoom Blur", value: $viewModel.zoomBlur, range: 0...10)
                AdjustableSlider(label: "Noise Reduction", value: $viewModel.noiseReduction, range: 0...10)
            }
        }
        .padding()
    }
}

struct ColorAdjustmentFiltersView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    var body: some View {
        VStack {
            Text("Apply color transformations, including exposure, hue, and tint adjustments.")
                .padding()
            HStack {
                AdjustableSlider(label: "Gamma", value: $viewModel.gamma, range: 0...3)
                AdjustableSlider(label: "Vibrance", value: $viewModel.vibrance, range: -1...1)
            }
            HStack {
                AdjustableSlider(label: "Exposure", value: $viewModel.exposure, range: -2...2)
                AdjustableSlider(label: "Temperature", value: $viewModel.temperature, range: 2000...10000)
            }
        }
        .padding()
    }
}

struct ColorEffectFiltersView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    var body: some View {
        VStack {
            Text("Apply color effects, including photo effects, dithering, and color maps.")
                .padding()
            HStack {
                AdjustableSlider(label: "Sepia Tone", value: $viewModel.sepiaTone, range: 0...1)
                AdjustableSlider(label: "Color Invert", value: $viewModel.colorInvert, range: 0...1)
            }
        }
        .padding()
    }
}

struct ReductionFiltersView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    var body: some View {
        VStack {
            Text("Create statistical information about an image.")
                .padding()
            HStack {
                AdjustableSlider(label: "Area Average", value: $viewModel.areaAverage, range: 0...1)
                AdjustableSlider(label: "Histogram", value: $viewModel.histogram, range: 0...1)
            }
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
            Slider(value: $value, in: range, onEditingChanged: { _ in
                valueChanged()
            })
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

struct FilterControls: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    var body: some View {
        HStack {
            Button("Reset") {
                viewModel.resetFilters()
            }
            .padding()
            
            Button("Save Preset") {
                viewModel.savePreset()
            }
            .padding()
            
            if let presets = viewModel.presets {
                Picker("Load Preset", selection: $viewModel.selectedPreset) {
                    ForEach(presets, id: \.self) { preset in
                        Text(preset.name).tag(preset)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: viewModel.selectedPreset) { newValue in
                    if let newValue = newValue {
                        viewModel.loadPreset(preset: newValue)
                    }
                }
            }
        }
        .padding()
    }
}
