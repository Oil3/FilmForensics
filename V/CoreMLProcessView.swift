//
//  CoreMLProcessorView.swift
//  V
//
//  Created by Almahdi Morris on 4/6/24.
//
import SwiftUI
import AVKit
import Vision

struct CoreMLProcessView: View {
    @EnvironmentObject var processor: CoreMLProcessor
    @State private var processingFiles: [URL] = []
    @State private var selectedMediaItem: URL?
    @State private var detectionFrames: [UIImage] = []

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

            VStack {
                Text("Selected Media Items")
                    .font(.headline)
                    .padding()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(processingFiles, id: \.self) { fileURL in
                            MediaItemView(url: fileURL, isSelected: fileURL == selectedMediaItem)
                                .onTapGesture {
                                    selectedMediaItem = fileURL
                                }
                        }
                    }
                }
                .frame(height: 100)
                .padding()
            }

            VStack {
                Text("Detection Frames")
                    .font(.headline)
                    .padding()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(processor.detectionFrames, id: \.self) { frame in
                            Image(uiImage: frame)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100)
                        }
                    }
                }
                .frame(height: 100)
                .padding()
            }

            VStack {
                Text("Current Logs")
                    .font(.headline)
                    .padding()

                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach(processor.detailedLogs, id: \.self) { log in
                            Text(log)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                        }
                    }
                }
                .frame(maxHeight: 200)
                .padding()
            }

            VStack {
                Text("Stats")
                    .font(.headline)
                    .padding()

                Text(processor.stats)
                    .padding()
            }

            if let selectedImage = processor.selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .overlay(
                        BoundingBoxViewWrapper(observations: $processor.currentObservations, image: selectedImage)
                    )
                    .padding()
            }

            if let selectedVideo = processor.selectedVideo {
                VideoPlayer(player: AVPlayer(url: selectedVideo))
                    .frame(maxHeight: 300)
                    .padding()
            }
        }
        .padding()
    }
}

struct MediaItemView: View {
    let url: URL
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            if url.pathExtension.lowercased() == "mp4" || url.pathExtension.lowercased() == "mov" {
                VideoThumbnailView(url: url)
                    .frame(width: 100, height: 100)
            } else if let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
            }
            
            if isSelected {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue, lineWidth: 4)
            }
        }
    }
}

struct VideoThumbnailView: View {
    let url: URL
    
    var body: some View {
        if let thumbnail = generateThumbnail(url: url) {
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "video")
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
    
    private func generateThumbnail(url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("Failed to generate thumbnail: \(error.localizedDescription)")
            return nil
        }
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
