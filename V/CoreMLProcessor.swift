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
    @Published var detailedLogs: [String] = []
    @Published var stats: String = ""
    @Published var currentObservations: [VNRecognizedObjectObservation] = []
    @Published var selectedImage: UIImage?
    @Published var selectedVideo: URL?
    @Published var detectionFrames: [DetectionFrame] = []
    @Published var showStats: Bool = true

    var isProcessing = false
    var framesProcessed = 0
    var totalFrames = 0
    var lastFrameCount = 0
    var fpsCalculationStartTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    var fileSelectionCompletionHandler: (([URL]) -> Void)?
    var detectionCounter = 0

    private var logFileURL: URL?
    private var summaryLogFileURL: URL?

    struct DetectionFrame: Identifiable, Hashable {
        let id = UUID()
        let imageURL: URL
        let timestamp: Double
    }

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
        detectionCounter = 0
        let dateTimeString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .long)
        summaryLogFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("summary_V_\(dateTimeString).txt")

        DispatchQueue.global(qos: .userInitiated).async {
            for url in urls {
                if !self.isProcessing { break }
                let logFilename = url.deletingPathExtension().lastPathComponent + "_V_" + dateTimeString + ".txt"
                self.logFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(logFilename)

                if url.pathExtension.lowercased() == "mp4" || url.pathExtension.lowercased() == "mov" {
                    self.processVideo(url: url, model: model, confidenceThreshold: confidenceThreshold, iouThreshold: iouThreshold, noVideoPlayback: noVideoPlayback)
                } else {
                    self.processImage(url: url, model: model, confidenceThreshold: confidenceThreshold, iouThreshold: confidenceThreshold)
                }
            }

            DispatchQueue.main.async {
                self.isProcessing = false
                self.generateGeneralLog()
            }
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
            let frameTime = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            let request = VNCoreMLRequest(model: try! VNCoreMLModel(for: model)) { [weak self] request, error in
                if let results = request.results as? [VNRecognizedObjectObservation] {
                    DispatchQueue.main.async {
                        self?.currentObservations = results
                    }
                    for observation in results {
                        if observation.confidence >= confidenceThreshold {
                            self?.logDetection(observation, at: frameTime, for: url, frameNumber: self?.framesProcessed ?? 0)
                        }
                    }
                    if let frameImage = self?.drawBoundingBoxes(on: ciImage, with: results),
                       let imageURL = self?.saveImageAsJPEG(frameImage, withName: "frame_\(self?.framesProcessed ?? 0)") {
                        DispatchQueue.main.async {
                            self?.detectionFrames.append(DetectionFrame(imageURL: imageURL, timestamp: frameTime))
                        }
                    }
                }
            }

            try? handler.perform([request])
            self.framesProcessed += 1
            DispatchQueue.main.async {
                self.updateStats()
            }
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
                    DispatchQueue.main.async {
                        self?.currentObservations = results
                    }
                    for observation in results {
                        if observation.confidence >= confidenceThreshold {
                            self?.logDetection(observation, at: nil, for: url, frameNumber: nil)
                        }
                    }
                    if let frameImage = self?.drawBoundingBoxes(on: image, with: results),
                       let imageURL = self?.saveImageAsJPEG(frameImage, withName: "frame_\(self?.framesProcessed ?? 0)") {
                        DispatchQueue.main.async {
                            self?.detectionFrames.append(DetectionFrame(imageURL: imageURL, timestamp: 0))
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
                    DispatchQueue.main.async {
                        self?.currentObservations = results
                    }
                    for observation in results {
                        if observation.confidence >= confidenceThreshold {
                            self?.logDetection(observation, at: nil, for: url, frameNumber: nil)
                        }
                    }
                    if let frameImage = self?.drawBoundingBoxes(on: resizedImage, with: results),
                       let imageURL = self?.saveImageAsJPEG(frameImage, withName: "frame_\(self?.framesProcessed ?? 0)") {
                        DispatchQueue.main.async {
                            self?.detectionFrames.append(DetectionFrame(imageURL: imageURL, timestamp: 0))
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

    private func drawBoundingBoxes(on image: CIImage, with observations: [VNRecognizedObjectObservation]) -> UIImage? {
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(image, from: image.extent) else { return nil }
        let uiImage = UIImage(cgImage: cgImage)

        UIGraphicsBeginImageContext(uiImage.size)
        uiImage.draw(at: .zero)

        let drawRect = CGRect(x: 0, y: 0, width: uiImage.size.width, height: uiImage.size.height)
        let contextRef = UIGraphicsGetCurrentContext()
        contextRef?.setStrokeColor(UIColor.red.cgColor)
        contextRef?.setLineWidth(2.0)

        for observation in observations {
            let rect = VNImageRectForNormalizedRect(observation.boundingBox, Int(drawRect.width), Int(drawRect.height))
            contextRef?.stroke(rect)
        }

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }

    private func saveImageAsJPEG(_ image: UIImage, withName name: String) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.95) else { return nil }
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(name).appendingPathExtension("jpg")
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving image as JPEG: \(error)")
            return nil
        }
    }

    private func generateLog(for url: URL) {
        guard let logFileURL = logFileURL else { return }

        do {
            let logText = detailedLogs.joined(separator: "\n")
            let directory = logFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            try logText.write(to: logFileURL, atomically: true, encoding: .utf8)
            DispatchQueue.main.async {
                self.detailedLogs.removeAll()
            }
        } catch {
            print("Error writing log: \(error)")
        }
    }

    private func generateGeneralLog() {
        guard let summaryLogFileURL = summaryLogFileURL else { return }

        let elapsedTime = CFAbsoluteTimeGetCurrent() - fpsCalculationStartTime
        let avgFps = Double(framesProcessed) / elapsedTime
        let summaryInfo = """
        Video File: \(logFileURL?.deletingPathExtension().lastPathComponent ?? "")
        Average FPS: \(String(format: "%.2f", avgFps))
        Total Detections: \(detectionCounter)
        Below Threshold Detections: \(detailedLogs.count - detectionCounter)
        Model Used: \(selectedModelName)
        Elapsed Time: \(String(format: "%.2f", elapsedTime)) seconds
        """

        do {
            let directory = summaryLogFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            try summaryInfo.write(to: summaryLogFileURL, atomically: true, encoding: .utf8)
            DispatchQueue.main.async {
                self.stats = summaryInfo
            }
        } catch {
            print("Error writing summary log: \(error)")
        }
    }

    private func updateStats() {
        var usedMegabytes: Float = 0
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if kerr == KERN_SUCCESS {
            let usedBytes: Float = Float(info.resident_size)
            usedMegabytes = usedBytes / 1024.0 / 1024.0
        }

        let currentTime = CFAbsoluteTimeGetCurrent()
        let elapsedTime = currentTime - fpsCalculationStartTime
        let fps = Double(framesProcessed - lastFrameCount) / elapsedTime

        let formattedMemoryUsed = String(format: "%.2f", usedMegabytes)
        let formattedFPS = String(format: "%.2f", fps)

        DispatchQueue.main.async {
            if self.showStats {
                self.stats = """
                Memory used: \(formattedMemoryUsed) MB
                FPS: \(formattedFPS)
                Frames processed: \(self.framesProcessed) / \(self.totalFrames)
                """
            }
        }

        fpsCalculationStartTime = currentTime
        lastFrameCount = framesProcessed
    }

    private func logDetection(_ observation: VNRecognizedObjectObservation, at time: Double?, for url: URL, frameNumber: Int?) {
        let label = observation.labels.first?.identifier ?? "Unknown"
        let boundingBox = observation.boundingBox
        let timeString = time != nil ? "\(Int(time! / 60)):\(String(format: "%.2f", time!.truncatingRemainder(dividingBy: 60)))" : "N/A"
        let frameString = frameNumber != nil ? "\(frameNumber!)" : "N/A"
        let logMessage = """
        \(String(format: "%04d", detectionCounter)) Object detected in \(url.lastPathComponent): \(label) at \(timeString) (frame: \(frameString)) (x: \(roundedString(boundingBox.origin.x)), y: \(roundedString(boundingBox.origin.y)), width: \(roundedString(boundingBox.width)), height: \(roundedString(boundingBox.height)))
        """
        appendToLogFile(logMessage)
        DispatchQueue.main.async {
            self.detailedLogs.append(logMessage)
        }
        detectionCounter += 1
    }

    private func appendToLogFile(_ message: String) {
        guard let logFileURL = logFileURL else { return }
        do {
            let data = message.data(using: .utf8)!
            let directory = logFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
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

    private func roundedString(_ value: CGFloat) -> String {
        return String(format: "%.2f", value)
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
