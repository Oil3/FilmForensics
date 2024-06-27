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
