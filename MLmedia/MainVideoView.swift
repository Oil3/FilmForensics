import SwiftUI
import AVKit
import AVFoundation
import Vision
import CoreML

struct MainVideoView: View {
  @ObservedObject var mediaModel = MediaModel()
  @State private var player = AVPlayer()
  @State private var playerView = AVPlayerView()
  @State private var detectedObjects: [VNRecognizedObjectObservation] = []
  @State private var detectedFaces: [VNFaceObservation] = []
  @State private var detectedHumans: [VNHumanObservation] = []
  @State private var detectedHands: [VNHumanHandPoseObservation] = []
  @State private var detectedBodyPoses: [VNHumanBodyPoseObservation] = []
  @State private var imageSize: CGSize = .zero
  @State private var videoSize: CGSize = .zero
  @State private var objectDetectionEnabled = true
  @State private var faceDetectionEnabled = true
  @State private var humanDetectionEnabled = false
  @State private var handDetectionEnabled = false
  @State private var bodyPoseDetectionEnabled = false
  @State private var maxRequestsMode = false
  @State private var framePerFrameMode = false
  @State private var loopMode = false
  @State private var playBackward = false
  @State private var autoPauseOnNewDetection = false
  @State private var showBoundingBoxes = true
  @State private var savePath: URL?
  @State private var framesWithObjects = 0
  @State private var framesWithFaces = 0
  @State private var framesWithHumans = 0
  @State private var framesWithHands = 0
  @State private var framesWithBodyPoses = 0
  @State private var totalFrames = 0
  @State private var droppedFrames = 0
  @State private var corruptedFrames = 0
  @State private var detectionFPS: Double = 0.0
  @State private var selectedSize: CGSize = CGSize(width: 1024, height: 576)
  @State private var videoOutput: AVPlayerItemVideoOutput?
  @State private var saveJsonLog = false
  @State private var saveLabels = false
  @State private var saveFrames = false
  
  var body: some View {
    NavigationView {
      videoGallery
      videoPreview
    }
    .tabItem {
      Label("MainVideoView", systemImage: "video")
    }
    .onAppear {
      if let savedPath = UserDefaults.standard.url(forKey: "savePath") {
        if checkAccessToPath(url: savedPath) {
          savePath = savedPath
        } else {
          selectSavePath()
        }
      }
    }
  }
  
  private var videoGallery: some View {
    VStack {
      Button("Add Video") {
        mediaModel.addVideos()
      }
      .padding()
      
      List {
        ForEach(Array(mediaModel.videos.enumerated()), id: \.element) { index, url in
          Button(action: {
            mediaModel.selectedVideoURL = url
            let asset = AVAsset(url: url)
            let playerItem = AVPlayerItem(asset: asset)
            setupVideoOutput(for: playerItem)
            player.replaceCurrentItem(with: playerItem)
            playerView.player = player
            startFrameExtraction()
          }) {
            Text("\(index + 1)/\(mediaModel.videos.count) - \(url.lastPathComponent)")
          }
          .contextMenu {
            Button(action: {
              if player.timeControlStatus == .playing {
                player.pause()
              } else {
                player.play()
              }
            }) {
              Text(player.timeControlStatus == .playing ? "Pause" : "Play")
            }
            Button(action: {
              if let currentPixelBuffer = mediaModel.currentPixelBuffer {
                let ciImage = CIImage(cvPixelBuffer: currentPixelBuffer)
                let context = CIContext()
                if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                  let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: ciImage.extent.width, height: ciImage.extent.height))
                  NSPasteboard.general.clearContents()
                  NSPasteboard.general.writeObjects([nsImage])
                }
              }
            }) {
              Text("Copy Frame")
            }
            Button(action: {
              if let currentPixelBuffer = mediaModel.currentPixelBuffer {
                saveCurrentFrame(fileName: getSaveURL(fileName: "current_frame.jpg").path)
              }
            }) {
              Text("Save Frame")
            }
            Button(action: {
              openInNewWindow(url: url)
            }) {
              Text("Open in New Window")
            }
            Button(action: {
              NSWorkspace.shared.activateFileViewerSelecting([url])
            }) {
              Text("Show in Finder")
            }
            Button(action: {
              if let savePath = savePath {
                let resultsFolder = savePath.appendingPathComponent(url.lastPathComponent)
                NSWorkspace.shared.activateFileViewerSelecting([resultsFolder])
              }
            }) {
              Text("Show Results Folder in Finder")
            }
            Button(action: {
              mediaModel.videos.removeAll { $0 == url }
            }) {
              Text("Delete from List")
            }
          }
        }
        .onMove(perform: move)
      }
      .onDrop(of: ["public.file-url"], isTargeted: nil, perform: addVideoFromDrop)
      .padding()
      
      Button("Clear All") {
        mediaModel.clearVideos()
        player.replaceCurrentItem(with: nil)
      }
      .padding()
      
      HStack {
        Text("Select Placeholder Size:")
        Menu("Select Size") {
          Button("640x640") { selectedSize = CGSize(width: 640, height: 640) }
          Button("1024x576") { selectedSize = CGSize(width: 1024, height: 576) }
          Button("576x1024") { selectedSize = CGSize(width: 576, height: 1024) }
          Button("1280x720") { selectedSize = CGSize(width: 1280, height: 720) }
        }
      }
      .padding()
    }
    .frame(minWidth: 200)
  }
  
  private var videoPreview: some View {
    ScrollView {
      HStack {
        Text("File: \(mediaModel.selectedVideoURL?.lastPathComponent ?? "N/A")")
        Text("Model: IO_cashtrack.mlmodel")
      }
      HStack {
        Text("Time: \(player.currentTime().asTimeString() ?? "00:00:00")")
        Text("Frame: \(getCurrentFrameNumber())")
        Text("Total Frames: \(player.currentItem?.asset.totalNumberOfFrames ?? 0)")
        Text("Dropped Frames: \(droppedFrames)")
        Text("Corrupted Frames: \(corruptedFrames)")
      }
      HStack {
        Text("Frames with Objects: \(framesWithObjects)")
        Text("Frames with Faces: \(framesWithFaces)")
        Text("Frames with Humans: \(framesWithHumans)")
        Text("Frames with Hands: \(framesWithHands)")
        Text("Frames with Body Poses: \(framesWithBodyPoses)")
        Text("Objects Presence: \((framesWithObjects / (totalFrames + 1)))%")
        Text("Faces Presence: \((framesWithFaces / (totalFrames + 1)))%")
        Text("Humans Presence: \((framesWithHumans / (totalFrames + 1)))%")
        Text("Hands Presence: \((framesWithHands / (totalFrames + 1)))%")
//        Text("Body Poses Presence: \((framesWithBodyPoses * 100 / (totalFrames+ 1))%")
      }
      if mediaModel.selectedVideoURL != nil {
        VStack {
          VideoPlayerViewMain(player: player, detections: $detectedObjects)
            .frame(width: selectedSize.width, height: selectedSize.height)
            .background(Color.black)
            .clipped()
            .overlay(
              GeometryReader { geo in
                DispatchQueue.main.async {
                  self.videoSize = geo.size
                }
                return ZStack {
                  ForEach(detectedObjects, id: \.self) { object in
                    if showBoundingBoxes && objectDetectionEnabled {
                      drawBoundingBox(for: object, in: geo.size, color: .red)
                    }
                  }
                  ForEach(detectedFaces, id: \.self) { face in
                    if showBoundingBoxes && faceDetectionEnabled {
                      drawBoundingBox(for: face, in: geo.size, color: .blue, scale: 2.0)
                    }
                  }
                  ForEach(detectedHumans, id: \.self) { human in
                    if showBoundingBoxes && humanDetectionEnabled {
                      drawBoundingBox(for: human, in: geo.size, color: .green)
                    }
                  }
                  ForEach(detectedHands, id: \.self) { hand in
                    if showBoundingBoxes && handDetectionEnabled {
                      drawHandJoints(for: hand, in: geo.size, color: .yellow)
                    }
                  }
                  ForEach(detectedBodyPoses, id: \.self) { bodyPose in
                    if showBoundingBoxes && bodyPoseDetectionEnabled {
                      drawBodyJoints(for: bodyPose, in: geo.size, color: .purple)
                    }
                  }
                }
              }
            )
        }
      } else {
        VStack {
          Rectangle()
            .stroke(Color.gray, lineWidth: 2)
            .frame(width: selectedSize.width, height: selectedSize.height)
            .background(Color.black)
            .overlay(
              Text("Load a video to start")
                .foregroundColor(.white)
            )
            .padding()
        }
        .padding()
      }
      VStack {
        HStack {
          Toggle("Enable Object Detection", isOn: $objectDetectionEnabled)
          Toggle("Enable Face Detection", isOn: $faceDetectionEnabled)
          Toggle("Enable Human Detection", isOn: $humanDetectionEnabled)
          Toggle("Enable Hand Detection", isOn: $handDetectionEnabled)
          Toggle("Enable Body Pose Detection", isOn: $bodyPoseDetectionEnabled)
          Toggle("Save Labels", isOn: $saveLabels)
          Toggle("Save Frames", isOn: $saveFrames)
          Toggle("Save JSON Log", isOn: $saveJsonLog)
          Toggle("Auto Pause on New Detection", isOn: $autoPauseOnNewDetection)
        }
        HStack {
          Button("Select Save Path") {
            selectSavePath()
          }
          if let savePath = savePath {
            Text("Save Path: \(savePath.path)")
          }
        }
        HStack {
          Toggle("Max Requests Mode", isOn: $maxRequestsMode)
          Toggle("Frame Per Frame Mode", isOn: $framePerFrameMode)
          Toggle("Loop", isOn: $loopMode)
          Toggle("Play Backward", isOn: $playBackward)
          Toggle("Show Bounding Boxes", isOn: $showBoundingBoxes)
        }
        HStack {
          Button("Play") {
            player.play()
            if framePerFrameMode {
              startFramePerFrameMode()
            }
            if loopMode {
              player.actionAtItemEnd = .none
              NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                player.seek(to: .zero)
                player.play()
              }
            }
            if playBackward {
              startPlayBackwardMode()
            }
          }
          Button("Pause") {
            player.pause()
            stopFramePerFrameMode()
            stopPlayBackwardMode()
          }
          Button("Background Run") {
            runPredictionsWithoutPlaying()
          }
        }
      }
    }
  }
  
  private func getVideoFrameRate() -> Float {
    return player.currentItem?.asset.tracks.first?.nominalFrameRate ?? 0
  }
  
  private func getCurrentFrameNumber() -> Int {
    guard let currentItem = player.currentItem else { return 0 }
    let currentTime = currentItem.currentTime()
    let frameRate = getVideoFrameRate()
    return Int(CMTimeGetSeconds(currentTime) * Double(frameRate))
  }
  
  private func drawBoundingBox(for observation: VNDetectedObjectObservation, in parentSize: CGSize, color: NSColor, scale: CGFloat = 1.0) -> some View {
    let boundingBox = observation.boundingBox
    let videoWidth = parentSize.width
    let videoHeight = parentSize.height
    let scaledBoundingBox = CGRect(
      x: boundingBox.origin.x - (boundingBox.size.width * (scale - 1) / 2),
      y: boundingBox.origin.y - (boundingBox.size.height * (scale - 1) / 2),
      width: boundingBox.size.width * scale,
      height: boundingBox.size.height * scale
    )
    let normalizedRect = CGRect(
      x: scaledBoundingBox.minX * videoWidth,
      y: (1 - scaledBoundingBox.maxY) * videoHeight,
      width: scaledBoundingBox.width * videoWidth,
      height: scaledBoundingBox.height * videoHeight
    )
    
    return Rectangle()
      .stroke(Color(color), lineWidth: 2)
      .frame(width: normalizedRect.width, height: normalizedRect.height)
      .position(x: normalizedRect.midX, y: normalizedRect.midY)
  }
  
private func drawHandJoints(for observation: VNHumanHandPoseObservation, in parentSize: CGSize, color: NSColor) -> some View {
  let jointNames: [VNHumanHandPoseObservation.JointName] = [
    .wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
    .indexMCP, .indexPIP, .indexDIP, .indexTip,
    .middleMCP, .middlePIP, .middleDIP, .middleTip,
    .ringMCP, .ringPIP, .ringDIP, .ringTip,
    .littleMCP, .littlePIP, .littleDIP, .littleTip
  ]
  
  let points = jointNames.compactMap { try? observation.recognizedPoint($0) }
  let normalizedPoints = points.map { CGPoint(x: $0.location.x * parentSize.width, y: (1 - $0.location.y) * parentSize.height) }
  
  // Define the connections between the hand joints
  let connections: [(VNHumanHandPoseObservation.JointName, VNHumanHandPoseObservation.JointName)] = [
    (.wrist, .thumbCMC), (.thumbCMC, .thumbMP), (.thumbMP, .thumbIP), (.thumbIP, .thumbTip),
    (.wrist, .indexMCP), (.indexMCP, .indexPIP), (.indexPIP, .indexDIP), (.indexDIP, .indexTip),
    (.wrist, .middleMCP), (.middleMCP, .middlePIP), (.middlePIP, .middleDIP), (.middleDIP, .middleTip),
    (.wrist, .ringMCP), (.ringMCP, .ringPIP), (.ringPIP, .ringDIP), (.ringDIP, .ringTip),
    (.wrist, .littleMCP), (.littleMCP, .littlePIP), (.littlePIP, .littleDIP), (.littleDIP, .littleTip)
  ]
  
  let connectionsPoints: [(CGPoint, CGPoint)] = connections.compactMap { connection in
    guard let startPoint = try? observation.recognizedPoint(connection.0),
          let endPoint = try? observation.recognizedPoint(connection.1),
          startPoint.confidence > 0.1, endPoint.confidence > 0.1 else { return nil }
    return (CGPoint(x: startPoint.location.x * parentSize.width, y: (1 - startPoint.location.y) * parentSize.height),
            CGPoint(x: endPoint.location.x * parentSize.width, y: (1 - endPoint.location.y) * parentSize.height))
  }
  
  return ZStack {
    // Draw lines
    ForEach(Array(connectionsPoints.enumerated()), id: \.offset) { _, connection in
      Line(start: connection.0, end: connection.1)
        .stroke(Color(color), lineWidth: 2)
    }
    
    // Draw points
    ForEach(Array(normalizedPoints.enumerated()), id: \.offset) { _, point in
      Circle()
        .fill(Color(color))
        .frame(width: 5, height: 5)
        .position(point)
    }
  }
}


private func drawBodyJoints(for observation: VNHumanBodyPoseObservation, in parentSize: CGSize, color: NSColor) -> some View {
  let jointNames: [VNHumanBodyPoseObservation.JointName] = [
    .neck, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
    .leftWrist, .rightWrist, .root, .leftHip, .rightHip,
    .leftKnee, .rightKnee, .leftAnkle, .rightAnkle,
    .leftEar, .leftEye, .rightEar, .rightEye, .nose
  ]
  
  let points = jointNames.compactMap { try? observation.recognizedPoint($0) }
  let normalizedPoints = points.map { CGPoint(x: $0.location.x * parentSize.width, y: (1 - $0.location.y) * parentSize.height) }
  
  // Define the connections between the joints
  let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
    (.neck, .leftShoulder), (.neck, .rightShoulder),
    (.leftShoulder, .leftElbow), (.rightShoulder, .rightElbow),
    (.leftElbow, .leftWrist), (.rightElbow, .rightWrist),
    (.neck, .root),
    (.root, .leftHip), (.root, .rightHip),
    (.leftHip, .leftKnee), (.rightHip, .rightKnee),
    (.leftKnee, .leftAnkle), (.rightKnee, .rightAnkle),
    (.neck, .nose),
    (.nose, .leftEye), (.nose, .rightEye),
    (.leftEye, .leftEar), (.rightEye, .rightEar)
  ]
  
  let connectionsPoints: [(CGPoint, CGPoint)] = connections.compactMap { connection in
    guard let startPoint = try? observation.recognizedPoint(connection.0),
          let endPoint = try? observation.recognizedPoint(connection.1),
          startPoint.confidence > 0.1, endPoint.confidence > 0.1 else { return nil }
    return (CGPoint(x: startPoint.location.x * parentSize.width, y: (1 - startPoint.location.y) * parentSize.height),
            CGPoint(x: endPoint.location.x * parentSize.width, y: (1 - endPoint.location.y) * parentSize.height))
  }
  
  return ZStack {
    // Draw lines
    ForEach(Array(connectionsPoints.enumerated()), id: \.offset) { _, connection in
      Line(start: connection.0, end: connection.1)
        .stroke(Color(color), lineWidth: 2)
    }
    
    // Draw points
    ForEach(Array(normalizedPoints.enumerated()), id: \.offset) { _, point in
      Circle()
        .fill(Color(color))
        .frame(width: 5, height: 5)
        .position(point)
    }
  }
}

  private func runModel(on pixelBuffer: CVPixelBuffer) {
    let model = try! VNCoreMLModel(for: custom2().model)
    let request = VNCoreMLRequest(model: model) { request, error in
      let start = CFAbsoluteTimeGetCurrent()
      if let results = request.results as? [VNRecognizedObjectObservation] {
        DispatchQueue.main.async {
          self.detectedObjects = results
          if !results.isEmpty { self.framesWithObjects += 1 }
          if saveLabels || saveFrames {
            Task {
              await processAndSaveDetections(results, at: player.currentItem?.currentTime())
            }
          }
          if autoPauseOnNewDetection && !results.isEmpty {
            player.pause()
          }
          let end = CFAbsoluteTimeGetCurrent()
          self.detectionFPS = 1.0 / (end - start)
        }
      }
    }
    request.imageCropAndScaleOption = .scaleFill
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
    try? handler.perform([request])
  }
  
  private func runFaceDetection(on pixelBuffer: CVPixelBuffer) {
    let faceRequest = VNDetectFaceRectanglesRequest { request, error in
      if let results = request.results as? [VNFaceObservation] {
        DispatchQueue.main.async {
          self.detectedFaces = results
          if !results.isEmpty { self.framesWithFaces += 1 }
          if saveLabels || saveFrames {
            Task {
              await processAndSaveFaces(results, at: player.currentItem?.currentTime())
            }
          }
        }
      }
    }

    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
    try? handler.perform([faceRequest])
  }
  
  private func runHumanDetection(on pixelBuffer: CVPixelBuffer) {
    let humanRequest = VNDetectHumanRectanglesRequest { request, error in
      if let results = request.results as? [VNHumanObservation] {
        DispatchQueue.main.async {
          self.detectedHumans = results
          if !results.isEmpty { self.framesWithHumans += 1 }
          if saveLabels || saveFrames {
            Task {
              await processAndSaveHumans(results, at: player.currentItem?.currentTime())
            }
          }
        }
      }
    }
    
    humanRequest.upperBodyOnly = true
    
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
    try? handler.perform([humanRequest])
  }
  
  private func runHandDetection(on pixelBuffer: CVPixelBuffer) {
    let handRequest = VNDetectHumanHandPoseRequest { request, error in
      if let results = request.results as? [VNHumanHandPoseObservation] {
        DispatchQueue.main.async {
          self.detectedHands = results
          if !results.isEmpty { self.framesWithHands += 1 }
          if saveLabels || saveFrames {
            Task {
              await processAndSaveHands(results, at: player.currentItem?.currentTime())
            }
          }
        }
      }
    }
    
    handRequest.maximumHandCount = handDetectionEnabled ? 10 : 0
    
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
    try? handler.perform([handRequest])
  }
  
  private func runBodyPoseDetection(on pixelBuffer: CVPixelBuffer) {
    let bodyPoseRequest = VNDetectHumanBodyPoseRequest { request, error in
      if let results = request.results as? [VNHumanBodyPoseObservation] {
        DispatchQueue.main.async {
          self.detectedBodyPoses = results
          if !results.isEmpty { self.framesWithBodyPoses += 1 }
          if saveLabels || saveFrames {
            Task {
              await processAndSaveBodyPoses(results, at: player.currentItem?.currentTime())
            }
          }
        }
      }
    }
    
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
    try? handler.perform([bodyPoseRequest])
  }
  
  private func processAndSaveDetections(_ detections: [VNRecognizedObjectObservation], at time: CMTime?) async {
    guard let time = time, let savePath = savePath else { return }
    
    let frameNumber = Int(CMTimeGetSeconds(time) * Double(getVideoFrameRate()))
    let videoFilename = mediaModel.selectedVideoURL?.lastPathComponent ?? "video"
    let folderName = "\(videoFilename)"
    let folderURL = savePath.appendingPathComponent(folderName)
    let labelsFolderURL = folderURL.appendingPathComponent("labels")
    let imagesFolderURL = folderURL.appendingPathComponent("images")
    
    createFolderIfNotExists(at: folderURL)
    createFolderIfNotExists(at: labelsFolderURL)
    createFolderIfNotExists(at: imagesFolderURL)
    
    let labelFileName = labelsFolderURL.appendingPathComponent("\(videoFilename)_\(frameNumber).txt")
    let frameFileName = imagesFolderURL.appendingPathComponent("\(videoFilename)_\(frameNumber).jpg")
    
    var labelText = ""
    var detectionLog = [Detection]()
    
    for detection in detections {
      let boundingBox = detection.boundingBox
      labelText += "0 \(boundingBox.midX.rounded(toPlaces: 5)) \(1 - boundingBox.midY.rounded(toPlaces: 5)) \(boundingBox.width.rounded(toPlaces: 5)) \(boundingBox.height.rounded(toPlaces: 5))\n"
      let identifier = detection.labels.first?.identifier ?? "unknown"
      let confidence = detection.confidence
      detectionLog.append(Detection(boundingBox: boundingBox, identifier: identifier, confidence: confidence))
    }
    
    if !labelText.isEmpty {
      do {
        try labelText.write(to: labelFileName, atomically: true, encoding: .utf8)
      } catch {
        print("Error saving labels: \(error)")
      }
      
      if saveFrames {
        saveCurrentFrame(fileName: frameFileName.path)
      }
    }
    
    if saveJsonLog {
      logDetections(detections: detectionLog, frameNumber: frameNumber, folderURL: folderURL)
    }
  }
  
  private func processAndSaveFaces(_ faces: [VNFaceObservation], at time: CMTime?) async {
    guard let time = time, let savePath = savePath else { return }
    
    let frameNumber = Int(CMTimeGetSeconds(time) * Double(getVideoFrameRate()))
    let videoFilename = mediaModel.selectedVideoURL?.lastPathComponent ?? "video"
    let folderName = "\(videoFilename)"
    let folderURL = savePath.appendingPathComponent(folderName)
    let labelsFolderURL = folderURL.appendingPathComponent("labels_faces")
    let imagesFolderURL = folderURL.appendingPathComponent("images_faces")
    
    createFolderIfNotExists(at: folderURL)
    createFolderIfNotExists(at: labelsFolderURL)
    createFolderIfNotExists(at: imagesFolderURL)
    
    let labelFileName = labelsFolderURL.appendingPathComponent("\(videoFilename)_\(frameNumber).txt")
    let frameFileName = imagesFolderURL.appendingPathComponent("\(videoFilename)_\(frameNumber).jpg")
    
    var labelText = ""
    var faceLog = [FaceDetection]()
    
    for face in faces {
      let boundingBox = face.boundingBox
      let scaledBoundingBox = CGRect(
        x: boundingBox.origin.x - boundingBox.size.width / 2,
        y: boundingBox.origin.y - boundingBox.size.height / 2,
        width: boundingBox.size.width * 2,
        height: boundingBox.size.height * 2
      )
      labelText += "0 \(scaledBoundingBox.midX.rounded(toPlaces: 5)) \(1 - scaledBoundingBox.midY.rounded(toPlaces: 5)) \(scaledBoundingBox.width.rounded(toPlaces: 5)) \(scaledBoundingBox.height.rounded(toPlaces: 5))\n"
      faceLog.append(FaceDetection(boundingBox: scaledBoundingBox))
    }
    
    if !labelText.isEmpty {
      do {
        try labelText.write(to: labelFileName, atomically: true, encoding: .utf8)
      } catch {
        print("Error saving labels: \(error)")
      }
      
      if saveFrames {
        saveCurrentFrame(fileName: frameFileName.path)
      }
    }
    
    if saveJsonLog {
      logFaceDetections(detections: faceLog, frameNumber: frameNumber, folderURL: folderURL)
    }
  }
  
  private func processAndSaveHumans(_ humans: [VNHumanObservation], at time: CMTime?) async {
    guard let time = time, let savePath = savePath else { return }
    
    let frameNumber = Int(CMTimeGetSeconds(time) * Double(getVideoFrameRate()))
    let videoFilename = mediaModel.selectedVideoURL?.lastPathComponent ?? "video"
    let folderName = "\(videoFilename)"
    let folderURL = savePath.appendingPathComponent(folderName)
    let labelsFolderURL = folderURL.appendingPathComponent("labels_humans")
    let imagesFolderURL = folderURL.appendingPathComponent("images_humans")
    
    createFolderIfNotExists(at: folderURL)
    createFolderIfNotExists(at: labelsFolderURL)
    createFolderIfNotExists(at: imagesFolderURL)
    
    let labelFileName = labelsFolderURL.appendingPathComponent("\(videoFilename)_\(frameNumber).txt")
    let frameFileName = imagesFolderURL.appendingPathComponent("\(videoFilename)_\(frameNumber).jpg")
    
    var labelText = ""
    var humanLog = [HumanDetection]()
    
    for human in humans {
      let boundingBox = human.boundingBox
      labelText += "0 \(boundingBox.midX.rounded(toPlaces: 5)) \(1 - boundingBox.midY.rounded(toPlaces: 5)) \(boundingBox.width.rounded(toPlaces: 5)) \(boundingBox.height.rounded(toPlaces: 5))\n"
      humanLog.append(HumanDetection(boundingBox: boundingBox))
    }
    
    if !labelText.isEmpty {
      do {
        try labelText.write(to: labelFileName, atomically: true, encoding: .utf8)
      } catch {
        print("Error saving labels: \(error)")
      }
      
      if saveFrames {
        saveCurrentFrame(fileName: frameFileName.path)
      }
    }
    
    if saveJsonLog {
      logHumanDetections(detections: humanLog, frameNumber: frameNumber, folderURL: folderURL)
    }
  }
  
  private func processAndSaveHands(_ hands: [VNHumanHandPoseObservation], at time: CMTime?) async {
    guard let time = time, let savePath = savePath else { return }
    
    let frameNumber = Int(CMTimeGetSeconds(time) * Double(getVideoFrameRate()))
    let videoFilename = mediaModel.selectedVideoURL?.lastPathComponent ?? "video"
    let folderName = "\(videoFilename)"
    let folderURL = savePath.appendingPathComponent(folderName)
    let labelsFolderURL = folderURL.appendingPathComponent("labels_hands")
    let imagesFolderURL = folderURL.appendingPathComponent("images_hands")
    
    createFolderIfNotExists(at: folderURL)
    createFolderIfNotExists(at: labelsFolderURL)
    createFolderIfNotExists(at: imagesFolderURL)
    
    let labelFileName = labelsFolderURL.appendingPathComponent("\(videoFilename)_\(frameNumber).txt")
    let frameFileName = imagesFolderURL.appendingPathComponent("\(videoFilename)_\(frameNumber).jpg")
    
    var labelText = ""
    var handLog = [HandDetection]()
    
    for hand in hands {
      for jointName in hand.availableJointNames {
        if let point = try? hand.recognizedPoint(jointName).location {
          labelText += "\(jointName) \(point.x.rounded(toPlaces: 5)) \(1 - point.y.rounded(toPlaces: 5))\n"
          handLog.append(HandDetection(location: point))
        }
      }
    }
    
    if !labelText.isEmpty {
      do {
        try labelText.write(to: labelFileName, atomically: true, encoding: .utf8)
      } catch {
        print("Error saving labels: \(error)")
      }
      
      if saveFrames {
        saveCurrentFrame(fileName: frameFileName.path)
      }
    }
    
    if saveJsonLog {
      logHandDetections(detections: handLog, frameNumber: frameNumber, folderURL: folderURL)
    }
  }
  
  private func processAndSaveBodyPoses(_ bodyPoses: [VNHumanBodyPoseObservation], at time: CMTime?) async {
    guard let time = time, let savePath = savePath else { return }
    
    let frameNumber = Int(CMTimeGetSeconds(time) * Double(getVideoFrameRate()))
    let videoFilename = mediaModel.selectedVideoURL?.lastPathComponent ?? "video"
    let folderName = "\(videoFilename)"
    let folderURL = savePath.appendingPathComponent(folderName)
    let labelsFolderURL = folderURL.appendingPathComponent("labels_body_poses")
    let imagesFolderURL = folderURL.appendingPathComponent("images_body_poses")
    
    createFolderIfNotExists(at: folderURL)
    createFolderIfNotExists(at: labelsFolderURL)
    createFolderIfNotExists(at: imagesFolderURL)
    
    let labelFileName = labelsFolderURL.appendingPathComponent("\(videoFilename)_\(frameNumber).txt")
    let frameFileName = imagesFolderURL.appendingPathComponent("\(videoFilename)_\(frameNumber).jpg")
    
    var labelText = ""
    var bodyPoseLog = [BodyPoseDetection]()
    
    for bodyPose in bodyPoses {
      for jointName in bodyPose.availableJointNames {
        if let point = try? bodyPose.recognizedPoint(jointName).location {
          labelText += "\(jointName) \(point.x.rounded(toPlaces: 5)) \(1 - point.y.rounded(toPlaces: 5))\n"
          bodyPoseLog.append(BodyPoseDetection(location: point))
        }
      }
    }
    
    if !labelText.isEmpty {
      do {
        try labelText.write(to: labelFileName, atomically: true, encoding: .utf8)
      } catch {
        print("Error saving labels: \(error)")
      }
      
      if saveFrames {
        saveCurrentFrame(fileName: frameFileName.path)
      }
    }
    
    if saveJsonLog {
      logBodyPoseDetections(detections: bodyPoseLog, frameNumber: frameNumber, folderURL: folderURL)
    }
  }
  
  private func saveCurrentFrame(fileName: String) {
    guard let pixelBuffer = mediaModel.currentPixelBuffer else { return }
    
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let context = CIContext()
    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
    let nsImage = NSImage(cgImage: cgImage, size: .zero)
    
    guard let tiffData = nsImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let jpegData = bitmap.representation(using: .jpeg, properties: [:]) else { return }
    
    do {
      try jpegData.write(to: URL(fileURLWithPath: fileName))
    } catch {
      print("Error saving frame: \(error)")
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
      if let videoOutput = self.videoOutput,
         videoOutput.hasNewPixelBuffer(forItemTime: time) {
        var presentationTime = CMTime()
        if let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: &presentationTime) {
          mediaModel.currentFrame = pixelBuffer
          mediaModel.currentPixelBuffer = pixelBuffer
          if objectDetectionEnabled {
            runModel(on: pixelBuffer)
          }
          if faceDetectionEnabled {
            runFaceDetection(on: pixelBuffer)
          }
          if humanDetectionEnabled {
            runHumanDetection(on: pixelBuffer)
          }
          if handDetectionEnabled {
            runHandDetection(on: pixelBuffer)
          }
          if bodyPoseDetectionEnabled {
            runBodyPoseDetection(on: pixelBuffer)
          }
        }
      }
    }
  }
  
  private func getSaveURL(fileName: String) -> URL {
    let savePanel = NSSavePanel()
    savePanel.nameFieldStringValue = fileName
    savePanel.canCreateDirectories = true
    savePanel.allowedContentTypes = [.movie]
    if savePanel.runModal() == .OK {
      return savePanel.url ?? URL(fileURLWithPath: "/dev/null")
    }
    return URL(fileURLWithPath: "/dev/null")
  }
  
  private func selectSavePath() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    if panel.runModal() == .OK {
      savePath = panel.url
      UserDefaults.standard.set(savePath, forKey: "savePath")
    }
  }
  
  private func createFolderIfNotExists(at url: URL) {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: url.path) {
      do {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
      } catch {
        print("Error creating folder: \(error)")
      }
    }
  }
  
  private func logDetections(detections: [Detection], frameNumber: Int, folderURL: URL) {
    let logFileName = folderURL.appendingPathComponent("log_\(mediaModel.selectedVideoURL?.lastPathComponent ?? "video").json")
    
    var log = DetectionLog(videoURL: mediaModel.selectedVideoURL?.absoluteString ?? "", creationDate: Date().description, frames: [])
    
    if let data = try? Data(contentsOf: logFileName), let existingLog = try? JSONDecoder().decode(DetectionLog.self, from: data) {
      log = existingLog
    }
    
    let frameLog = FrameLog(frameNumber: frameNumber, detections: detections.isEmpty ? nil : detections)
    log.frames.append(frameLog)
    
    do {
      let data = try JSONEncoder().encode(log)
      try data.write(to: logFileName)
    } catch {
      print("Error saving log: \(error)")
    }
  }
  
  private func logFaceDetections(detections: [FaceDetection], frameNumber: Int, folderURL: URL) {
    let logFileName = folderURL.appendingPathComponent("log_faces_\(mediaModel.selectedVideoURL?.lastPathComponent ?? "video").json")
    
    var log = FaceDetectionLog(videoURL: mediaModel.selectedVideoURL?.absoluteString ?? "", creationDate: Date().description, frames: [])
    
    if let data = try? Data(contentsOf: logFileName), let existingLog = try? JSONDecoder().decode(FaceDetectionLog.self, from: data) {
      log = existingLog
    }
    
    let frameLog = FaceFrameLog(frameNumber: frameNumber, detections: detections.isEmpty ? nil : detections)
    log.frames.append(frameLog)
    
    do {
      let data = try JSONEncoder().encode(log)
      try data.write(to: logFileName)
    } catch {
      print("Error saving log: \(error)")
    }
  }
  
  private func logHumanDetections(detections: [HumanDetection], frameNumber: Int, folderURL: URL) {
    let logFileName = folderURL.appendingPathComponent("log_humans_\(mediaModel.selectedVideoURL?.lastPathComponent ?? "video").json")
    
    var log = HumanDetectionLog(videoURL: mediaModel.selectedVideoURL?.absoluteString ?? "", creationDate: Date().description, frames: [])
    
    if let data = try? Data(contentsOf: logFileName), let existingLog = try? JSONDecoder().decode(HumanDetectionLog.self, from: data) {
      log = existingLog
    }
    
    let frameLog = HumanFrameLog(frameNumber: frameNumber, detections: detections.isEmpty ? nil : detections)
    log.frames.append(frameLog)
    
    do {
      let data = try JSONEncoder().encode(log)
      try data.write(to: logFileName)
    } catch {
      print("Error saving log: \(error)")
    }
  }
  
  private func logHandDetections(detections: [HandDetection], frameNumber: Int, folderURL: URL) {
    let logFileName = folderURL.appendingPathComponent("log_hands_\(mediaModel.selectedVideoURL?.lastPathComponent ?? "video").json")
    
    var log = HandDetectionLog(videoURL: mediaModel.selectedVideoURL?.absoluteString ?? "", creationDate: Date().description, frames: [])
    
    if let data = try? Data(contentsOf: logFileName), let existingLog = try? JSONDecoder().decode(HandDetectionLog.self, from: data) {
      log = existingLog
    }
    
    let frameLog = HandFrameLog(frameNumber: frameNumber, detections: detections.isEmpty ? nil : detections)
    log.frames.append(frameLog)
    
    do {
      let data = try JSONEncoder().encode(log)
      try data.write(to: logFileName)
    } catch {
      print("Error saving log: \(error)")
    }
  }
  
  private func logBodyPoseDetections(detections: [BodyPoseDetection], frameNumber: Int, folderURL: URL) {
    let logFileName = folderURL.appendingPathComponent("log_body_poses_\(mediaModel.selectedVideoURL?.lastPathComponent ?? "video").json")
    
    var log = BodyPoseDetectionLog(videoURL: mediaModel.selectedVideoURL?.absoluteString ?? "", creationDate: Date().description, frames: [])
    
    if let data = try? Data(contentsOf: logFileName), let existingLog = try? JSONDecoder().decode(BodyPoseDetectionLog.self, from: data) {
      log = existingLog
    }
    
    let frameLog = BodyPoseFrameLog(frameNumber: frameNumber, detections: detections.isEmpty ? nil : detections)
    log.frames.append(frameLog)
    
    do {
      let data = try JSONEncoder().encode(log)
      try data.write(to: logFileName)
    } catch {
      print("Error saving log: \(error)")
    }
  }
  
  private func startFramePerFrameMode() {
    player.rate = 1.0 / Float(player.currentItem?.tracks.first?.currentVideoFrameRate ?? 1.0)
  }
  
  private func stopFramePerFrameMode() {
    player.rate = 1.0
  }
  
  private func startPlayBackwardMode() {
    player.rate = -1.0
  }
  
  private func stopPlayBackwardMode() {
    player.rate = 1.0
  }
  
  private func runPredictionsWithoutPlaying() {
    guard let playerItem = player.currentItem else { return }
    let duration = playerItem.duration
    let frameRate = getVideoFrameRate()
    let totalFrames = Int(CMTimeGetSeconds(duration) * Double(frameRate))
    
    var currentFrame = 0
    var currentTime = CMTime.zero
    
    while currentFrame < totalFrames {
      let interval = CMTime(value: 1, timescale: Int32(frameRate))
      currentTime = CMTimeMultiplyByFloat64(interval, multiplier: Float64(currentFrame))
      
      if let videoOutput = videoOutput, videoOutput.hasNewPixelBuffer(forItemTime: currentTime) {
        var presentationTime = CMTime()
        if let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: &presentationTime) {
          runModel(on: pixelBuffer)
          if faceDetectionEnabled {
            runFaceDetection(on: pixelBuffer)
          }
          if humanDetectionEnabled {
            runHumanDetection(on: pixelBuffer)
          }
          if handDetectionEnabled {
            runHandDetection(on: pixelBuffer)
          }
          if bodyPoseDetectionEnabled {
            runBodyPoseDetection(on: pixelBuffer)
          }
        }
      }
      
      currentFrame += 1
    }
  }
  
  private func checkAccessToPath(url: URL) -> Bool {
    var bookmarkDataIsStale: Bool = false
    do {
      _ = try URL(resolvingBookmarkData: url.bookmarkData(), options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &bookmarkDataIsStale)
      return !bookmarkDataIsStale
    } catch {
      return false
    }
  }
  
  private func move(from source: IndexSet, to destination: Int) {
    mediaModel.videos.move(fromOffsets: source, toOffset: destination)
  }
  
  private func addVideoFromDrop(providers: [NSItemProvider]) -> Bool {
    for provider in providers {
      if provider.hasItemConformingToTypeIdentifier("public.file-url") {
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, error) in
          guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
          DispatchQueue.main.async {
            self.mediaModel.videos.append(url)
          }
        }
        return true
      }
    }
    return false
  }
  
  private func openInNewWindow(url: URL) {
    let newWindow = NSWindow(
      contentRect: NSMakeRect(0, 0, 800, 600),
      styleMask: [.titled, .closable, .resizable, .miniaturizable],
      backing: .buffered, defer: false)
    newWindow.title = "Video Player"
    let newWindowController = NSWindowController(window: newWindow)
    newWindowController.showWindow(self)
    
    let mainVideoView = MainVideoView()
    let contentView = NSHostingView(rootView: mainVideoView)
    newWindow.contentView = contentView
    
    mainVideoView.mediaModel.videos = [url]
    mainVideoView.mediaModel.selectedVideoURL = url
    let asset = AVAsset(url: url)
    let playerItem = AVPlayerItem(asset: asset)
    mainVideoView.setupVideoOutput(for: playerItem)
    mainVideoView.player.replaceCurrentItem(with: playerItem)
    mainVideoView.playerView.player = mainVideoView.player
    mainVideoView.startFrameExtraction()
  }
}
