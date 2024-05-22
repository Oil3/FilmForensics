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
                FilterPane(viewModel: videoPlayerViewModel, title: "Favorite Filters")
                    .tabItem {
                        Label("Favorite", systemImage: "star")
                    }
                FilterPane(viewModel: videoPlayerViewModel, title: "Blur & Sharpen")
                    .tabItem {
                        Label("Blur & Sharpen", systemImage: "drop.fill")
                    }
                FilterPane(viewModel: videoPlayerViewModel, title: "Color Adjustment")
                    .tabItem {
                        Label("Color Adjustment", systemImage: "paintbrush")
                    }
                FilterPane(viewModel: videoPlayerViewModel, title: "Color Effects")
                    .tabItem {
                        Label("Color Effects", systemImage: "sparkles")
                    }
                FilterPane(viewModel: videoPlayerViewModel, title: "Composite")
                    .tabItem {
                        Label("Composite", systemImage: "rectangle.stack")
                    }
                FilterPane(viewModel: videoPlayerViewModel, title: "Convolution")
                    .tabItem {
                        Label("Convolution", systemImage: "wand.and.rays")
                    }
                MLDetectionView(viewModel: videoPlayerViewModel)
                    .tabItem {
                        Label("YOLO Detection", systemImage: "square.stack.3d.up")
                    }
            }
            FilterControls(viewModel: videoPlayerViewModel)
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
        .sheet(isPresented: $showPicker) {
            if isImagePicker {
                ImagePicker(sourceType: .photoLibrary, selectedImage: $videoPlayerViewModel.image)
            } else {
                VideoPicker(videoURL: $videoPlayerViewModel.videoURL)
            }
        }
    }
}

struct FilterPane: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    let title: String

    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .padding()
            FilterControls(viewModel: viewModel)
        }
        .padding()
    }
}

struct YoloDetectionView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel

    var body: some View {
        VStack {
            Text("YOLO Detection")
                .font(.headline)
                .padding()
            Toggle("Show Bounding Boxes", isOn: $viewModel.showBoundingBoxes)
                .padding()
            FilterControls(viewModel: viewModel)
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


struct FavoriteFiltersView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    var body: some View {
        VStack {
            HStack {
                AdjustableSlider(label: "Brightness", value: $viewModel.brightness, range: -1...1, tooltip: "Adjusts the brightness of the image.")
                AdjustableSlider(label: "Contrast", value: $viewModel.contrast, range: 0...2, tooltip: "Adjusts the contrast of the image.")
            }
            HStack {
                AdjustableSlider(label: "Saturation", value: $viewModel.saturation, range: 0...2, tooltip: "Adjusts the saturation of the image.")
                AdjustableSlider(label: "Hue", value: $viewModel.hue, range: -Float(Double.pi)...Float(Double.pi), tooltip: "Adjusts the hue of the image.")
            }
        }
        .padding()
    }
}

struct BlurAndSharpenFiltersView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    var body: some View {
        VStack {
            Text("Apply blurs, simulate motion and zoom effects, reduce noise, and erode and dilate image regions.")
                .padding()
            HStack {
                AdjustableSlider(label: "Gaussian Blur", value: $viewModel.gaussianBlur, range: 0...10, tooltip: "Blurs an image with a Gaussian distribution pattern.")
                AdjustableSlider(label: "Motion Blur", value: $viewModel.motionBlur, range: 0...10, tooltip: "Creates motion blur on an image.")
            }
            HStack {
                AdjustableSlider(label: "Zoom Blur", value: $viewModel.zoomBlur, range: 0...10, tooltip: "Creates zoom blur on an image.")
                AdjustableSlider(label: "Noise Reduction", value: $viewModel.noiseReduction, range: 0...10, tooltip: "Reduces noise by sharpening the edges of objects.")
            }
            HStack {
                AdjustableSlider(label: "Sharpen Luminance", value: $viewModel.sharpenLuminance, range: 0...1, tooltip: "Applies a sharpening effect to an image.")
                AdjustableSlider(label: "Unsharp Mask", value: $viewModel.unsharpMask, range: 0...2, tooltip: "Increases an image’s contrast between two colors.")
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
                AdjustableSlider(label: "Gamma", value: $viewModel.gamma, range: 0...3, tooltip: "Alters an image’s transition between black and white.")
                AdjustableSlider(label: "Vibrance", value: $viewModel.vibrance, range: -1...1, tooltip: "Adjusts an image’s vibrancy.")
            }
            HStack {
                AdjustableSlider(label: "Exposure", value: $viewModel.exposure, range: -2...2, tooltip: "Adjusts an image’s exposure.")
                AdjustableSlider(label: "Temperature", value: $viewModel.temperature, range: 2000...10000, tooltip: "Alters an image’s temperature and tint.")
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
                AdjustableSlider(label: "Sepia Tone", value: $viewModel.sepiaTone, range: 0...1, tooltip: "Adjusts an image’s colors to shades of brown.")
                Toggle("Color Invert", isOn: $viewModel.colorInvert)
                    .toggleStyle(SwitchToggleStyle())
                    .padding()
                    .help("Inverts an image’s colors.")
            }
        }
        .padding()
    }
}

struct CompositeFiltersView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    var body: some View {
        VStack {
            Text("Composite images by using a range of blend modes and compositing operators.")
                .padding()
            HStack {
                AdjustableSlider(label: "Addition", value: $viewModel.additionCompositing, range: 0...1, tooltip: "Blends colors from two images by addition.")
                AdjustableSlider(label: "Multiply", value: $viewModel.multiplyCompositing, range: 0...1, tooltip: "Blends colors from two images by multiplying color components.")
            }
        }
        .padding()
    }
}

struct ConvolutionFiltersView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    var body: some View {
        VStack {
            Text("Produce effects such as blurring, sharpening, edge detection, translation, and embossing.")
                .padding()
            HStack {
                AdjustableSlider(label: "Convolution 3x3", value: $viewModel.convolution3X3, range: 0...1, tooltip: "Applies a convolution 3 x 3 filter to the RGBA components of an image.")
                AdjustableSlider(label: "Convolution 5x5", value: $viewModel.convolution5X5, range: 0...1, tooltip: "Applies a convolution 5 x 5 filter to the RGBA components image.")
            }
        }
        .padding()
    }
}


extension Notification.Name {
    static let sliderValueChanged = Notification.Name("sliderValueChanged")
}
