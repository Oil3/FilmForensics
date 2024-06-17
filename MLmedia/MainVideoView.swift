import SwiftUI
import AVKit
import Vision

struct MainVideoView: View {
    @ObservedObject var mediaModel = MediaModel()
    @State private var player = AVPlayer()
    @State private var isProcessing = false
    @State private var detections: [VNRecognizedObjectObservation] = []

    var body: some View {
        NavigationView {
            videoGallery
            videoPreview
        }
        .tabItem {
            Label("MainVideoView", systemImage: "video")
        }
    }

    private var videoGallery: some View {
        VStack {
            Button("Add Video") {
                mediaModel.addVideos()
            }
            .padding()

            List(mediaModel.videos, id: \.self) { url in
                Button(action: {
                    mediaModel.selectedVideoURL = url
                    player = AVPlayer(url: url)
                }) {
                    Text(url.lastPathComponent)
                }
            }

            Button("Clear All") {
                mediaModel.clearVideos()
                player = AVPlayer()
            }
            .padding()
        }
        .frame(minWidth: 200)
    }

    private var videoPreview: some View {
        VStack {
            if let selectedVideoURL = mediaModel.selectedVideoURL {
                VideoPlayer(player: player)
                    .frame(height: 400)
                    .overlay(BoundingBoxOverlay(detections: detections), alignment: .topLeading)
                
                HStack {
                    Button("Process Video") {
                        processVideo(url: selectedVideoURL)
                    }
                    .padding()
                    
                    Button("Play") {
                        player.play()
                    }
                    .padding()
                    
                    Button("Pause") {
                        player.pause()
                    }
                    .padding()
                }
            } else {
                Text("Select a video to preview")
                    .padding()
            }
        }
        .frame(minWidth: 400)
    }

    private func processVideo(url: URL) {
        // Placeholder for CoreML video processing logic
        // Add your model and video processing code here
        // For each frame with detections, save frame and create YOLOv8 annotations
    }
}

struct BoundingBoxOverlay: View {
    var detections: [VNRecognizedObjectObservation]
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(detections, id: \.self) { detection in
                let boundingBox = detection.boundingBox
                let rect = CGRect(
                    x: boundingBox.minX * geometry.size.width,
                    y: (1 - boundingBox.maxY) * geometry.size.height,
                    width: boundingBox.width * geometry.size.width,
                    height: boundingBox.height * geometry.size.height
                )
                
                Rectangle()
                    .stroke(Color.red, lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
    }
}
