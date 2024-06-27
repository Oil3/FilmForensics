import SwiftUI

class MediaModel: ObservableObject {
  @Published var videos: [URL] = []
  @Published var selectedVideoURL: URL?
  @Published var currentFrame: CVPixelBuffer?
  @Published var currentPixelBuffer: CVPixelBuffer?
  
  func addVideos() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseFiles = true
    panel.allowedFileTypes = ["mp4", "mov"]
    if panel.runModal() == .OK {
      videos.append(contentsOf: panel.urls)
    }
  }
  
  func clearVideos() {
    videos.removeAll()
    selectedVideoURL = nil
    currentFrame = nil
    currentPixelBuffer = nil
  }
}

import Vision
import AVFoundation
import AVKit

extension URL {
  func bookmarkData() -> Data {
    return (try? self.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)) ?? Data()
  }
}

extension CFAbsoluteTime {
  var asTimeString: String? {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = .positional
    return formatter.string(from: self)
  }
}

struct VideoPlayerViewMain: NSViewRepresentable {
  var player: AVPlayer
  @Binding var detections: [VNRecognizedObjectObservation]
  
  func makeNSView(context: Context) -> AVPlayerView {
    let playerView = AVPlayerView()
    playerView.player = player
    playerView.allowsMagnification = true
    playerView.allowsPictureInPicturePlayback = true
    playerView.controlsStyle = .floating
    playerView.autoresizingMask = .none
    playerView.videoFrameAnalysisTypes = .subject
    return playerView
  }
  
  func updateNSView(_ nsView: AVPlayerView, context: Context) {
    if let playerView = nsView as? AVPlayerView {
      playerView.player = player
    }
  }
}

extension CGRect {
  func scaled(to size: CGSize) -> CGRect {
    let scaleX = size.width / self.width
    let scaleY = size.height / self.height
    return CGRect(x: self.origin.x * scaleX,
                  y: self.origin.y * scaleY,
                  width: self.width * scaleX,
                  height: self.height * scaleY)
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

extension NSImage {
  var cgImage: CGImage? {
    guard let data = tiffRepresentation else { return nil }
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
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


extension Array where Element == Double {
  func distance(to vector: [Double]) -> Double {
    return zip(self, vector).map { pow($0 - $1, 2) }.reduce(0, +)
  }
}
