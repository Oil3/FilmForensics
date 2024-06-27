import SwiftUI
import AVKit
import AVFoundation
import Vision
import CoreML

struct VideoToolsView: View {
    @ObservedObject var mediaModel = MediaModel()
    @State private var player = AVPlayer()
    @State private var playerView = AVPlayerView()
    @State private var detectedObjects: [VNRecognizedObjectObservation] = []
    @State private var imageSize: CGSize = .zero
    @State private var videoSize: CGSize = .zero
    @State private var objectDetectionEnabled = false
    @State private var videoOutput: AVPlayerItemVideoOutput?
    
    var body: some View {
        NavigationView {
            videoGallery
            videoEditor
        }
        .tabItem {
            Label("VideoTools", systemImage: "scissors")
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

    private var videoEditor: some View {
        VStack {
            if mediaModel.selectedVideoURL != nil {
                VStack {
                    VStack {
                        Text("Duration: \(player.currentItem?.asset.duration.seconds ?? 0, specifier: "%.2f")s")
                        Text("FPS: \(player.currentItem?.asset.tracks(withMediaType: .video).first?.nominalFrameRate ?? 0, specifier: "%.2f")")
                    }
                    
VStack {
                    VideoPlayerView(playerView: playerView)
                        .frame(minWidth: 640, maxWidth: 3200, minHeight: 360, maxHeight: 1800)
                     
                        .overlay(
                            GeometryReader { geo -> AnyView in
                                if let pixelBuffer = mediaModel.currentPixelBuffer {

                                    DispatchQueue.main.async {
                                        self.videoSize = geo.size
                                        
                                        if objectDetectionEnabled {                                                runModel(on: pixelBuffer)
                                            }
                                        }
                                    return AnyView(
                                    
                                            ForEach(detectedObjects, id: \.self) { object in
                                                drawBoundingBox(for: object, in: geo.size)
                                        }
                                    )
                                    
                                }
else {
                                    return AnyView(EmptyView())
                                }
                            }

                        )
                    .scaledToFit()
                    
}
                    Button("Enable Object Detection") {
                        objectDetectionEnabled.toggle()
                    }
                    .padding()

                    Button("Trim Video") {
                        beginTrimming()
                    }
                    .padding()
                    
                }
                
            } else {
                Text("Select a video to edit")
                    .padding()
            }
        }
                            

        //.frame(maxWidth: 1080)
      //  .aspectRatio(contentMode: .)
      //  .colorMultiply(.blue)
    }
    
    private func calculateVideoFrame(for containerSize: CGSize) -> CGSize {
        guard let videoTrack = player.currentItem?.asset.tracks(withMediaType: .video).first else {
            return .zero
        }

        let videoSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        let videoRatio = abs(videoSize.width / videoSize.height)
        let containerRatio = containerSize.width / containerSize.height

        if videoRatio > containerRatio {
            return CGSize(width: containerSize.width, height: containerSize.width / videoRatio)
        } else {
            return CGSize(width: containerSize.height * videoRatio, height: containerSize.height)
        }
    }

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
                  DispatchQueue.main.async {
        let request = VNCoreMLRequest(model: model) { request, error in
            if let results = request.results as? [VNRecognizedObjectObservation] {
                    self.detectedObjects = results
                }
            }
        

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
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
//                    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
//                    let context = CIContext()
//                    if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
//                        let nsImage = NSImage(cgImage: cgImage, size: .zero)
                        mediaModel.currentFrame = pixelBuffer
                        mediaModel.currentPixelBuffer = pixelBuffer
//                    }
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
}

struct VideoPlayerView: NSViewRepresentable {
    var playerView: AVPlayerView
  
    func makeNSView(context: Context) -> AVPlayerView {
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
    //playerView.bounds = nsView.bounds
    nsView.allowsMagnification = true
    nsView.showsFrameSteppingButtons = true
    nsView.allowsVideoFrameAnalysis = true
    nsView.videoFrameAnalysisTypes = .default
    nsView.controlsStyle = .floating
    nsView.allowsPictureInPicturePlayback = true
    }
    
}

extension CMTime {
    func asTimeString() -> String? {
        let totalSeconds = CMTimeGetSeconds(self)
        guard !(totalSeconds.isNaN || totalSeconds.isInfinite) else { return nil }
        let hours = Int(totalSeconds) / 3600
        let minutes = Int(totalSeconds) % 3600 / 60
        let seconds = Int(totalSeconds) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

extension AVAsset {
    var totalNumberOfFrames: Int {
        let duration = CMTimeGetSeconds(self.duration)
        let frameRate = self.nominalFrameRate
        return Int(duration * Double(frameRate))
        } 
    

    var nominalFrameRate: Float {
        return self.tracks(withMediaType: .video).first?.nominalFrameRate ?? 0
    }
}


//private func loadAllLabels() {
//  guard let savePath = savePath else { return }
//  
//  let fileManager = FileManager.default
//  do {
//    let fileURLs = try fileManager.contentsOfDirectory(at: savePath, includingPropertiesForKeys: nil)
//    var allDetections: [VNRecognizedObjectObservation] = []
//    
//    for fileURL in fileURLs where fileURL.pathExtension == "txt" {
//      let content = try String(contentsOf: fileURL)
//      let lines = content.split(separator: "\n")
//      for line in lines {
//        let components = line.split(separator: " ")
//        if components.count == 5, let x = Double(components[1]), let y = Double(components[2]), let width = Double(components[3]), let height = Double(components[4]) {
//          let boundingBox = CGRect(x: x, y: y, width: width, height: height)
//          let observation = VNRecognizedObjectObservation(boundingBox: boundingBox)
//          allDetections.append(observation)
//        }
//      }
//    }
//    self.detectedObjects = allDetections
//  } catch {
//    print("Error loading labels: \(error)")
//  }
//}


//HStack {
//  Button("Load All Labels") {
//    loadAllLabels()
//  }
//  Button("Load and Sync Labels") {
//    loadAndSyncLabels()
//  }
//}
//
//private func loadAndSyncLabels() {
//  guard let savePath = savePath else { return }
//  
//  let fileManager = FileManager.default
//  do {
//    let fileURLs = try fileManager.contentsOfDirectory(at: savePath, includingPropertiesForKeys: nil)
//    var frameDetections: [Int: [VNRecognizedObjectObservation]] = [:]
//    
//    for fileURL in fileURLs where fileURL.pathExtension == "txt" {
//      let frameNumber = Int(fileURL.deletingPathExtension().lastPathComponent.split(separator: "_").last ?? "") ?? 0
//      let content = try String(contentsOf: fileURL)
//      let lines = content.split(separator: "\n")
//      var detections: [VNRecognizedObjectObservation] = []
//      
//      for line in lines {
//        let components = line.split(separator: " ")
//        if components.count == 5, let x = Double(components[1]), let y = Double(components[2]), let width = Double(components[3]), let height = Double(components[4]) {
//          let boundingBox = CGRect(x: x, y: y, width: width, height: height)
//          let observation = VNRecognizedObjectObservation(boundingBox: boundingBox)
//          detections.append(observation)
//        }
//      }
//      frameDetections[frameNumber] = detections
//    }
//    
//    self.detectedObjects = []
//    player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { time in
//      let frameNumber = Int(CMTimeGetSeconds(time) * Double(self.getVideoFrameRate()))
//      self.detectedObjects = frameDetections[frameNumber] ?? []
//    }
//  } catch {
//    print("Error loading labels: \(error)")
//  }
//  }
