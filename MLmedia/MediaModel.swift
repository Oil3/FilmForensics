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




struct FaceDetection: Codable, Identifiable {
  var id = UUID()
  var boundingBox: CGRect
}

struct FaceDetectionLog: Codable {
  let videoURL: String
  let creationDate: String
  var frames: [FaceFrameLog]
}

struct FaceFrameLog: Codable {
  var frameNumber: Int
  var detections: [FaceDetection]?
}
