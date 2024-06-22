import SwiftUI
import AVKit
import AVFoundation
import Vision
import CoreML

struct BatchProcessingView: View {
  @State private var selectedVideoURL: URL?
  @State private var saveLabels = false
  @State private var saveFrames = false
  @State private var isProcessing = false
  @State private var savePath: URL?
  @State private var detectionLog = [DetectionLog]()
  @State private var mainVideoView = MainVideoView()
  @ObservedObject var mediaModel = MediaModel()

  var body: some View {
    VStack {
      Button("Select Video for Batch Processing") {
        openFile()
      }
      .padding()
      
      if let selectedVideoURL = selectedVideoURL {
        Text("Selected Video: \(selectedVideoURL.lastPathComponent)")
          .padding()
      }
      
      Toggle("Save Labels", isOn: $saveLabels)
      Toggle("Save Frames", isOn: $saveFrames)
        .padding()
      
      Button("Start Batch Processing") {
        if let selectedVideoURL = selectedVideoURL {
          startBatchProcessing(videoURL: selectedVideoURL)
        }
      }
      .disabled(isProcessing || selectedVideoURL == nil)
      .padding()
      
      if isProcessing {
        ProgressView("Processing...")
          .padding()
      }
      
      Spacer()
    }
    .padding()
    .onAppear {
      if let savedPath = UserDefaults.standard.url(forKey: "savePath") {
        savePath = savedPath
      }
    }
  }
  
  private func openFile() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowedFileTypes = ["mp4", "mov", "m4v"]
    
    if panel.runModal() == .OK {
      self.selectedVideoURL = panel.url
    }
  }
  
  private func startBatchProcessing(videoURL: URL) {
    guard !isProcessing else { return }
    isProcessing = true
    
    let asset = AVAsset(url: videoURL)
    let reader = try! AVAssetReader(asset: asset)
    let videoTrack = asset.tracks(withMediaType: .video).first!
    let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ])
    reader.add(readerOutput)
    reader.startReading()
    
    var frameNumber = 0
    
    DispatchQueue.global(qos: .userInitiated).async {
      while reader.status == .reading {
        if let sampleBuffer = readerOutput.copyNextSampleBuffer(),
           let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
          self.processFrame(pixelBuffer: pixelBuffer, frameNumber: frameNumber, videoURL: videoURL)
          frameNumber += 1
        }
      }
      
      if reader.status == .completed {
        print("Batch processing completed")
      } else if reader.status == .failed {
        print("Batch processing failed: \(String(describing: reader.error))")
      }
      
      DispatchQueue.main.async {
        self.isProcessing = false
      }
    }
  }
  
  private func processFrame(pixelBuffer: CVPixelBuffer, frameNumber: Int, videoURL: URL) {
    let model = try! VNCoreMLModel(for: IO_cashtrack().model)
    let request = VNCoreMLRequest(model: model) { request, error in
      if let results = request.results as? [VNRecognizedObjectObservation] {
        DispatchQueue.main.async {
          self.saveDetections(results: results, frameNumber: frameNumber, videoURL: videoURL)
        }
      }
    }
    
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
    try? handler.perform([request])
  }
  
  private func saveDetections(results: [VNRecognizedObjectObservation], frameNumber: Int, videoURL: URL) {
    guard let savePath = savePath else { return }
    
    let videoFilename = videoURL.lastPathComponent
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
    
    for detection in results {
      let boundingBox = detection.boundingBox
      labelText += "0 \(boundingBox.midX.rounded(toPlaces: 5)) \(1 - boundingBox.midY.rounded(toPlaces: 5)) \(boundingBox.width.rounded(toPlaces: 5)) \(boundingBox.height.rounded(toPlaces: 5))\n"
      let identifier = detection.labels.first?.identifier ?? "unknown"
      let confidence = detection.confidence
      detectionLog.append(Detection(boundingBox: boundingBox, identifier: identifier, confidence: confidence))
    }
    
    if !labelText.isEmpty && saveLabels {
      do {
        try labelText.write(to: labelFileName, atomically: true, encoding: .utf8)
      } catch {
        print("Error saving labels: \(error)")
      }
      
      if saveFrames {
        saveCurrentFrame(fileName: frameFileName.path)
      }
    }
    
    mainVideoView.logDetections(detections: detectionLog, frameNumber: frameNumber, folderURL: folderURL)
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
  

}
