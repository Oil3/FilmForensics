//
//  FiltersImageControlsView.swift
//  FilmForensics
//
// Copyright Almahdi Morris - 1/6/24.
//

import SwiftUI

struct FiltersImageControlsView: View {
    @State private var showHistogram = false
    @ObservedObject var imageViewerModel: ImageViewerModel

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
                HistogramView(image: imageViewerModel.ciImage)
                    .frame(height: 150)
                    .padding()
            }
            ScrollView {
                FiltersImageControls(imageViewerModel: imageViewerModel)
                    .padding()
            }
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(10)
//        .shadow(radius: 220)
    }
}

struct FiltersImageControls: View {
    @ObservedObject var imageViewerModel: ImageViewerModel

    var body: some View {
        VStack(spacing: 10) {
            Text("Filters")
                .font(.headline)
                .foregroundColor(.white)
            Group {
                MiniSlider(label: "Brightness", value: $imageViewerModel.brightness, range: -1...1, tooltip: "Adjusts the brightness of the image.")
                MiniSlider(label: "Contrast", value: $imageViewerModel.contrast, range: 0...2, tooltip: "Adjusts the contrast of the image.")
                MiniSlider(label: "Saturation", value: $imageViewerModel.saturation, range: 0...2, tooltip: "Adjusts the saturation of the image.")
                MiniSlider(label: "Hue", value: $imageViewerModel.hue, range: -Float.pi...Float.pi, tooltip: "Adjusts the hue of the image.")
                MiniSlider(label: "Gamma", value: $imageViewerModel.gamma, range: 0...3, tooltip: "Alters an image’s transition between black and white.")
                MiniSlider(label: "Vibrance", value: $imageViewerModel.vibrance, range: -1...1, tooltip: "Adjusts an image’s vibrancy.")
                MiniSlider(label: "Exposure", value: $imageViewerModel.exposure, range: -2...2, tooltip: "Adjusts an image’s exposure.")
                MiniSlider(label: "Temperature", value: $imageViewerModel.temperature, range: 2000...10000, tooltip: "Alters an image’s temperature and tint.")
                MiniSlider(label: "Sepia Tone", value: $imageViewerModel.sepiaTone, range: 0...1, tooltip: "Adjusts an image’s colors to shades of brown.")
                Toggle("Color Invert", isOn: $imageViewerModel.colorInvert)
                    .toggleStyle(SwitchToggleStyle())
                    .foregroundColor(.white)
                    .help("Inverts an image’s colors.")
            }
            .padding(.horizontal)
            HStack {
                Button("Reset") {
                    imageViewerModel.resetFilters()
                }
                Button("Save Preset") {
                    imageViewerModel.savePreset()
                }
                if let presets = imageViewerModel.presets {
                    Picker("Load Preset", selection: $imageViewerModel.selectedPreset) {
                        ForEach(presets, id: \.self) { preset in
                            Text(preset.name).tag(preset)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: imageViewerModel.selectedPreset) { newValue in
                        if let newValue = newValue {
                            imageViewerModel.loadPreset(preset: newValue)
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

