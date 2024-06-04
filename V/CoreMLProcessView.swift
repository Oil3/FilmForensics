//
//  CoreMLProcessorView.swift
//  V
//
//  Created by Almahdi Morris on 4/6/24.
//
import SwiftUI
import UIKit
import AVKit
import Vision

struct CoreMLProcessView: View {
    @StateObject private var processor = CoreMLProcessor()
    @State private var selectedLog: String = ""
    @State private var logEntries: [String] = []
    @State private var processingFiles: [URL] = []
    @State private var selectedImage: UIImage?
    @State private var selectedVideo: URL?
    
    var body: some View {
        VStack {
            Picker("Select Model", selection: $processor.selectedModelName) {
                ForEach(processor.modelList, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding()

            HStack {
                Button("Select Files") {
                    processor.selectFiles { urls in
                        processingFiles = urls
                        print("Selected files: \(processingFiles)") // Debug message
                    }
                }
                .padding()

                Button("Start Processing") {
                    processor.startProcessing(urls: processingFiles, confidenceThreshold: 0.5, iouThreshold: 0.5, noVideoPlayback: false)
                }
                .padding()

                Button("Stop Processing") {
                    processor.stopProcessing()
                }
                .padding()

                Button("Placeholder") {
                    // Placeholder button action
                }
                .padding()
            }

            HStack {
                VStack {
                    Text("Current File Log")
                        .font(.headline)
                        .padding()
                    
                    SyntaxHighlightingTextView(text: Binding(
                        get: { processor.currentFileLog.joined(separator: "\n") },
                        set: { _ in }
                    ))
                    .frame(maxHeight: 200)
                    .padding()
                }

                VStack {
                    Text("General Log & Stats")
                        .font(.headline)
                        .padding()
                    
                    SyntaxHighlightingTextView(text: Binding(
                        get: { processor.generalLog.joined(separator: "\n") },
                        set: { _ in }
                    ))
                    .frame(maxHeight: 200)
                    .padding()

                    Text(processor.stats)
                        .padding()
                }
            }

            VStack {
                Text("Media Carousel")
                    .font(.headline)
                    .padding()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(processingFiles, id: \.self) { fileURL in
                            if fileURL.pathExtension.lowercased() == "mp4" || fileURL.pathExtension.lowercased() == "mov" {
                                VideoThumbnailView(url: fileURL, selectedVideo: $selectedVideo)
                            } else {
                                ImageThumbnailView(url: fileURL, selectedImage: $selectedImage)
                            }
                        }
                    }
                }
                .frame(height: 100)
                .padding()
            }

            if let selectedImage = selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .overlay(
                        BoundingBoxViewWrapper(observations: $processor.currentObservations, image: selectedImage)
                    )
                    .padding()
            }

            if let selectedVideo = selectedVideo {
                VideoPlayer(player: AVPlayer(url: selectedVideo))
                    .frame(maxHeight: 300)
                    .padding()
            }
        }
        .padding()
    }
}

struct ImageThumbnailView: View {
    let url: URL
    @Binding var selectedImage: UIImage?
    
    var body: some View {
        if let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .frame(width: 100, height: 100)
                .aspectRatio(contentMode: .fit)
                .onTapGesture {
                    selectedImage = image
                }
        }
    }
}

struct VideoThumbnailView: View {
    let url: URL
    @Binding var selectedVideo: URL?
    
    var body: some View {
        let thumbnail = generateThumbnail(url: url)
        
        return Image(uiImage: thumbnail)
            .resizable()
            .frame(width: 100, height: 100)
            .aspectRatio(contentMode: .fit)
            .onTapGesture {
                selectedVideo = url
            }
    }
    
    private func generateThumbnail(url: URL) -> UIImage {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        let time = CMTime(seconds: 1, preferredTimescale: 60)
        if let cgImage = try? imageGenerator.copyCGImage(at: time, actualTime: nil) {
            return UIImage(cgImage: cgImage)
        }

        return UIImage(systemName: "video") ?? UIImage()
    }
}

struct BoundingBoxViewWrapper: UIViewRepresentable {
    @Binding var observations: [VNRecognizedObjectObservation]
    var image: UIImage

    func makeUIView(context: Context) -> BoundingBoxView {
        let view = BoundingBoxView()
        view.updateSize(for: image.size)
        view.observations = observations
        return view
    }

    func updateUIView(_ uiView: BoundingBoxView, context: Context) {
        uiView.updateSize(for: image.size)
        uiView.observations = observations
    }
}
