  //
  //  ContentView.swift
  //  FilmForensics
  //
  //  Created by Almahdi Morris on 05/20/24.
  //
import SwiftUI
import AVKit
import AVFoundation
import CoreImage

struct ContentView: View {
    @StateObject private var videoPlayerViewModel = VideoPlayerViewModel()
    @State private var showPicker = false
    @State private var isImagePicker = false

    var body: some View {
        VStack {
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
            .padding()

            TabView {
                VideoView(videoPlayerViewModel: videoPlayerViewModel)
                    .tabItem {
                        Label("Video", systemImage: "video")
                    }
                ImageView(videoPlayerViewModel: videoPlayerViewModel)
                    .tabItem {
                        Label("Image", systemImage: "photo")
                    }
            }
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
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct VideoView: View {
    @ObservedObject var videoPlayerViewModel: VideoPlayerViewModel

    var body: some View {
        VStack {
            VideoPlayerView(player: videoPlayerViewModel.player)
                .onAppear {
                    videoPlayerViewModel.setupPlayer()
                }
            FilterControls(videoPlayerViewModel: videoPlayerViewModel)
        }
    }
}

struct ImageView: View {
    @ObservedObject var videoPlayerViewModel: VideoPlayerViewModel

    var body: some View {
        VStack {
            if let ciImage = videoPlayerViewModel.ciImage {
                Image(nsImage: ciImage.toNSImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    //.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    //.overlay(Rectangle().stroke(Color.clear, lineWidth: 0)) // Ensure image is in front
            }
            FilterControls(videoPlayerViewModel: videoPlayerViewModel)
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
            AdjustableSlider(label: "Brightness", value: $videoPlayerViewModel.brightness, range: -1...1, tooltip: "Adjusts the brightness of the image.")
            AdjustableSlider(label: "Contrast", value: $videoPlayerViewModel.contrast, range: 0...2, tooltip: "Adjusts the contrast of the image.")
            AdjustableSlider(label: "Saturation", value: $videoPlayerViewModel.saturation, range: 0...2, tooltip: "Adjusts the saturation of the image.")
            AdjustableSlider(label: "Hue", value: $videoPlayerViewModel.hue, range: -Float.pi...Float.pi, tooltip: "Adjusts the hue of the image.")
            AdjustableSlider(label: "Gamma", value: $videoPlayerViewModel.gamma, range: 0...3, tooltip: "Alters an image’s transition between black and white.")
            AdjustableSlider(label: "Vibrance", value: $videoPlayerViewModel.vibrance, range: -1...1, tooltip: "Adjusts an image’s vibrancy.")
            AdjustableSlider(label: "Exposure", value: $videoPlayerViewModel.exposure, range: -2...2, tooltip: "Adjusts an image’s exposure.")
            AdjustableSlider(label: "Temperature", value: $videoPlayerViewModel.temperature, range: 2000...10000, tooltip: "Alters an image’s temperature and tint.")
            AdjustableSlider(label: "Sepia Tone", value: $videoPlayerViewModel.sepiaTone, range: 0...1, tooltip: "Adjusts an image’s colors to shades of brown.")
            Toggle("Color Invert", isOn: $videoPlayerViewModel.colorInvert)
                .toggleStyle(SwitchToggleStyle())
                .padding()
                .help("Inverts an image’s colors.")
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
