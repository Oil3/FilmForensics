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
  @State private var imageSize: CGSize = .zero
  @State private var videoSize: CGSize = .zero
  @State private var objectDetectionEnabled = false
  @State private var faceDetectionEnabled = true // New state for face detection
  @State private var saveLabels = false
  @State private var saveFrames = false
  @State private var saveJsonLog = false
  @State private var videoOutput: AVPlayerItemVideoOutput?
  @State private var isProcessing = false
  @State private var fpsMode = false
  @State private var framePerFrameMode = false
  @State private var loopMode = false
  @State private var playBackward = false
  @State private var autoPauseOnNewDetection = false
  @State private var showBoundingBoxes = true
  @State private var savePath: URL?
  @State private var totalObjectsDetected = 0
  @State private var totalFacesDetected = 0 // New state for face detection count
  @State private var droppedFrames = 0
  @State private var corruptedFrames = 0
  @State private var detectionFPS: Double = 0.0
  @State private var selectedSize: CGSize = CGSize(width: 1280, height: 720)
  
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
              // Play/Pause toggle
              if player.timeControlStatus == .playing {
                player.pause()
              } else {
                player.play()
              }
            }) {
              Text(player.timeControlStatus == .playing ? "Pause" : "Play")
            }
            Button(action: {
              // Copy frame to clipboard
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
              // Save current frame
              if let currentPixelBuffer = mediaModel.currentPixelBuffer {
                saveCurrentFrame(fileName: getSaveURL(fileName: "current_frame.jpg").path)
              }
            }) {
              Text("Save Frame")
            }
            Button(action: {
              // Open in new window
              openInNewWindow(url: url)
            }) {
              Text("Open in New Window")
            }
            Button(action: {
              // Show in Finder
              NSWorkspace.shared.activateFileViewerSelecting([url])
            }) {
              Text("Show in Finder")
            }
            Button(action: {
              // Show results folder in Finder
              if let savePath = savePath {
                let resultsFolder = savePath.appendingPathComponent(url.lastPathComponent)
                NSWorkspace.shared.activateFileViewerSelecting([resultsFolder])
              }
            }) {
              Text("Show Results Folder in Finder")
            }
            Button(action: {
              // Delete from list
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
      }
      if mediaModel.selectedVideoURL != nil {
        VStack {
          VideoPlayerViewMain(player: player, detections: $detectedObjects)
            .frame(width: selectedSize.width, height: selectedSize.height)
            .background(Color.black)
            .clipped()
            .overlay(
              GeometryReader { geo -> AnyView in
                DispatchQueue.main.async {
                  self.videoSize = geo.size
                }
                return AnyView(
                  ForEach(detectedObjects, id: \.self) { object in
                    if showBoundingBoxes {
                      drawBoundingBox(for: object, in: geo.size, color: .red)
                    }
                  }
                )
              }
            )
            .overlay(
              GeometryReader { geo -> AnyView in
                return AnyView(
                  ForEach(detectedFaces, id: \.self) { face in
                    if showBoundingBoxes {
                      drawBoundingBox(for: face, in: geo.size, color: .blue)
                    }
                  }
                )
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
          Toggle("Enable Face Detection", isOn: $faceDetectionEnabled) // New toggle for face detection
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
          Toggle("Matrix Mode", isOn: $fpsMode)
          Toggle("Frame Per Frame Mode", isOn: $framePerFrameMode)
          Toggle("Loop", isOn: $loopMode)
          Toggle("Play Backward", isOn: $playBackward)
          Toggle("Show Bounding Boxes", isOn: $showBoundingBoxes)
        }
        HStack {
          Button("Play") {
            player.play()
            if fpsMode {
              startFPSMode()
            }
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
            stopFPSMode()
            stopFramePerFrameMode()
            stopPlayBackwardMode()
          }
        }
        .padding()
        HStack {
          Button("Load All Labels") {
            loadAllLabels()
          }
          Button("Load and Sync Labels") {
            loadAndSyncLabels()
          }
        }
        HStack {
          Button("Run Predictions") {
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
  
  private func drawBoundingBox(for observation: VNDetectedObjectObservation, in parentSize: CGSize, color: NSColor) -> some View {
    let boundingBox = observation.boundingBox
    let videoWidth = parentSize.width
    let videoHeight = parentSize.height
    let normalizedRect = CGRect(
      x: boundingBox.minX * videoWidth,
      y: (1 - boundingBox.maxY) * videoHeight,
      width: boundingBox.width * videoWidth,
      height: boundingBox.height * videoHeight
    )
    
    return Rectangle()
      .stroke(Color(color), lineWidth: 2)
      .frame(width: normalizedRect.width, height: normalizedRect.height)
      .position(x: normalizedRect.midX, y: normalizedRect.midY)
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
  
  private func processAndSaveDetections(_ detections: [VNRecognizedObjectObservation], at time: CMTime?) async {
    guard let time = time, let savePath = savePath else { return }
    
    let frameNumber = Int(CMTimeGetSeconds(time) * Double(getVideoFrameRate())) // Calculate frame number based on actual video FPS
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
    
    let frameNumber = Int(CMTimeGetSeconds(time) * Double(getVideoFrameRate())) // Calculate frame number based on actual video FPS
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
      labelText += "0 \(boundingBox.midX.rounded(toPlaces: 5)) \(1 - boundingBox.midY.rounded(toPlaces: 5)) \(boundingBox.width.rounded(toPlaces: 5)) \(boundingBox.height.rounded(toPlaces: 5))\n"
      faceLog.append(FaceDetection(boundingBox: boundingBox))
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
        }
      }
    }
  }
  
  private func beginTrimming() {
    guard playerView.canBeginTrimming else { return }
    playerView.beginTrimming { result in
      if result == .okButton {
        exportTrimmedAsset()
      } else {
        print("Trimming canceled")
      }
    }
  }
  
  private func exportTrimmedAsset() {
    guard let playerItem = player.currentItem else { return }
    let preset = AVAssetExportPresetAppleM4V720pHD
    guard let exportSession = AVAssetExportSession(asset: playerItem.asset, presetName: preset) else {
      print("Error creating export session")
      return
    }
    exportSession.outputFileType = .m4v
    let outputURL = getSaveURL(fileName: "trimmed.m4v")
    exportSession.outputURL = outputURL
    let startTime = playerItem.reversePlaybackEndTime
    let endTime = playerItem.forwardPlaybackEndTime
    let timeRange = CMTimeRangeFromTimeToTime(start: startTime, end: endTime)
    exportSession.timeRange = timeRange
    exportSession.exportAsynchronously {
      switch exportSession.status {
      case .completed:
        print("Export completed")
        DispatchQueue.main.async {
          self.mediaModel.videos.append(outputURL)
        }
      case .failed:
        print("Export failed: \(String(describing: exportSession.error))")
      default:
        print("Export status: \(exportSession.status)")
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
  
  private func loadAllLabels() {
    guard let savePath = savePath else { return }
    
    let fileManager = FileManager.default
    do {
      let fileURLs = try fileManager.contentsOfDirectory(at: savePath, includingPropertiesForKeys: nil)
      var allDetections: [VNRecognizedObjectObservation] = []
      
      for fileURL in fileURLs where fileURL.pathExtension == "txt" {
        let content = try String(contentsOf: fileURL)
        let lines = content.split(separator: "\n")
        for line in lines {
          let components = line.split(separator: " ")
          if components.count == 5, let x = Double(components[1]), let y = Double(components[2]), let width = Double(components[3]), let height = Double(components[4]) {
            let boundingBox = CGRect(x: x, y: y, width: width, height: height)
            let observation = VNRecognizedObjectObservation(boundingBox: boundingBox)
            allDetections.append(observation)
          }
        }
      }
      self.detectedObjects = allDetections
    } catch {
      print("Error loading labels: \(error)")
    }
  }
  
  private func loadAndSyncLabels() {
    guard let savePath = savePath else { return }
    
    let fileManager = FileManager.default
    do {
      let fileURLs = try fileManager.contentsOfDirectory(at: savePath, includingPropertiesForKeys: nil)
      var frameDetections: [Int: [VNRecognizedObjectObservation]] = [:]
      
      for fileURL in fileURLs where fileURL.pathExtension == "txt" {
        let frameNumber = Int(fileURL.deletingPathExtension().lastPathComponent.split(separator: "_").last ?? "") ?? 0
        let content = try String(contentsOf: fileURL)
        let lines = content.split(separator: "\n")
        var detections: [VNRecognizedObjectObservation] = []
        
        for line in lines {
          let components = line.split(separator: " ")
          if components.count == 5, let x = Double(components[1]), let y = Double(components[2]), let width = Double(components[3]), let height = Double(components[4]) {
            let boundingBox = CGRect(x: x, y: y, width: width, height: height)
            let observation = VNRecognizedObjectObservation(boundingBox: boundingBox)
            detections.append(observation)
          }
        }
        frameDetections[frameNumber] = detections
      }
      
      self.detectedObjects = []
      player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { time in
        let frameNumber = Int(CMTimeGetSeconds(time) * Double(self.getVideoFrameRate()))
        self.detectedObjects = frameDetections[frameNumber] ?? []
      }
    } catch {
      print("Error loading labels: \(error)")
    }
  }
  
  private func startFPSMode() {
    player.rate = 1.0 // Start with normal speed
    var detectionTime: Double = 1.0
    
    player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { time in
      let startTime = CFAbsoluteTimeGetCurrent()
      let endTime = CFAbsoluteTimeGetCurrent()
      detectionTime = endTime - startTime
      let newRate = 1.0 / detectionTime
      player.rate = Float(newRate)
    }
  }
  
  private func stopFPSMode() {
    player.rate = 1.0
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
  private var trackingRequests: [VNTrackObjectRequest] = []
  
  private mutating func setupObjectTracking(for observation: VNRecognizedObjectObservation) {
    let trackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
    trackingRequests.append(trackingRequest)
  }
  
  private func startObjectTracking() {
    guard !trackingRequests.isEmpty else { return }
    
    let requestHandler = VNSequenceRequestHandler()
    
    player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { time in
      guard let currentPixelBuffer = self.mediaModel.currentPixelBuffer else { return }
      
      try? requestHandler.perform(self.trackingRequests, on: currentPixelBuffer)
      
      DispatchQueue.main.async {
        for trackingRequest in self.trackingRequests {
          if let newObservation = trackingRequest.results?.first as? VNDetectedObjectObservation {
            // Update your bounding boxes or other UI elements with the newObservation
          }
        }
      }
    }
  }
}
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
