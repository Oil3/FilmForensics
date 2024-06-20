import SwiftUI
import AVKit
import AVFoundation
import Vision
import CoreML

struct MainVideoView: View {
    @ObservedObject var mediaModel = MediaModel()
    @State private var player = AVPlayer()
    @State private var playerView = AVPlayerView()
    @State private var detectedObjects: [VNRecognizedObjectObservation] = []
    @State private var imageSize: CGSize = .zero
    @State private var videoSize: CGSize = .zero
    @State private var objectDetectionEnabled = false
    @State private var saveLabels = false
    @State private var saveFrames = false
    @State private var videoOutput: AVPlayerItemVideoOutput?
    @State private var isProcessing = false
    @State private var fpsMode = false
    @State private var framePerFrameMode = false
    @State private var loopMode = false
    @State private var playBackward = false
    @State private var autoPauseOnNewDetection = false
    @State private var showBoundingBoxes = true
    @State private var savePath: URL?
    @State private var totalObjectsDetected = 0
    @State private var droppedFrames = 0
    @State private var corruptedFrames = 0
    @State private var detectionFPS: Double = 0.0
    var body: some View {
        NavigationView {
            videoGallery
            videoPreview
        }
        .tabItem {
            Label("MainVideoView", systemImage: "video")
        }
        .onAppear {
            if let savedPath = UserDefaults.standard.url(forKey: "savePath") {
                savePath = savedPath
            }
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
                    let asset = AVAsset(url: url)
                    let playerItem = AVPlayerItem(asset: asset)
                    setupVideoOutput(for: playerItem)
                    player.replaceCurrentItem(with: playerItem)
                    playerView.player = player
                    startFrameExtraction()
                }) {
                    Text(url.lastPathComponent)
                }
            }

            Button("Clear All") {
                mediaModel.clearVideos()
                player.replaceCurrentItem(with: nil)
            }
            .padding()
        }
        .frame(minWidth: 200)
    }

    private var videoPreview: some View {
        VStack {
            if mediaModel.selectedVideoURL != nil {
                VStack {
                HStack {
                      HStack {
                        Text("File: \(mediaModel.selectedVideoURL?.lastPathComponent ?? "N/A")")
                        Text("Model: IO_cashtrack.mlmodel")
//                        Text("Input Shape: \(getModelInputShape())")
      }
            HStack {
                        //Text("Real-Time FPS: \(getVideoFrameRate(), specifier: "%.2f")")
                        Text("Time: \(player.currentTime().asTimeString() ?? "00:00:00")")
                        Text("Frame: \(getCurrentFrameNumber())")
                        Text("Total Frames: \(player.currentItem?.asset.totalNumberOfFrames ?? 0)")
                        Text("Dropped Frames: \(droppedFrames)")
                        Text("Corrupted Frames: \(corruptedFrames)")
                        //Text("Original Resolution: \(player.currentItem?.asset.tracks(withMediaType: .video).first?.naturalSize.width ?? 0)x\(player.currentItem?.asset.tracks(withMediaType: .video).first?.naturalSize.height ?? 0)")
                        }
                        HStack {
                        Text("Current Resolution: \(videoSize.width, specifier: "%.0f")x\(videoSize.height, specifier: "%.0f")")
                        Text("Detection FPS: \(detectionFPS, specifier: "%.2f")")
                      Text("Video FPS: \(getVideoFrameRate(), specifier: "%.2f")")

                        Text("Total Objects Detected: \(totalObjectsDetected)")
                    }
}
                            VStack {

                    VideoPlayerViewMain(player: player, detections: $detectedObjects)
                        .frame(minWidth: 640, maxWidth: 3200, minHeight: 360, maxHeight: 1800)
                        .overlay(
                            GeometryReader { geo -> AnyView in
                                DispatchQueue.main.async {
                                    self.videoSize = geo.size
                                }
                                return AnyView(
                                    ForEach(detectedObjects, id: \.self) { object in
                                        if showBoundingBoxes {
                                            drawBoundingBox(for: object, in: geo.size)
                                        }
                                    }
                                )
                            }
                        )
                        .scaledToFit()
}
                    VStack {
                        HStack {
                            Toggle("Enable Object Detection", isOn: $objectDetectionEnabled)

                            Toggle("Save Labels", isOn: $saveLabels)

                            Toggle("Save Frames", isOn: $saveFrames)

                            Toggle("Auto Pause on New Detection", isOn: $autoPauseOnNewDetection)
                        }

                        HStack {
                            Button("Select Save Path") {
                                selectSavePath()
                            }

                            if let savePath = savePath {
                                Text("Save Path: \(savePath.path)")
                            }
                        }

                        HStack {
                            Toggle("FPS Mode", isOn: $fpsMode)

                            Toggle("Frame Per Frame Mode", isOn: $framePerFrameMode)

                            Toggle("Loop", isOn: $loopMode)

                            Toggle("Play Backward", isOn: $playBackward)
                            
                            Toggle("Show Bounding Boxes", isOn: $showBoundingBoxes)
                        }

                        HStack {
                            Button("Play") {
                                player.play()
                                if fpsMode {
                                    startFPSMode()
                                }
                                if framePerFrameMode {
                                    startFramePerFrameMode()
                                }
                                if loopMode {
                                    player.actionAtItemEnd = .none
                                    NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                                        player.seek(to: .zero)
                                        player.play()
                                    }
                                }
                                if playBackward {
                                    startPlayBackwardMode()
                                }
                            }
                            Button("Pause") {
                                player.pause()
                                stopFPSMode()
                                stopFramePerFrameMode()
                                stopPlayBackwardMode()
                            }                        }
                            .padding()

                        HStack {
                            Button("Load All Labels") {
                                loadAllLabels()
                            }

                            Button("Load and Sync Labels") {
                                loadAndSyncLabels()
                            }
                        }
                    }
                }
            } else {
                Text("Select a video to preview")
                    .padding()
            }
        }
       }

    private func getVideoFrameRate() -> Float {
        return player.currentItem?.tracks.first?.currentVideoFrameRate ?? 0
    }

    private func getCurrentFrameNumber() -> Int {
        guard let currentItem = player.currentItem else { return 0 }
        let currentTime = currentItem.currentTime()
        let frameRate = currentItem.tracks.first?.currentVideoFrameRate ?? 0
        return Int(CMTimeGetSeconds(currentTime) * Double(frameRate))
    }

//    private func getModelInputShape() -> String {
//        let model = try! VNCoreMLModel(for: IO_cashtrack().model)
//      guard let inputDescription = model.inputImageFeatureName.first. else {
//            return "Unknown"
//        }
//        let inputShape = inputDescription
//                return inputShape
              
//    }

    private func drawBoundingBox(for observation: VNRecognizedObjectObservation, in parentSize: CGSize) -> some View {
        let boundingBox = observation.boundingBox
        let videoWidth = videoSize.width
        let videoHeight = videoSize.height
        let normalizedRect = CGRect(
            x: boundingBox.minX * videoWidth,
            y: (1 - boundingBox.maxY) * videoHeight,
            width: boundingBox.width * videoWidth,
            height: boundingBox.height * videoHeight
        )

        return Rectangle()
            .stroke(Color.red, lineWidth: 2)
            .frame(width: normalizedRect.width, height: normalizedRect.height)
            .position(x: normalizedRect.midX, y: normalizedRect.midY)
    }
 
    

    private func runModel(on pixelBuffer: CVPixelBuffer) {
        let model = try! VNCoreMLModel(for: IO_cashtrack().model)
        let request = VNCoreMLRequest(model: model) { request, error in
            let start = CFAbsoluteTimeGetCurrent()
            if let results = request.results as? [VNRecognizedObjectObservation] {
                DispatchQueue.main.async {
                    self.detectedObjects = results
                    self.totalObjectsDetected += results.count
                    if saveLabels || saveFrames {
                        processAndSaveDetections(results, at: player.currentItem?.currentTime())
                    }
                    if autoPauseOnNewDetection && results.isEmpty == false {
                        player.pause()
                    }
                    let end = CFAbsoluteTimeGetCurrent()
                    self.detectionFPS = 1.0 / (end - start)
                }
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    private func processAndSaveDetections(_ detections: [VNRecognizedObjectObservation], at time: CMTime?) {
        guard let time = time else { return }
        guard let savePath = savePath else { return }

        let frameNumber = Int(CMTimeGetSeconds(time) * 100) // Assuming 100 FPS for simplicity
        let labelFileName = "\(savePath.path)/frame_\(frameNumber).txt"
        let frameFileName = "\(savePath.path)/frame_\(frameNumber).jpg"
        
        var labelText = ""
        for detection in detections {
            let boundingBox = detection.boundingBox
            labelText += "0 \(boundingBox.midX) \(1 - boundingBox.midY) \(boundingBox.width) \(boundingBox.height)\n"
        }

        if !labelText.isEmpty {
            do {
                try labelText.write(toFile: labelFileName, atomically: true, encoding: .utf8)
            } catch {
                print("Error saving labels: \(error)")
            }

            if saveFrames {
                saveCurrentFrame(fileName: frameFileName)
            }
        }
    }

    private func saveCurrentFrame(fileName: String) {
        guard let pixelBuffer = mediaModel.currentPixelBuffer else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let nsImage = NSImage(cgImage: cgImage, size: .zero)

        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [:]) else { return }

        do {
            try jpegData.write(to: URL(fileURLWithPath: fileName))
        } catch {
            print("Error saving frame: \(error)")
        }
    }

    private func setupVideoOutput(for playerItem: AVPlayerItem) {
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: pixelBufferAttributes)
        playerItem.add(videoOutput)
        self.videoOutput = videoOutput
    }

    private func startFrameExtraction() {
        let interval = CMTime(value: 1, timescale: 40)
        player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            if let currentItem = player.currentItem,
               let videoOutput = self.videoOutput,
               videoOutput.hasNewPixelBuffer(forItemTime: time) {
                
                var presentationTime = CMTime()
                if let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: &presentationTime) {
                    mediaModel.currentFrame = pixelBuffer
                    mediaModel.currentPixelBuffer = pixelBuffer
                    if objectDetectionEnabled {
                        runModel(on: pixelBuffer)
                    }
                }
            }
        }
    }

    private func beginTrimming() {
        guard playerView.canBeginTrimming else { return }
        
        playerView.beginTrimming { result in
            if result == .okButton {
                exportTrimmedAsset()
            } else {
                print("Trimming canceled")
            }
        }
    }

    private func exportTrimmedAsset() {
        guard let playerItem = player.currentItem else { return }
        
        let preset = AVAssetExportPresetAppleM4V720pHD
        guard let exportSession = AVAssetExportSession(asset: playerItem.asset, presetName: preset) else {
            print("Error creating export session")
            return
        }
        exportSession.outputFileType = .m4v
        
        let outputURL = getSaveURL(fileName: "trimmed.m4v")
        exportSession.outputURL = outputURL
        
        let startTime = playerItem.reversePlaybackEndTime
        let endTime = playerItem.forwardPlaybackEndTime
        let timeRange = CMTimeRangeFromTimeToTime(start: startTime, end: endTime)
        exportSession.timeRange = timeRange
        
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                print("Export completed")
                DispatchQueue.main.async {
                    self.mediaModel.videos.append(outputURL)
                }
            case .failed:
                print("Export failed: \(String(describing: exportSession.error))")
            default:
                print("Export status: \(exportSession.status)")
            }
        }
    }

    private func getSaveURL(fileName: String) -> URL {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = fileName
        savePanel.canCreateDirectories = true
        savePanel.allowedFileTypes = ["m4v"]
        
        if savePanel.runModal() == .OK {
            return savePanel.url ?? URL(fileURLWithPath: "/dev/null")
        }
        return URL(fileURLWithPath: "/dev/null")
    }

    private func selectSavePath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            savePath = panel.url
            UserDefaults.standard.set(savePath, forKey: "savePath")
        }
    }

    private func loadAllLabels() {
        // Add implementation to load all labels as heatmap
    }

    private func loadAndSyncLabels() {
        // Add implementation to load and sync labels with the video playback
        // This would involve reading the labels and showing them at the corresponding frames
    }

    private func startFPSMode() {
        // Implement FPS mode: video speed ≤ detection speed(FPPS), and video framerate/playbackspeed increases gradually until we cant satisfy the condition
    }

    private func stopFPSMode() {
        // Stop FPS mode
    }

    private func startFramePerFrameMode() {
        // Implement frame-per-frame mode: reduces video speed to play one frame per second
    }

    private func stopFramePerFrameMode() {
        // Stop frame-per-frame mode
    }

    private func startPlayBackwardMode() {
        // Implement play backward mode
    }

    private func stopPlayBackwardMode() {
        // Stop play backward mode
    }
}

struct VideoPlayerViewMain: NSViewRepresentable {
    var player: AVPlayer
    @Binding var detections: [VNRecognizedObjectObservation]

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.player = player
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if let playerView = nsView as? AVPlayerView {
            playerView.player = player
        }
    }
}
