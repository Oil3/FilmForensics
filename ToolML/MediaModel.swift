//
//  MediaModel.swift
//  ToolML
//
//  Created by Almahdi Morris on 15/6/24.
//
import SwiftUI
import AVKit

enum MediaType {
    case image
    case video
}

class MediaModel: ObservableObject, Identifiable, Hashable {
    static func == (lhs: MediaModel, rhs: MediaModel) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    let id = UUID()
    let url: URL
    @Published var image: NSImage?
    @Published var videoThumbnail: NSImage?
    @Published var videoPlayer: AVPlayer?
    @Published var currentFrame: NSImage?
    let type: MediaType

    init(url: URL, type: MediaType) {
        self.url = url
        self.type = type
        if type == .video {
            self.videoPlayer = AVPlayer(url: url)
            generateThumbnail()
        } else if type == .image {
            loadImage()
        }
    }

    func loadImage() {
        if type == .image && image == nil {
            if let nsImage = NSImage(contentsOf: url) {
                DispatchQueue.main.async {
                    self.image = nsImage
                }
            }
        }
    }

    func generateThumbnail() {
        guard type == .video else { return }
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        let time = CMTime(seconds: 1, preferredTimescale: 60)
        if let cgImage = try? imageGenerator.copyCGImage(at: time, actualTime: nil) {
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            DispatchQueue.main.async {
                self.videoThumbnail = nsImage
            }
        }
    }

    func startVideo() {
        videoPlayer?.play()
        extractFrame()
    }

    func pauseVideo() {
        videoPlayer?.pause()
    }

    func extractFrame() {
        guard let player = videoPlayer, let currentItem = player.currentItem else { return }
        let currentTime = player.currentTime()

        let imageGenerator = AVAssetImageGenerator(asset: currentItem.asset)
        imageGenerator.appliesPreferredTrackTransform = true

        imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: currentTime)]) { _, cgImage, _, _, _ in
            if let cgImage = cgImage {
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                DispatchQueue.main.async {
                    self.currentFrame = nsImage
                }
            }
        }
    }
}
