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
    @State private var objectDetectionEnabled = false

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
                    HStack {
                        Text("Duration: \(player.currentItem?.asset.duration.seconds ?? 0, specifier: "%.2f")s")
                        Text("FPS: \(player.currentItem?.asset.tracks(withMediaType: .video).first?.nominalFrameRate ?? 0, specifier: "%.2f")")
                    }
                    .padding()

                    VideoPlayerView(playerView: playerView)
                        .frame(height: 400)
                        .overlay(
                            GeometryReader { geo -> AnyView in
                                if let frame = mediaModel.currentFrame {
                                    DispatchQueue.main.async {
                                        self.imageSize = geo.size
                                        if objectDetectionEnabled {
                                            runModel(on: frame)
                                        }
                                    }
                                    return AnyView(
                                        ZStack {
                                            Image(nsImage: frame)
                                                .resizable()
                                                .background(GeometryReader { geo -> Color in
                                                    DispatchQueue.main.async {
                                                        self.imageSize = geo.size
                                                    }
                                                    return Color.clear
                                                })
                                            ForEach(detectedObjects, id: \.self) { object in
                                                drawBoundingBox(for: object, in: geo.size)
                                            }
                                        }
                                    )
                                } else {
                                    return AnyView(EmptyView())
                                }
                            }
                        )

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
        .frame(minWidth: 400)
    }

    private func drawBoundingBox(for observation: VNRecognizedObjectObservation, in parentSize: CGSize) -> some View {
        let boundingBox = observation.boundingBox
        let imageWidth = imageSize.width
        let imageHeight = imageSize.height

        let normalizedRect = CGRect(
            x: boundingBox.minX * imageWidth,
            y: (1 - boundingBox.maxY) * imageHeight,
            width: boundingBox.width * imageWidth,
            height: boundingBox.height * imageHeight
        )

        return Rectangle()
            .stroke(Color.red, lineWidth: 2)
            .frame(width: normalizedRect.width, height: normalizedRect.height)
            .position(x: normalizedRect.midX, y: normalizedRect.midY)
    }

    private func runModel(on image: NSImage) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let model = try! VNCoreMLModel(for: IO_cashtrack().model)

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

    private func startFrameExtraction() {
        let interval = CMTime(value: 1, timescale: 1)
        player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            if let currentItem = player.currentItem {
                let currentTime = currentItem.currentTime()
                let generator = AVAssetImageGenerator(asset: currentItem.asset)
                generator.appliesPreferredTrackTransform = true
                generator.requestedTimeToleranceAfter = .zero
                generator.requestedTimeToleranceBefore = .zero

                do {
                    let cgImage = try generator.copyCGImage(at: currentTime, actualTime: nil)
                    let nsImage = NSImage(cgImage: cgImage, size: .zero)
                    let resizedImage = resizeImage(image: nsImage, targetSize: CGSize(width: 640, height: 640))
                    mediaModel.currentFrame = resizedImage
                } catch {
                    print("Error extracting frame: \(error)")
                }
            }
        }
    }

    private func resizeImage(image: NSImage, targetSize: CGSize) -> NSImage {
        let img = NSImage(size: targetSize)
        img.lockFocus()
        let ctx = NSGraphicsContext.current
        ctx?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: targetSize), from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1)
        img.unlockFocus()
        return img
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

    func updateNSView(_ nsView: AVPlayerView, context: Context) {}
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
