import SwiftUI
import AVFoundation
import Vision
import CoreML

class VideoProcessor: ObservableObject {
  private var sequenceRequestHandler = VNSequenceRequestHandler()
  private var dispatchQueue = DispatchQueue(label: "com.example.VideoProcessor")
  private var asset: AVAsset?
  fileprivate var startTime: CFAbsoluteTime?
  fileprivate var frameCount: Int = 0
  
  @Published var isProcessing: Bool = false
  @Published var selectedModelURL: URL?
  @Published var logs: [(id: UUID, message: String)] = []
  fileprivate var savePath: URL?
  
  func processVideo(url: URL, startTime: CMTime, duration: CMTime, requests: [VNRequest], saveFrames: Bool, saveLabels: Bool) {
    asset = AVAsset(url: url)
    
    guard let asset = asset else {
      print("Failed to initialize AVAsset")
      return
    }
    
    isProcessing = true
    self.frameCount = 0
    self.startTime = CFAbsoluteTimeGetCurrent()
    
    let reader = try! AVAssetReader(asset: asset)
    let videoTrack = asset.tracks(withMediaType: .video).first!
    let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ])
    reader.add(readerOutput)
    reader.startReading()
    
    dispatchQueue.async { [weak self] in
      guard let self = self else { return }
      while reader.status == .reading {
        if let sampleBuffer = readerOutput.copyNextSampleBuffer(),
           let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
          self.handleFrame(pixelBuffer: pixelBuffer, requests: requests, videoURL: url, saveFrames: saveFrames, saveLabels: saveLabels)
        }
      }
      
      DispatchQueue.main.async {
        self.isProcessing = false
      }
      
      if reader.status == .completed {
        print("Video processing completed.")
      } else if reader.status == .failed {
        print("Video processing failed: \(reader.error?.localizedDescription ?? "Unknown error")")
      }
    }
  }
  
  func cancelProcessing() {
    isProcessing = false
  }
  
  func selectCoreMLModel() {
    let panel = NSOpenPanel()
    panel.allowedFileTypes = ["mlmodelc"]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.begin { response in
      if response == .OK, let url = panel.url {
        self.selectedModelURL = url
      }
    }
  }
  
  func selectSavePath() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    panel.begin { response in
      if response == .OK, let url = panel.url {
        self.savePath = url
      }
    }
  }
  
  fileprivate func logDetection(videoURL: URL, detections: [VNObservation], detectionType: String, elapsedTime: Double, saveFrames: Bool, saveLabels: Bool, pixelBuffer: CVPixelBuffer?) {
    frameCount += 1
    let videoPath = videoURL.path
    var detectionInfo = detections.map { observation -> String in
      if let objectObservation = observation as? VNRecognizedObjectObservation {
        let topLabel = objectObservation.labels.first?.identifier ?? "unknown"
        return "\(topLabel) (\(objectObservation.confidence))"
      } else if let faceObservation = observation as? VNFaceObservation {
        return "Face"
      } else if let handObservation = observation as? VNHumanHandPoseObservation {
        return "Hand"
      } else if let bodyPoseObservation = observation as? VNHumanBodyPoseObservation {
        return "Body Pose"
      } else {
        return "Unknown"
      }
    }.joined(separator: ", ")
    
    let frameInfo = "video \(frameCount) / \(videoPath): \(detectionType) [\(detectionInfo)], \(String(format: "%.1f", elapsedTime)) ms"
    DispatchQueue.main.async {
      self.logs.append((id: UUID(), message: frameInfo))
    }
    
    if saveFrames, let pixelBuffer = pixelBuffer {
      saveFrame(videoURL: videoURL, frameNumber: frameCount, pixelBuffer: pixelBuffer)
    }
    
    if saveLabels {
      saveLabel(videoURL: videoURL, frameNumber: frameCount, detections: detections)
    }
  }
  
  private func saveFrame(videoURL: URL, frameNumber: Int, pixelBuffer: CVPixelBuffer) {
    guard let savePath = savePath else { return }
    let framePath = savePath.appendingPathComponent("frames")
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: framePath.path) {
      try? fileManager.createDirectory(at: framePath, withIntermediateDirectories: true, attributes: nil)
    }
    
    let imageName = "\(videoURL.deletingPathExtension().lastPathComponent)_frame_\(frameNumber).jpg"
    let imagePath = framePath.appendingPathComponent(imageName)
    
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let context = CIContext()
    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
    let nsImage = NSImage(cgImage: cgImage, size: .zero)
    
    guard let tiffData = nsImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let jpegData = bitmap.representation(using: .jpeg, properties: [:]) else { return }
    
    do {
      try jpegData.write(to: imagePath)
    } catch {
      print("Error saving frame: \(error)")
    }
  }
  
  private func saveLabel(videoURL: URL, frameNumber: Int, detections: [VNObservation]) {
    guard let savePath = savePath else { return }
    let labelPath = savePath.appendingPathComponent("labels")
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: labelPath.path) {
      try? fileManager.createDirectory(at: labelPath, withIntermediateDirectories: true, attributes: nil)
    }
    
    let labelName = "\(videoURL.deletingPathExtension().lastPathComponent)_frame_\(frameNumber).txt"
    let labelFilePath = labelPath.appendingPathComponent(labelName)
    
    var labelContent = ""
    for observation in detections {
      if let objectObservation = observation as? VNRecognizedObjectObservation {
        let topLabel = objectObservation.labels.first?.identifier ?? "unknown"
        let confidence = objectObservation.confidence
        labelContent += "\(topLabel) \(confidence)\n"
      }
    }
    
    try? labelContent.write(to: labelFilePath, atomically: true, encoding: .utf8)
  }
  
  private func handleFrame(pixelBuffer: CVPixelBuffer, requests: [VNRequest], videoURL: URL, saveFrames: Bool, saveLabels: Bool) {
    let startTime = CFAbsoluteTimeGetCurrent()
    do {
      try sequenceRequestHandler.perform(requests, on: pixelBuffer)
      let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
      for request in requests {
        guard let results = request.results else { continue }
        let detectionType = request is VNCoreMLRequest ? "coreml" : "vision"
        logDetection(videoURL: videoURL, detections: results as! [VNObservation], detectionType: detectionType, elapsedTime: elapsedTime, saveFrames: saveFrames, saveLabels: saveLabels, pixelBuffer: pixelBuffer)
      }
    } catch {
      print("Error performing request: \(error.localizedDescription)")
    }
  }
}

struct OfflineVideoProcessingView: View {
  @StateObject private var videoProcessor = VideoProcessor()
  @State private var videoURL: URL?
  @State private var startTime: Double = 0.0
  @State private var duration: Double = 10.0
  @State private var requests: [VNRequest] = []
  @State private var enableObjectDetection = false
  @State private var enableFaceDetection = false
  @State private var enableHandDetection = false
  @State private var enableBodyPoseDetection = false
  @State private var enableCustomModelDetection = false
  @State private var saveFrames = false
  @State private var saveLabels = false
  
  var body: some View {
    NavigationView {
      videoGallery
      VStack {
        if let videoURL = videoURL {
          Text("Selected Video: \(videoURL.lastPathComponent)")
          
          VStack {
            HStack {
              Text("Start Time")
              TextField("Start Time", value: $startTime, formatter: NumberFormatter())
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 100)
            }
            
            HStack {
              Text("Duration")
              TextField("Duration", value: $duration, formatter: NumberFormatter())
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 100)
            }
            
            VStack {
              Toggle("Enable Object Detection", isOn: $enableObjectDetection)
              Toggle("Enable Face Detection", isOn: $enableFaceDetection)
              Toggle("Enable Hand Detection", isOn: $enableHandDetection)
              Toggle("Enable Body Pose Detection", isOn: $enableBodyPoseDetection)
              Toggle("Enable Custom Model Detection", isOn: $enableCustomModelDetection)
              Toggle("Save Frames", isOn: $saveFrames)
              Toggle("Save Labels", isOn: $saveLabels)
            }
            .padding()
            
            Button(action: {
              videoProcessor.selectCoreMLModel()
            }) {
              Text("Select Core ML Model")
            }
            
            if let modelURL = videoProcessor.selectedModelURL {
              Text("Selected Model: \(modelURL.lastPathComponent)")
            }
            
            Button(action: {
              startProcessing()
            }) {
              Text("Start Processing")
            }
            .disabled(videoProcessor.isProcessing)
            
            Button(action: {
              videoProcessor.cancelProcessing()
            }) {
              Text("Cancel Processing")
            }
            .disabled(!videoProcessor.isProcessing)
            
            Button(action: {
              videoProcessor.selectSavePath()
            }) {
              Text("Select Save Path")
            }
            
            if let savePath = videoProcessor.savePath {
              Text("Save Path: \(savePath.path)")
            }
          }
          .padding()
        }
      }
      VStack {
        Text("Status")
        List(videoProcessor.logs, id: \.id) { log in
          Text(log.message)
        }
      }
      .frame(minWidth: 300)
    }
    .padding()
  }
  
  private var videoGallery: some View {
    VStack {
      Button(action: {
        selectVideoFile()
      }) {
        Text("Add Video")
      }
      .padding()
      
      List {
        // Placeholder for video list, you can replace this with your actual video list implementation
        Text("Video 1")
        Text("Video 2")
        Text("Video 3")
      }
      .padding()
      
      Button("Clear All") {
        // Clear video list logic here
      }
      .padding()
    }
    .frame(minWidth: 200)
  }
  
  private func selectVideoFile() {
    let panel = NSOpenPanel()
    panel.allowedFileTypes = ["mp4", "mov"]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.begin { response in
      if response == .OK, let url = panel.url {
        videoURL = url
      }
    }
  }
  
  private func startProcessing() {
    guard let videoURL = videoURL else { return }
    
    let start = CMTime(seconds: startTime, preferredTimescale: 600)
    let duration = CMTime(seconds: self.duration, preferredTimescale: 600)
    let timeRange = CMTimeRange(start: start, duration: duration)
    
    requests = []
    
    if enableObjectDetection {
      requests.append(VNCoreMLRequest(model: try! VNCoreMLModel(for: cash2cashNMS().model), completionHandler: visionRequestHandler))
    }
    
    if enableFaceDetection {
      requests.append(VNDetectFaceRectanglesRequest(completionHandler: visionRequestHandler))
    }
    
    if enableHandDetection {
      requests.append(VNDetectHumanHandPoseRequest(completionHandler: visionRequestHandler))
    }
    
    if enableBodyPoseDetection {
      requests.append(VNDetectHumanBodyPoseRequest(completionHandler: visionRequestHandler))
    }
    
    if enableCustomModelDetection, let modelURL = videoProcessor.selectedModelURL {
      let compiledModelURL = try! MLModel.compileModel(at: modelURL)
      let model = try! MLModel(contentsOf: compiledModelURL)
      let visionModel = try! VNCoreMLModel(for: model)
      requests.append(VNCoreMLRequest(model: visionModel, completionHandler: visionRequestHandler))
    }
    
    videoProcessor.processVideo(url: videoURL, startTime: start, duration: duration, requests: requests, saveFrames: saveFrames, saveLabels: saveLabels)
  }
  
  private func visionRequestHandler(request: VNRequest, error: Error?) {
    if let error = error {
      print("Vision request error: \(error.localizedDescription)")
    } else {
      guard let results = request.results else { return }
      let elapsedTime = CFAbsoluteTimeGetCurrent() - (videoProcessor.startTime ?? 0)
      let detectionType = request is VNCoreMLRequest ? "coreml" : "vision"
      videoProcessor.logDetection(videoURL: videoURL!, detections: results as! [VNObservation], detectionType: detectionType, elapsedTime: elapsedTime, saveFrames: saveFrames, saveLabels: saveLabels, pixelBuffer: nil)
    }
  }
}
