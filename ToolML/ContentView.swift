//
//  ContentView.swift
//  ToolML
//
//  Created by Almahdi Morris on 14/6/24.
//

import SwiftUI
import CoreML
import Vision

struct ContentView: View {
    @State private var selectedImage: NSImage? = nil
    @State private var detectedObjects: [VNRecognizedObjectObservation] = []

    var body: some View {
        VStack {
            // Model Description
            Text("Model: best")
                .font(.title)
                .padding()

            // Image and Detection Result Display
            HStack {
                // Left Column: Image Picker and Gallery
                VStack {
                    if let image = selectedImage {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .onTapGesture {
                                runModel(on: image)
                            }
                    }
                    Spacer()
                    Button(action: selectImage) {
                        Text("Select Image")
                    }
                    Button(action: clearImages) {
                        Text("Clear")
                    }
                }
                .frame(width: 120)

                // Right Column: Selected Image and Detection Results
                VStack {
                    if let image = selectedImage {
                        ZStack {
                            Image(nsImage: image)
                             //   .resizable()
                                .fixedSize()
                            ForEach(detectedObjects, id: \.self) { object in
                                drawBoundingBox(for: object)
                            }
                        }
                    } else {
                        Text("No Image Selected")
                    }
                }
            }
        }
        .padding()
    }

    func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["png", "jpg", "jpeg"]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) {
            selectedImage = image
            runModel(on: image)
        }
    }

    func clearImages() {
        selectedImage = nil
        detectedObjects.removeAll()
    }

    func runModel(on image: NSImage) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let model = try! VNCoreMLModel(for: ccashier3().model)

        let request = VNCoreMLRequest(model: model) { request, error in
            if let results = request.results as? [VNRecognizedObjectObservation] {
                DispatchQueue.main.async {
                    self.detectedObjects = results
                }
            }
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }

    func drawBoundingBox(for observation: VNRecognizedObjectObservation) -> some View {
        let boundingBox = observation.boundingBox
        let normalizedRect = CGRect(x: boundingBox.minX, y:  1 - boundingBox.maxY, width: boundingBox.width, height: boundingBox.height)
        
        return Rectangle()
            .stroke(Color.red, lineWidth: 2)
            .frame(width: normalizedRect.width * 640, height: normalizedRect.height * 640)
            .position(x: normalizedRect.midX * 640, y: normalizedRect.midY * 640)
    }
}
