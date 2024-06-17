import SwiftUI
import AVKit
import AVFoundation

struct VideoToolsView: View {
    @ObservedObject var mediaModel = MediaModel()
    @State private var player = AVPlayer()
    @State private var startTrim: Double = 0
    @State private var endTrim: Double = 1
    @State private var cropRect: CGRect = CGRect(x: 50, y: 50, width: 100, height: 100)
    @State private var videoDuration: CMTime = .zero
    @State private var playerItem: AVPlayerItem?

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
                    videoDuration = asset.duration
                    playerItem = AVPlayerItem(asset: asset)
                    player = AVPlayer(playerItem: playerItem)
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

    private var videoEditor: some View {
        VStack {
            if let selectedVideoURL = mediaModel.selectedVideoURL {
                ZStack {
                    VideoPlayer(player: player)
                        .frame(height: 400)
                        .overlay(
                            GeometryReader { geometry in
                                Rectangle()
                                    .stroke(Color.green, lineWidth: 2)
                                    .frame(width: cropRect.width, height: cropRect.height)
                                    .position(x: cropRect.midX, y: cropRect.midY)
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                let newX = cropRect.origin.x + value.translation.width
                                                let newY = cropRect.origin.y + value.translation.height
                                                if newX >= 0 && newX + cropRect.width <= geometry.size.width {
                                                    cropRect.origin.x = newX
                                                }
                                                if newY >= 0 && newY + cropRect.height <= geometry.size.height {
                                                    cropRect.origin.y = newY
                                                }
                                            }
                                    )
                                    .gesture(
                                        MagnificationGesture()
                                            .onChanged { value in
                                                let newWidth = cropRect.width * value
                                                let newHeight = cropRect.height * value
                                                if newWidth <= geometry.size.width && newHeight <= geometry.size.height && newWidth > 50 && newHeight > 50 {
                                                    cropRect.size.width = newWidth
                                                    cropRect.size.height = newHeight
                                                }
                                            }
                                    )
                            }
                        )
                    
                    VStack {
                        HStack {
                            Text("Trim Start")
                            Slider(value: $startTrim, in: 0...1, step: 0.01)
                            Text(String(format: "%.2f", startTrim * videoDuration.seconds))
                        }
                        HStack {
                            Text("Trim End")
                            Slider(value: $endTrim, in: 0...1, step: 0.01)
                            Text(String(format: "%.2f", endTrim * videoDuration.seconds))
                        }
                   
                    .padding()
                

                HStack {
                    Button("Trim Video") {
                        Task {
                            await trimVideo(url: selectedVideoURL, start: startTrim, end: endTrim)
                        }
                    }
                    .padding()
                    
                    Button("Crop Video") {
                        Task {
                            await cropVideo(url: selectedVideoURL, rect: cropRect)
                        }
                    }
                    .padding()
                }
            } 
        }
        .frame(minWidth: 400)
    }
}
}
    private func trimVideo(url: URL, start: Double, end: Double) async {
        let asset = AVAsset(url: url)
        let startTime = CMTime(seconds: start * asset.duration.seconds, preferredTimescale: asset.duration.timescale)
        let endTime = CMTime(seconds: end * asset.duration.seconds, preferredTimescale: asset.duration.timescale)
        let timeRange = CMTimeRange(start: startTime, end: endTime)

        do {
            try await asset.loadValues(forKeys: ["tracks"])
        } catch {
            print("Tracks not loaded")
            return
        }

        let composition = AVMutableComposition()
        do {
            if let videoTrack = asset.tracks(withMediaType: .video).first {
                let videoCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
                try videoCompositionTrack?.insertTimeRange(timeRange, of: videoTrack, at: .zero)
            }
            if let audioTrack = asset.tracks(withMediaType: .audio).first {
                let audioCompositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                try audioCompositionTrack?.insertTimeRange(timeRange, of: audioTrack, at: .zero)
            }
        } catch {
            print("Error creating composition: \(error)")
            return
        }

        let videoComposition = AVMutableVideoComposition()
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = timeRange

        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: composition.tracks(withMediaType: .video).first!)
        instruction.layerInstructions = [transformer]
        videoComposition.instructions = [instruction]
        videoComposition.renderSize = CGSize(width: composition.tracks(withMediaType: .video).first!.naturalSize.width, height: composition.tracks(withMediaType: .video).first!.naturalSize.height)
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            print("Error creating export session")
            return
        }

        let outputURL = url.deletingPathExtension().appendingPathExtension("trimmed.mp4")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition

        await exportSession.export()

        if exportSession.status == .completed {
            DispatchQueue.main.async {
                self.mediaModel.videos.append(outputURL)
            }
        } else {
            print("Export failed: \(String(describing: exportSession.error))")
        }
    }

    private func cropVideo(url: URL, rect: CGRect) async {
        let asset = AVAsset(url: url)
        let composition = AVMutableComposition()
        guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first else {
            print("No video track found")
            return
        }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = CGSize(width: rect.width, height: rect.height)
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)

        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        let scale = CGAffineTransform(scaleX: rect.width / videoTrack.naturalSize.width, y: rect.height / videoTrack.naturalSize.height)
        let move = CGAffineTransform(translationX: -rect.minX, y: -rect.minY)
        transformer.setTransform(scale.concatenating(move), at: .zero)
        instruction.layerInstructions = [transformer]
        videoComposition.instructions = [instruction]

        let outputURL = url.deletingPathExtension().appendingPathExtension("cropped.mp4")
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            print("Error creating export session")
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition

        await exportSession.export()

        if exportSession.status == .completed {
            DispatchQueue.main.async {
                self.mediaModel.videos.append(outputURL)
            }
        } else {
            print("Export failed: \(String(describing: exportSession.error))")
        }
    }
}
