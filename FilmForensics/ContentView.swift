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
    @State private var showPicker = false
    @State private var isImagePicker = false

    var body: some View {
        VStack {
            ZStack {
                VideoPlayerView(player: videoPlayerViewModel.player)
                    .onAppear {
                        videoPlayerViewModel.setupPlayer()
                    }
                if let ciImage = videoPlayerViewModel.ciImage {
                    Image(nsImage: ciImage.toNSImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            TabView {
                FilterPane(videoPlayerViewModel: videoPlayerViewModel, title: "Favorite Filters")
                    .tabItem {
                        Label("Favorite", systemImage: "star")
                    }
                FilterPane(videoPlayerViewModel: videoPlayerViewModel, title: "Blur & Sharpen")
                    .tabItem {
                        Label("Blur & Sharpen", systemImage: "drop.fill")
                    }
                FilterPane(videoPlayerViewModel: videoPlayerViewModel, title: "Color Adjustment")
                    .tabItem {
                        Label("Color Adjustment", systemImage: "paintbrush")
                    }
                FilterPane(videoPlayerViewModel: videoPlayerViewModel, title: "Color Effects")
                    .tabItem {
                        Label("Color Effects", systemImage: "sparkles")
                    }
                FilterPane(videoPlayerViewModel: videoPlayerViewModel, title: "Composite")
                    .tabItem {
                        Label("Composite", systemImage: "rectangle.stack")
                    }
                FilterPane(videoPlayerViewModel: videoPlayerViewModel, title: "Convolution")
                    .tabItem {
                        Label("Convolution", systemImage: "wand.and.rays")
                    }
                YoloDetectionView(videoPlayerViewModel: videoPlayerViewModel)
                    .tabItem {
                        Label("YOLO Detection", systemImage: "square.stack.3d.up")
                    }
            }
            FilterControls(videoPlayerViewModel: videoPlayerViewModel)
            HStack {
                Button("Open Video") {
                    isImagePicker = false
                    showPicker = true
                }
                Button("Open Image") {
                    isImagePicker = true
                    showPicker = true
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .fileImporter(isPresented: $showPicker, allowedContentTypes: isImagePicker ? [.image] : [.movie]) { result in
            switch result {
            case .success(let url):
                if isImagePicker {
                    videoPlayerViewModel.loadImage(url: url)
                } else {
                    videoPlayerViewModel.loadVideo(url: url)
                }
            case .failure(let error):
                print("Failed to load file: \(error.localizedDescription)")
            }
        }
    }
}

struct FilterPane: View {
    @ObservedObject var videoPlayerViewModel: VideoPlayerViewModel
    let title: String

    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .padding()
            FilterControls(videoPlayerViewModel: videoPlayerViewModel)
        }
        .padding()
    }
}

struct AdjustableSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let tooltip: String

    var body: some View {
        VStack {
            Text(label)
            Slider(value: $value, in: range) { isEditing in
                if !isEditing {
                    valueChanged()
                }
            }
            Text("\(Int(value * 100))%")
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.2)))
        .help(tooltip)
    }

    func valueChanged() {
        NotificationCenter.default.post(name: .sliderValueChanged, object: nil)
    }
}

extension CIImage {
    func toNSImage() -> NSImage {
        let rep = NSCIImageRep(ciImage: self)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}

struct FilterControls: View {
    @ObservedObject var videoPlayerViewModel: VideoPlayerViewModel

    var body: some View {
        HStack {
            Button("Reset") {
                videoPlayerViewModel.resetFilters()
            }
            .padding()

            Button("Save Preset") {
                videoPlayerViewModel.savePreset()
            }
            .padding()

            if let presets = videoPlayerViewModel.presets {
                Picker("Load Preset", selection: $videoPlayerViewModel.selectedPreset) {
                    ForEach(presets, id: \.self) { preset in
                        Text(preset.name).tag(preset)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: videoPlayerViewModel.selectedPreset) { newValue in
                    if let newValue = newValue {
                        videoPlayerViewModel.loadPreset(preset: newValue)
                    }
                }
            }
        }
        .padding()
    }
}

extension Notification.Name {
    static let sliderValueChanged = Notification.Name("sliderValueChanged")
}
