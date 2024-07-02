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
  @State private var totalObjectsDetected = 0
  @State private var totalFacesDetected = 0
  @State private var totalHumansDetected = 0
  @State private var totalHandsDetected = 0
  @State private var totalBodyPosesDetected = 0
  @State private var droppedFrames = 0
  @State private var corruptedFrames = 0
  @State private var detectionFPS: Double = 0.0
  @State private var selectedSize: CGSize = CGSize(width: 1280, height: 720)
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
  whitePointAdjustFilter?.setValue(CIColor(red: CGFloat(Float(whitePoint)), green: CGFloat(Float(whitePoint)), blue: CGFloat(Float(whitePoint))), forKey: kCIInputColorKey)

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
        Text("Current Resolution: \(videoSize.width, specifier: "%.0f")x\(videoSize.height, specifier: "%.0f")")
        Text("Detection FPS: \(detectionFPS, specifier: "%.2f")")
        Text("Video FPS: \(getVideoFrameRate(), specifier: "%.2f")")
        Text("Total Objects Detected: \(totalObjectsDetected)")
        Text("Total Faces Detected: \(totalFacesDetected)")
        Text("Total Humans Detected: \(totalHumansDetected)")
        Text("Total Hands Detected: \(totalHandsDetected)")
        Text("Total Body Poses Detected: \(totalBodyPosesDetected)")
      }
      if mediaModel.selectedVideoURL != nil {
        VStack {
          VideoPlayerViewMain(player: player, detections: $detectedObjects)
            .frame(width: selectedSize.width, height: selectedSize.height)
            .background(Color.black)
            .clipped()
            .modifier(BoundingBoxModifier(observations: detectedObjects, color: .red, scale: 1.0))
            .modifier(BoundingBoxModifier(observations: detectedFaces.map { VNDetectedObjectObservation(boundingBox: $0.boundingBox) }, color: .blue, scale: 2.0))
            .modifier(BoundingBoxModifier(observations: detectedHumans.map { VNDetectedObjectObservation(boundingBox: $0.boundingBox) }, color: .green, scale: 1.0))
            .modifier(HandJointModifier(hands: detectedHands, color: .yellow))
            .modifier(BodyPoseJointModifier(bodyPoses: detectedBodyPoses, color: .purple))
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
  
  private func runModel(on pixelBuffer: CVPixelBuffer) {
    let model = try! VNCoreMLModel(for: IO_cashtrack().model)
    let request = VNCoreMLRequest(model: model) { request, error in
      let start = CFAbsoluteTimeGetCurrent()
      if let results = request.results as? [VNRecognizedObjectObservation] {
        DispatchQueue.main.async {
          self.detectedObjects = results
          self.totalObjectsDetected += results.count
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
    
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
    try? handler.perform([request])
  }
  
  private func runFaceDetection(on pixelBuffer: CVPixelBuffer) {
    let faceRequest = VNDetectFaceRectanglesRequest { request, error in
      if let results = request.results as? [VNFaceObservation] {
        DispatchQueue.main.async {
          self.detectedFaces = results
          self.totalFacesDetected += results.count
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
          self.totalHumansDetected += results.count
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
          self.totalHandsDetected += results.count
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
          self.totalBodyPosesDetected += results.count
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

struct BoundingBoxModifier: ViewModifier {
  let observations: [VNDetectedObjectObservation]
  let color: NSColor
  let scale: CGFloat
  
  func body(content: Content) -> some View {
    content.overlay(
      ForEach(observations, id: \.self) { observation in
        drawBoundingBox(for: observation, scale: scale, color: color)
      }
    )
  }
  
  private func drawBoundingBox(for observation: VNDetectedObjectObservation, scale: CGFloat, color: NSColor) -> some View {
    let boundingBox = observation.boundingBox
    let normalizedRect = CGRect(
      x: boundingBox.origin.x - boundingBox.size.width * (scale - 1) / 2,
      y: boundingBox.origin.y - boundingBox.size.height * (scale - 1) / 2,
      width: boundingBox.width * scale,
      height: boundingBox.height * scale
    )
    
    return Rectangle()
      .stroke(Color(color), lineWidth: 2)
      .frame(width: normalizedRect.width, height: normalizedRect.height)
      .position(x: normalizedRect.midX, y: normalizedRect.midY)
  }
}

struct HandJointModifier: ViewModifier {
  let hands: [VNHumanHandPoseObservation]
  let color: NSColor
  
  func body(content: Content) -> some View {
    content.overlay(
      ForEach(hands, id: \.self) { hand in
        ForEach(hand.availableJointNames, id: \.self) { jointName in
          if let point = try? hand.recognizedPoint(jointName).location {
            drawHandJoint(at: point, color: color)
          }
        }
      }
    )
  }
  
  private func drawHandJoint(at point: CGPoint, color: NSColor) -> some View {
    Circle()
      .fill(Color(color))
      .frame(width: 5, height: 5)
      .position(x: point.x, y: 1 - point.y)
  }
}

struct BodyPoseJointModifier: ViewModifier {
  let bodyPoses: [VNHumanBodyPoseObservation]
  let color: NSColor
  
  func body(content: Content) -> some View {
    content.overlay(
      ForEach(bodyPoses, id: \.self) { bodyPose in
        ForEach(bodyPose.availableJointNames, id: \.self) { jointName in
          if let point = try? bodyPose.recognizedPoint(jointName).location {
            drawBodyPoseJoint(at: point, color: color)
          }
        }
      }
    )
  }
  
  private func drawBodyPoseJoint(at point: CGPoint, color: NSColor) -> some View {
    Circle()
      .fill(Color(color))
      .frame(width: 5, height: 5)
      .position(x: point.x, y: 1 - point.y)
  }
}
import sys
import coremltools as ct
import coremltools.proto.FeatureTypes_pb2 as ft

def update_multiarray_to_float32(feature):
if feature.type.HasField("multiArrayType"):
  feature.type.multiArrayType.dataType = ft.ArrayFeatureType.FLOAT32
  if len(sys.argv) != 3:
    print("USAGE: %s <input_mlmodel> <output_mlmodel>" % sys.argv[0])
  sys.exit(1)
    input_model_path = sys.argv[1]
    output_model_path = sys.argv[2]
    spec = ct.utils.load_spec(input_model_path)
    for feature in spec.description.input:
      update_multiarray_to_float32(feature)
    for feature in spec.description.output:
      update_multiarray_to_float32(feature)
    ct.utils.save_spec(spec, output_model_path)
