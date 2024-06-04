//
//  CoreMLProcessor.swift
//  V
//
//  Created by Almahdi Morris on 4/6/24.
//
import SwiftUI
import CoreML
import Vision
import AVFoundation

class CoreMLProcessor: NSObject, ObservableObject {
    @Published var selectedModelName: String = "ccashier3"
    @Published var modelList: [String] = ["ccashier3", "ccontrol4", "cctrack23090"]
    @Published var logs: [String] = []
    @Published var detailedLogs: [String] = []
    @Published var currentFileLog: [String] = []
    @Published var generalLog: [String] = []
    @Published var stats: String = ""
    @Published var currentObservations: [VNRecognizedObjectObservation] = []
    
    var isProcessing = false
    var framesProcessed = 0
    var totalFrames = 0
    var fileSelectionCompletionHandler: (([URL]) -> Void)?

    func selectModel(named modelName: String) {
        selectedModelName = modelName
    }

    func selectFiles(completion: @escaping ([URL]) -> Void) {
        fileSelectionCompletionHandler = completion
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.movie, .image], asCopy: true)
        documentPicker.allowsMultipleSelection = true
        documentPicker.delegate = self
        guard let window = UIApplication.shared.windows.first else { return }
        window.rootViewController?.present(documentPicker, animated: true, completion: nil)
    }

    func startProcessing(urls: [URL], confidenceThreshold: Float, iouThreshold: Float, noVideoPlayback: Bool) {
        guard let model = loadModel(named: selectedModelName) else { 
            print("Failed to load model: \(selectedModelName)")
            return 
        }

        isProcessing = true
        DispatchQueue.global(qos: .userInitiated).async {
            for url in urls {
                if !self.isProcessing { break }
                if url.pathExtension.lowercased() == "mp4" || url.pathExtension.lowercased() == "mov" {
                    self.processVideo(url: url, model: model, confidenceThreshold: confidenceThreshold, iouThreshold: iouThreshold, noVideoPlayback: noVideoPlayback)
                } else {
                    self.processImage(url: url, model: model, confidenceThreshold: confidenceThreshold, iouThreshold: iouThreshold)
                }
            }

            self.isProcessing = false
            self.generateGeneralLog()
        }
    }

    func stopProcessing() {
        isProcessing = false
    }

    private func loadModel(named modelName: String) -> MLModel? {
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else { 
            print("Model not found: \(modelName)")
            return nil 
        }
        do {
            return try MLModel(contentsOf: modelURL)
        } catch {
            print("Error loading model: \(error)")
            return nil
        }
    }

    private func processVideo(url: URL, model: MLModel, confidenceThreshold: Float, iouThreshold: Float, noVideoPlayback: Bool) {
        print("Processing video: \(url)")
        let asset = AVAsset(url: url)
        let reader = try! AVAssetReader(asset: asset)
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else { return }
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        reader.add(readerOutput)
        reader.startReading()
        
        self.totalFrames = Int(videoTrack.nominalFrameRate) * Int(CMTimeGetSeconds(asset.duration))
        self.framesProcessed = 0
        
        while let sampleBuffer = readerOutput.copyNextSampleBuffer(), reader.status == .reading {
            if !isProcessing { break }
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            let request = VNCoreMLRequest(model: try! VNCoreMLModel(for: model)) { [weak self] request, error in
                if let results = request.results as? [VNRecognizedObjectObservation] {
                    self?.currentObservations = results
                    for observation in results {
                        if observation.confidence >= confidenceThreshold {
                            let logEntry = "Detected object with confidence \(observation.confidence) at time \(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))) in video \(url.lastPathComponent)"
                            self?.detailedLogs.append(logEntry)
                            self?.currentFileLog.append(logEntry)
                        }
                    }
                }
            }

            try? handler.perform([request])
            self.framesProcessed += 1
            self.updateStats()
        }
        reader.cancelReading()

        generateLog(for: url)
    }

    private func processImage(url: URL, model: MLModel, confidenceThreshold: Float, iouThreshold: Float) {
        print("Processing image: \(url)")
        guard let image = CIImage(contentsOf: url) else { return }
        let handler = VNImageRequestHandler(ciImage: image, options: [:])

        var request: VNCoreMLRequest
        if selectedModelName == "ccashier3" {
            request = VNCoreMLRequest(model: try! VNCoreMLModel(for: model)) { [weak self] request, error in
                if let results = request.results as? [VNRecognizedObjectObservation] {
                    self?.currentObservations = results
                    for observation in results {
                        if observation.confidence >= confidenceThreshold {
                            let logEntry = "Detected object with confidence \(observation.confidence) in image \(url.lastPathComponent)"
                            self?.detailedLogs.append(logEntry)
                            self?.currentFileLog.append(logEntry)
                        }
                    }
                }
            }
        } else {
            // Handle specific input names and resizing
            var targetSize: CGSize
            if selectedModelName == "cctrack23090" {
                targetSize = CGSize(width: 416, height: 416)
            } else {
                targetSize = CGSize(width: 704, height: 416)
            }
            let resizedImage = resizeImage(image: image, targetSize: targetSize)
            let handler = VNImageRequestHandler(ciImage: resizedImage, options: [:])
            request = VNCoreMLRequest(model: try! VNCoreMLModel(for: model)) { [weak self] request, error in
                if let results = request.results as? [VNRecognizedObjectObservation] {
                    self?.currentObservations = results
                    for observation in results {
                        if observation.confidence >= confidenceThreshold {
                            let logEntry = "Detected object with confidence \(observation.confidence) in image \(url.lastPathComponent)"
                            self?.detailedLogs.append(logEntry)
                            self?.currentFileLog.append(logEntry)
                        }
                    }
                }
            }
        }
        
        try? handler.perform([request])
        generateLog(for: url)
    }
    
    private func resizeImage(image: CIImage, targetSize: CGSize) -> CIImage {
        let scale = CGAffineTransform(scaleX: targetSize.width / image.extent.width, y: targetSize.height / image.extent.height)
        return image.transformed(by: scale)
    }

    private func generateLog(for url: URL) {
        let logFilename = url.deletingPathExtension().lastPathComponent + "_log.txt"
        let logFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(logFilename)

        do {
            let logText = currentFileLog.joined(separator: "\n")
            try logText.write(to: logFileURL, atomically: true, encoding: .utf8)
            logs.append(logFileURL.path)
            currentFileLog.removeAll()
        } catch {
            print("Error writing log: \(error)")
        }
    }

    private func generateGeneralLog() {
        let generalLogFilename = "general_log.txt"
        let generalLogFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(generalLogFilename)

        do {
            let logText = detailedLogs.joined(separator: "\n")
            try logText.write(to: generalLogFileURL, atomically: true, encoding: .utf8)
            generalLog.append(generalLogFileURL.path)
            detailedLogs.removeAll()
        } catch {
            print("Error writing general log: \(error)")
        }
    }
    
    private func updateStats() {
        let memoryUsed = ProcessInfo.processInfo.physicalMemory / (1024 * 1024)
        let fps = Double(framesProcessed) / (CFAbsoluteTimeGetCurrent() - ProcessInfo.processInfo.systemUptime)
        stats = """
        Memory used: \(memoryUsed) MB
        FPS: \(fps)
        Frames processed: \(framesProcessed) / \(totalFrames)
        """
    }

    func loadLog(logPath: String) -> [String] {
        do {
            let logContent = try String(contentsOfFile: logPath)
            return logContent.components(separatedBy: "\n")
        } catch {
            print("Error reading log: \(error)")
            return []
        }
    }
}

// MARK: - UIDocumentPickerDelegate
extension CoreMLProcessor: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        fileSelectionCompletionHandler?(urls)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // Handle cancellation
    }
}
