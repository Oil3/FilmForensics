  //  CameraViewController.swift
  //  Machine Security System
  //
  // Copyright Almahdi Morris - 04/25/24.
import UIKit
import AVFoundation
import Vision
import CoreML

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
  private var lastInferenceTime: Date = Date(timeIntervalSince1970: 0)
  private let inferenceInterval: TimeInterval = 0.3 // Run inference every 0.3 seconds
  private var detectionOverlay: CALayer! = nil
  
  private let cameraQueue = DispatchQueue(label: "cameraQueue", qos: .default, attributes: .concurrent, autoreleaseFrequency: .workItem)
  private let captureSession = AVCaptureSession()
  private let videoDataOutput = AVCaptureVideoDataOutput()
  private var bufferSize: CGSize = .zero
  
  private var selectedVNModel: VNCoreMLModel?
  private var audioPlayer: AVAudioPlayer?
  
    // Log file URL with dynamic name based on current date and hour
  private var logFileURL: URL {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "ddMMMyyHH'h'"
    let fileName = dateFormatter.string(from: Date()) + ".txt"
    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    return documentsDirectory.appendingPathComponent(fileName)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setupCamera()
    setupDetectionOverlay()
    loadModel()
    loadSound()
    //clearLogFile() // we do not clear the log file at the start
  }
  
  func setupCamera() {
    captureSession.beginConfiguration()
    captureSession.sessionPreset = .hd1920x1080
    
    guard let captureDevice = AVCaptureDevice.default(for: .video),
          let input = try? AVCaptureDeviceInput(device: captureDevice) else {
      print("Error setting up camera input")
      captureSession.commitConfiguration()
      return
    }
    
    if captureSession.canAddInput(input) {
      captureSession.addInput(input)
    }
    
    if captureSession.canAddOutput(videoDataOutput) {
      captureSession.addOutput(videoDataOutput)
    }
    videoDataOutput.setSampleBufferDelegate(self, queue: cameraQueue)
    
    let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    previewLayer.videoGravity = .resizeAspectFill
    previewLayer.frame = view.bounds
    view.layer.addSublayer(previewLayer)
    
    captureSession.commitConfiguration()
    DispatchQueue.global(qos: .background).async {
      self.captureSession.startRunning()
    }
  }
  
  func setupDetectionOverlay() {
    detectionOverlay = CALayer()
    detectionOverlay.frame = view.bounds
    detectionOverlay.masksToBounds = true
    view.layer.addSublayer(detectionOverlay)
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if let previewLayer = view.layer.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer }) as? AVCaptureVideoPreviewLayer {
      previewLayer.frame = view.bounds
    }
    detectionOverlay.frame = view.bounds
    detectionOverlay.layoutIfNeeded()
  }
  
  func loadModel() {
    guard let modelUrl = Bundle.main.url(forResource: "yolov8x2AAA", withExtension: "mlmodelc") else {
      fatalError("Model file not found")
    }
    
    do {
      let model = try MLModel(contentsOf: modelUrl)
      selectedVNModel = try VNCoreMLModel(for: model)
    } catch {
      fatalError("Error loading model: \(error)")
    }
  }
  
  func loadSound() {
    guard let soundURL = Bundle.main.url(forResource: "detFX", withExtension: "m4a") else {
      print("Failed to find sound file.")
      return
    }
    
    do {
      audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
      audioPlayer?.prepareToPlay()
    } catch {
      print("Failed to load sound file: \(error)")
    }
  }
  
  func playSound() {
    audioPlayer?.play()
  }
  
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      print("Failed to obtain a CVPixelBuffer for the current output frame.")
      return
    }
    
    let currentTime = Date()
    guard currentTime.timeIntervalSince(lastInferenceTime) >= inferenceInterval else { return }
    lastInferenceTime = currentTime
    
    guard let model = selectedVNModel else { return }
    
    let request = VNCoreMLRequest(model: model) { (request, error) in
      if let results = request.results as? [VNRecognizedObjectObservation] {
        self.processObjectObservations(results)
      }
    }
    
    request.imageCropAndScaleOption = .scaleFill
    
    let faceRequest = VNDetectFaceRectanglesRequest { (request, error) in
      if let results = request.results as? [VNFaceObservation] {
        self.processFaceObservations(results)
      }
    }
    
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
    do {
      try handler.perform([request, faceRequest])
    } catch {
      print("Failed to perform request: \(error)")
    }
  }
  
  func processObjectObservations(_ observations: [VNRecognizedObjectObservation]) {
    DispatchQueue.main.async {
      self.detectionOverlay.sublayers?.removeAll(where: { $0.name == "objectBox" })
      
      for observation in observations {
        let boundingBox = observation.boundingBox
        let convertedRect = self.convertBoundingBox(boundingBox)
        let boundingBoxLayer = self.createBoundingBoxLayer(frame: convertedRect, color: UIColor.yellow)
        self.detectionOverlay.addSublayer(boundingBoxLayer)
        
        self.logDetection(observation)
      }
      
      if !observations.isEmpty {
        self.playSound()
      }
    }
  }
  
  func processFaceObservations(_ observations: [VNFaceObservation]) {
    DispatchQueue.main.async {
      self.detectionOverlay.sublayers?.removeAll(where: { $0.name == "faceBox" })
      
      for observation in observations {
        let boundingBox = observation.boundingBox
        let convertedRect = self.convertBoundingBox(boundingBox)
        let boundingBoxLayer = self.createBoundingBoxLayer(frame: convertedRect, color: UIColor.systemBlue)
        self.detectionOverlay.addSublayer(boundingBoxLayer)
        
        self.logFaceDetection(observation)
      }
    }
  }
  
  func convertBoundingBox(_ boundingBox: CGRect) -> CGRect {
    let width = boundingBox.width * view.bounds.width
    let height = boundingBox.height * view.bounds.height
    let x = boundingBox.origin.x * view.bounds.width
    let y = view.bounds.height - (boundingBox.origin.y * view.bounds.height + height)
    return CGRect(x: x, y: y, width: width, height: height)
  }
  
  func createBoundingBoxLayer(frame: CGRect, color: UIColor) -> CALayer {
    let layer = CALayer()
    layer.frame = frame
    layer.borderColor = color.cgColor
    layer.borderWidth = 2.0
    layer.name = color == UIColor.yellow ? "objectBox" : "faceBox"
    return layer
  }
  
  private func clearLogFile() {
    try? FileManager.default.removeItem(at: logFileURL)
  }
  private func roundedString(_ value: CGFloat) -> String {
        return String(format: "%.4f", value)
    }

  private func logDetection(_ observation: VNRecognizedObjectObservation) {
    let label = observation.labels.first?.identifier ?? "Unknown"
    let boundingBox = observation.boundingBox
  let logMessage = "\(currentDTG()) Object detected: \(label) at (x: \(roundedString(boundingBox.origin.x)), y: \(roundedString(boundingBox.origin.y)), width: \(roundedString(boundingBox.width)), height: \(roundedString(boundingBox.height)))\n"
    appendToLogFile(logMessage)
  }
  
  private func logFaceDetection(_ observation: VNFaceObservation) {
    let boundingBox = observation.boundingBox
    let logMessage = "\(currentDTG()) Face detected at (x: \(roundedString(boundingBox.origin.x)), y: \(roundedString(boundingBox.origin.y)), width: \(roundedString(boundingBox.width)), height: \(roundedString(boundingBox.height)))\n"
    appendToLogFile(logMessage)
  }
  
  private func currentDTG() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "ddMMMHHmm"
    //dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    return dateFormatter.string(from: Date())
  }
  
  private func appendToLogFile(_ message: String) {
    do {
      let data = message.data(using: .utf8)!
      if FileManager.default.fileExists(atPath: logFileURL.path) {
        let fileHandle = try FileHandle(forWritingTo: logFileURL)
        fileHandle.seekToEndOfFile()
        fileHandle.write(data)
        fileHandle.closeFile()
      } else {
        try data.write(to: logFileURL, options: .atomic)
      }
    } catch {
      print("Failed to log detection: \(error)")
    }
  }
}
