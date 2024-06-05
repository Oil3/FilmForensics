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
    @State private var selectedDetectionFrames: Set<CoreMLProcessor.DetectionFrame> = []
    @State private var isPreviewPresented: Bool = false
    @State private var previewImage: UIImage?
    @State private var previewVideo: URL?

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
                Text("Detection Frames")
                    .font(.headline)
                    .padding()

                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 10) {
                        ForEach(processor.detectionFrames) { frame in
                            Image(uiImage: frame.image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 150, height: 150)
                                .overlay(
                                    Text("\(String(format: "%.2f", frame.timestamp))s")
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.7))
                                        .padding(4),
                                    alignment: .bottom
                                )
                                .border(selectedDetectionFrames.contains(frame) ? Color.blue : Color.clear, width: 3)
                                .contextMenu {
                                    Button("Copy", action: { copyFrame(frame) })
                                    Button("Export", action: { exportFrame(frame) })
                                    Button("Select All", action: { selectAllFrames() })
                                    Button("Select All Before", action: { selectAllFrames(before: frame) })
                                    Button("Select All After", action: { selectAllFrames(after: frame) })
                                }
                                .onTapGesture {
                                    if selectedDetectionFrames.contains(frame) {
                                        selectedDetectionFrames.remove(frame)
                                    } else {
                                        selectedDetectionFrames.insert(frame)
                                    }
                                }
                                .onLongPressGesture {
                                    previewImage = frame.image
                                    isPreviewPresented = true
                                }
                        }
                    }
                }
                .frame(height: 200)
                .padding()

                HStack {
                    Button("Clear Frames", action: clearFrames)
                        .padding()

                    Button("Export Selected", action: exportSelectedFrames)
                        .padding()

                    Button("Export All", action: exportAllFrames)
                        .padding()
                }
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
        .sheet(isPresented: $isPreviewPresented) {
            if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .onTapGesture {
                        isPreviewPresented = false
                    }
            } else if let videoURL = previewVideo {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .onTapGesture {
                        isPreviewPresented = false
                    }
            }
        }
    }

    private func clearFrames() {
        processor.detectionFrames.removeAll()
        selectedDetectionFrames.removeAll()
    }

    private func exportSelectedFrames() {
        let selectedImages = selectedDetectionFrames.map { $0.image }
        exportImages(selectedImages)
    }

    private func exportAllFrames() {
        let allImages = processor.detectionFrames.map { $0.image }
        exportImages(allImages)
    }

    private func copyFrame(_ frame: CoreMLProcessor.DetectionFrame) {
        UIPasteboard.general.image = frame.image
    }

    private func exportFrame(_ frame: CoreMLProcessor.DetectionFrame) {
        exportImages([frame.image])
    }

    private func exportImages(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        let activityViewController = UIActivityViewController(activityItems: images, applicationActivities: nil)
        guard let window = UIApplication.shared.windows.first else { return }
        window.rootViewController?.present(activityViewController, animated: true, completion: nil)
    }

    private func selectAllFrames() {
        selectedDetectionFrames = Set(processor.detectionFrames)
    }

    private func selectAllFrames(before frame: CoreMLProcessor.DetectionFrame) {
        if let index = processor.detectionFrames.firstIndex(of: frame) {
            selectedDetectionFrames = Set(processor.detectionFrames.prefix(index))
        }
    }

    private func selectAllFrames(after frame: CoreMLProcessor.DetectionFrame) {
        if let index = processor.detectionFrames.firstIndex(of: frame) {
            selectedDetectionFrames = Set(processor.detectionFrames.suffix(from: index))
        }
    }
}


