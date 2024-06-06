//
//  FilterControlsView.swift
//  FilmForensics
//
// Copyright Almahdi Morris - 1/6/24.
//
import SwiftUI

struct FilterControlsView: View {
    @ObservedObject var videoPlayerViewModel: VideoPlayerViewModel
    @State private var showHistogram = false

    var body: some View {
        VStack {
            Button(action: {
                showHistogram.toggle()
            }) {
                Text(showHistogram ? "Hide Histogram" : "Show Histogram")
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            if showHistogram {
                HistogramView(image: videoPlayerViewModel.ciImage)
                    .frame(height: 150)
                    .padding()
            }
            ScrollView {
                FilterControls(videoPlayerViewModel: videoPlayerViewModel)
                    .padding()
            }
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(10)
        .shadow(radius: 10)
    }
}

struct FilterControls: View {
    @ObservedObject var videoPlayerViewModel: VideoPlayerViewModel
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Filters")
                .font(.headline)
                .foregroundColor(.white)
            Group {
                MiniSlider(label: "Brightness", value: $videoPlayerViewModel.brightness, range: -1...1, tooltip: "Adjusts the brightness of the image.")
                MiniSlider(label: "Contrast", value: $videoPlayerViewModel.contrast, range: 0...2, tooltip: "Adjusts the contrast of the image.")
                MiniSlider(label: "Saturation", value: $videoPlayerViewModel.saturation, range: 0...2, tooltip: "Adjusts the saturation of the image.")
                MiniSlider(label: "Hue", value: $videoPlayerViewModel.hue, range: -Float.pi...Float.pi, tooltip: "Adjusts the hue of the image.")
                MiniSlider(label: "Gamma", value: $videoPlayerViewModel.gamma, range: 0...3, tooltip: "Alters an image’s transition between black and white.")
                MiniSlider(label: "Vibrance", value: $videoPlayerViewModel.vibrance, range: -1...1, tooltip: "Adjusts an image’s vibrancy.")
                MiniSlider(label: "Exposure", value: $videoPlayerViewModel.exposure, range: -2...2, tooltip: "Adjusts an image’s exposure.")
                MiniSlider(label: "Temperature", value: $videoPlayerViewModel.temperature, range: 2000...10000, tooltip: "Alters an image’s temperature and tint.")
                MiniSlider(label: "Sepia Tone", value: $videoPlayerViewModel.sepiaTone, range: 0...1, tooltip: "Adjusts an image’s colors to shades of brown.")
                Toggle("Color Invert", isOn: $videoPlayerViewModel.colorInvert)
                    .toggleStyle(SwitchToggleStyle())
                    .foregroundColor(.white)
                    .help("Inverts an image’s colors.")
            }
            .padding(.horizontal)
            HStack {
                Button("Reset") {
                    videoPlayerViewModel.resetFilters()
                }
                Button("Save Preset") {
                    videoPlayerViewModel.savePreset()
                }
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
            .padding(.horizontal)
            .foregroundColor(.white)
        }
        .padding()
    }
}

struct MiniSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let tooltip: String

    var body: some View {
        VStack {
            HStack {
                Text(label)
                    .foregroundColor(.white)
                Slider(value: $value, in: range) { isEditing in
                    if !isEditing {
                        valueChanged()
                    }
                }
                .frame(width: 100)
                Text("\(Int(value * 100))%")
                    .foregroundColor(.white)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.2)))
            .help(tooltip)
        }
    }

    func valueChanged() {
        NotificationCenter.default.post(name: .sliderValueChanged, object: nil)
    }
}
