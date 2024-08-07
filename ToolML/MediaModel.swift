import SwiftUI
import AVKit
import Vision
import Combine

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
    @Published var thumbnail: NSImage?
    @Published var videoThumbnail: NSImage?
    @Published var videoPlayer: AVPlayer?
    @Published var currentFrame: NSImage?
    @Published var detectedObjects: [VNRecognizedObjectObservation] = []
    let type: MediaType
    var cancellables = Set<AnyCancellable>()

    init(url: URL, type: MediaType) {
        self.url = url
        self.type = type
        if type == .video {
            self.videoPlayer = AVPlayer(url: url)
            generateVideoThumbnail()
        } else if type == .image {
            generateImageThumbnail()
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

    func generateImageThumbnail() {
        guard type == .image else { return }
      let targetSize = NSSize(width: 100, height: 100)//, height: 100)
        if let nsImage = NSImage(contentsOf: url) {
            let thumbnail = nsImage.resizeImage(targetSize: targetSize)
            DispatchQueue.main.async {
                self.thumbnail = thumbnail
            }
        }
    }

    func generateVideoThumbnail() {
        guard type == .video else { return }
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        let time = CMTime(seconds: 1, preferredTimescale: 60)
        if let cgImage = try? imageGenerator.copyCGImage(at: time, actualTime: nil) {
            let thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: 100, height: 100))
            DispatchQueue.main.async {
                self.videoThumbnail = thumbnail
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
                    self.runModelOnImage(nsImage)
                }
            }
        }
    }

    func runModelOnImage(_ image: NSImage) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let model = try! VNCoreMLModel(for: best().model)

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
}

extension NSImage {
    func resizeImage(targetSize: NSSize) -> NSImage {
let originalSize = self.size
        let widthRatio  = targetSize.width  / originalSize.width
        let heightRatio = targetSize.height / originalSize.height
                let scaleFactor = min(widthRatio, heightRatio)
        let scaledSize = NSSize(width: originalSize.width * scaleFactor, height: originalSize.height * scaleFactor)
        let newImage = NSImage(size: scaledSize)
        newImage.lockFocus()
        let ctx = NSGraphicsContext.current
        ctx?.imageInterpolation = .none
        self.draw(in: NSRect(origin: .zero, size: scaledSize), from: NSRect(origin: .zero, size: originalSize), operation: .copy, fraction: 1)
        newImage.unlockFocus()
        return newImage
    }
}
