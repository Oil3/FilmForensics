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
import Vision
import AVFoundation
import AVKit
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

struct HandDetection: Codable, Identifiable {
  var id = UUID()
  //var jointName: VNHumanHandPoseObservation.JointName
  var location: CGPoint
}

struct HandFrameLog: Codable {
  var frameNumber: Int
  var detections: [HandDetection]?
}

struct HandDetectionLog: Codable {
  var videoURL: String
  var creationDate: String
  var frames: [HandFrameLog]
}






struct FaceDetection: Codable, Identifiable {
  var id = UUID()
  var boundingBox: CGRect
}

struct FaceFrameLog: Codable {
  var frameNumber: Int
  var detections: [FaceDetection]?
}

struct FaceDetectionLog: Codable {
  var videoURL: String
  var creationDate: String
  var frames: [FaceFrameLog]
}

struct HumanDetection: Codable, Identifiable {
  var id = UUID()
  var boundingBox: CGRect
}

struct HumanFrameLog: Codable {
  var frameNumber: Int
  var detections: [HumanDetection]?
}

struct HumanDetectionLog: Codable {
  var videoURL: String
  var creationDate: String
  var frames: [HumanFrameLog]
}
