import SwiftUI
import AVKit
import Vision

struct MainVideoView: View {
    @ObservedObject var mediaModel = MediaModel()
    @State private var player = AVPlayer()
    @State private var isProcessing = false
    @State private var detections: [VNRecognizedObjectObservation] = []
    @State private var progress: Double = 0.0
    @State private var saveFrames = false
    @State private var outputFolderURL: URL?

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
                    
                    Button("Load All Labels") {
                        loadAllLabels()
                    }
                    .padding()
                    
                    Button("Load and Sync Labels") {
                        loadAndSyncLabels()
                    }
                    .padding()
                    
                    Toggle("Save Frames", isOn: $saveFrames)
                        .padding()
                }
                ProgressBar(value: $progress)
                    .frame(height: 10)
                    .padding()
            } else {
                Text("Select a video to preview")
                    .padding()
            }
        }
        .frame(minWidth: 400)
    }

    private func processVideo(url: URL) {
        isProcessing = true
        progress = 0.0

        let outputFolderPanel = NSOpenPanel()
        outputFolderPanel.canChooseFiles = false
        outputFolderPanel.canChooseDirectories = true
        outputFolderPanel.canCreateDirectories = true

        outputFolderPanel.begin { response in
            if response == .OK, let outputFolderURL = outputFolderPanel.url {
                self.outputFolderURL = outputFolderURL

                DispatchQueue.global(qos: .userInitiated).async {
                    let asset = AVAsset(url: url)
                    guard let videoTrack = asset.tracks(withMediaType: .video).first else {
                        return
                    }
                    let totalFrames = Int(asset.duration.seconds * Double(videoTrack.nominalFrameRate))
                    let interval = CMTime(value: 1, timescale: CMTimeScale(videoTrack.nominalFrameRate))

                    let readerSettings: [String: Any] = [
                        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                    ]
                    let reader = try! AVAssetReader(asset: asset)
                    let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerSettings)
                    reader.add(readerOutput)
                    reader.startReading()

                    var frameNumber = 0

                    while reader.status == .reading {
                        if let sampleBuffer = readerOutput.copyNextSampleBuffer(),
                           let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                            processFrame(pixelBuffer, frameNumber: frameNumber)
                            frameNumber += 1
                            progress = Double(frameNumber) / Double(totalFrames)

                            if saveFrames {
                                saveFrame(pixelBuffer, frameNumber: frameNumber)
                            }
                        }
                    }
                    isProcessing = false
                }
            }
        }
    }

    private func processFrame(_ pixelBuffer: CVPixelBuffer, frameNumber: Int) {
        let model = try! VNCoreMLModel(for: IO_cashtrack().model)
        let request = VNCoreMLRequest(model: model) { request, error in
            if let results = request.results as? [VNRecognizedObjectObservation] {
                saveDetections(results, frameNumber: frameNumber)
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    private func saveDetections(_ detections: [VNRecognizedObjectObservation], frameNumber: Int) {
        guard let outputFolderURL = outputFolderURL else { return }
        let labelFileURL = outputFolderURL.appendingPathComponent("frame_\(frameNumber).txt")

        var labelContent = ""
        for detection in detections {
            let bbox = detection.boundingBox
            labelContent += "0 \(bbox.minX) \(bbox.minY) \(bbox.width) \(bbox.height)\n"
        }

        try? labelContent.write(to: labelFileURL, atomically: true, encoding: .utf8)
    }

    private func saveFrame(_ pixelBuffer: CVPixelBuffer, frameNumber: Int) {
        guard let outputFolderURL = outputFolderURL else { return }
        let context = CIContext()
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        let nsImage = NSImage(cgImage: cgImage!, size: .zero)

        let imageFileURL = outputFolderURL.appendingPathComponent("frame_\(frameNumber).jpg")
        nsImage.saveAsJpeg(to: imageFileURL)
    }

    private func loadAllLabels() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false

        panel.begin { response in
            if response == .OK, let folderURL = panel.url {
                loadAllLabels(from: folderURL)
            }
        }
    }

    private func loadAllLabels(from folderURL: URL) {
        detections.removeAll()
        let fileManager = FileManager.default
        if let fileURLs = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) {
            for fileURL in fileURLs where fileURL.pathExtension == "txt" {
                if let content = try? String(contentsOf: fileURL) {
                    for line in content.split(separator: "\n") {
                        let components = line.split(separator: " ")
                        if components.count == 5 {
                            let x = Double(components[1])!
                            let y = Double(components[2])!
                            let width = Double(components[3])!
                            let height = Double(components[4])!
                            let boundingBox = VNRectangleObservation(boundingBox: CGRect(x: x, y: y, width: width, height: height))
                            detections.append(VNRecognizedObjectObservation(boundingBox: boundingBox.boundingBox))
                        }
                    }
                }
            }
        }
    }

    private func loadAndSyncLabels() {
        // Add implementation to load and sync labels with the video playback
        // This would involve reading the labels and showing them at the corresponding frames
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

struct ProgressBar: View {
    @Binding var value: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .opacity(0.3)
                    .foregroundColor(Color(NSColor.systemTeal))
                
                Rectangle()
                    .frame(width: min(CGFloat(self.value)*geometry.size.width, geometry.size.width), height: geometry.size.height)
                    .foregroundColor(Color(NSColor.systemBlue))
                    .animation(.linear)
            }
            .cornerRadius(45.0)
        }
    }
}

extension NSImage {
    func saveAsJpeg(to url: URL) {
        guard let tiffData = self.tiffRepresentation else { return }
        guard let bitmapImageRep = NSBitmapImageRep(data: tiffData) else { return }
        guard let jpegData = bitmapImageRep.representation(using: .jpeg, properties: [:]) else { return }

        try? jpegData.write(to: url)
    }
}
