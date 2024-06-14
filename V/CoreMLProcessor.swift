import SwiftUI
import CoreML
import Vision
import AVFoundation

class CoreMLProcessor: NSObject, ObservableObject {
    @Published var selectedModelURL: String = "IO_cashtrack"
    @Published var modelList: [String] = ["ccashier3", "IO_cashtrack", "cctrack23090"]
    @Published var detailedLogs: [String] = []
    @Published var stats: String = ""
    @Published var currentObservations: [VNRecognizedObjectObservation] = []
    @Published var selectedImage: NSImage?
    @Published var selectedVideo: URL?
    @Published var detectionFrames: [DetectionFrame] = []
    @Published var resizedImages: [String: NSImage] = [:]
    @Published var selectedResizedImageKey: String = "output_640"

    var isProcessing = false
    var framesProcessed = 0
    var totalFrames = 0
    var lastFrameCount = 0
    var fpsCalculationStartTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    var fileSelectionCompletionHandler: (([URL]) -> Void)?
    var detectionCounter = 0

    private var logFileURL: URL?
    private var summaryLogFileURL: URL?

    struct DetectionFrame: Identifiable {
        let id = UUID()
        let imageURL: URL
        let timestamp: Double
        let boundingBoxes: [CGRect]
    }

    func selectModel(named modelName: String) {
        selectedModelURL = modelName
    }

    func selectFiles(completionHandler: @escaping ([URL]) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true
        openPanel.allowedFileTypes = ["public.movie", "public.image"]
        openPanel.begin { response in
            if response == .OK {
                completionHandler(openPanel.urls)
            }
        }
    }

    func startProcessing(urls: [URL], confidenceThreshold: Float, iouThreshold: Float, noVideoPlayback: Bool) {
        guard let model = loadModel(named: selectedModelURL) else {
            print("Failed to load model: \(selectedModelURL)")
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
            let videoExtensions = ["mp4", "mov", "gif"]
              if videoExtensions.contains(url.pathExtension) {
                    self.processVideo(url: url, model: model, confidenceThreshold: confidenceThreshold, iouThreshold: iouThreshold, noVideoPlayback: noVideoPlayback)
                } else {
                    self.processImage(url: url, model: model, confidenceThreshold: confidenceThreshold, iouThreshold: iouThreshold)
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
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlpackage") else {
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
                    if let frameImage = self?.drawBoundingBoxes(on: ciImage, with: results) {
                        if let imageURL = self?.saveImageAsJPEG(frameImage, withName: "frame_\(self?.framesProcessed ?? 0)") {
                            DispatchQueue.main.async {
                                let boundingBoxes = results.map { $0.boundingBox }
                                self?.detectionFrames.append(DetectionFrame(imageURL: imageURL, timestamp: frameTime, boundingBoxes: boundingBoxes))
                            }
                        }
                    }
                }
            }

            try? handler.perform([request])
            self.framesProcessed += 1
            if CFAbsoluteTimeGetCurrent() - self.fpsCalculationStartTime >= 5 {
                DispatchQueue.main.async {
                    self.updateStats()
                }
                self.fpsCalculationStartTime = CFAbsoluteTimeGetCurrent()
                self.lastFrameCount = self.framesProcessed
            }
        }
        reader.cancelReading()

        generateLog(for: url)
    }

    private func processImage(url: URL, model: MLModel, confidenceThreshold: Float, iouThreshold: Float) {
        print("Processing image: \(url)")
        let handler = VNImageRequestHandler(url: url, options: [:])

        let request = VNCoreMLRequest(model: try! VNCoreMLModel(for: model)) { [weak self] request, error in
            if let results = request.results as? [VNRecognizedObjectObservation] {
                DispatchQueue.main.async {
                    self?.currentObservations = results
                }
                for observation in results {
                    if observation.confidence >= confidenceThreshold {
                        self?.logDetection(observation, at: nil, for: url, frameNumber: nil)
                    }
                }
                if let frameImage = self?.drawBoundingBoxes(on: CIImage(contentsOf: url)!, with: results) {
                    if let imageURL = self?.saveImageAsJPEG(frameImage, withName: "frame_\(self?.framesProcessed ?? 0)") {
                        DispatchQueue.main.async {
                            let boundingBoxes = results.map { $0.boundingBox }
                            self?.detectionFrames.append(DetectionFrame(imageURL: imageURL, timestamp: 0, boundingBoxes: boundingBoxes))
                        }
                    }
                }
            }
        }

        try? handler.perform([request])
        generateLog(for: url)
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
        Video File: \(logFileURL?.deletingLastPathComponent().lastPathComponent ?? "")
        Average FPS: \(String(format: "%.2f", avgFps))
        Total Detections: \(detectionCounter)
        Below Threshold Detections: \(detailedLogs.count - detectionCounter)
        Model Used: \(selectedModelURL)
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
            self.stats = """
            Memory used: \(formattedMemoryUsed) MB
            FPS: \(formattedFPS)
            Frames processed: \(self.framesProcessed) / \(self.totalFrames)
            """
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

    private func saveImageAsJPEG(_ image: CIImage, withName name: String) -> URL? {
        let context = CIContext()
        guard let cgImage = context.createCGImage(image, from: image.extent),
              let data = NSImage(cgImage: cgImage, size: NSSize(width: image.extent.size.width, height: image.extent.size.height)).tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: data),
              let jpegData = bitmapImage.representation(using: .jpeg, properties: [:]) else {
            return nil
        }
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(name).appendingPathExtension("jpg")
        do {
            try jpegData.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving image as JPEG: \(error)")
            return nil
        }
    }

    func resizeImage(image: CIImage, outputKey: CGSize) -> CIImage {
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(image, from: image.extent)
        let nsImage = NSImage(cgImage: cgImage!, size: NSSize(width: image.extent.width, height: image.extent.height))
        guard let resizerModel = loadResizerModel() else {
            print("Failed to load resizer model")
            return image
        }
        do {
            let resizer = try MLresizer(model: resizerModel)
            let pixelBuffer = nsImage.toCVPixelBuffer()!
            let input = MLresizerInput(image: pixelBuffer)
            let output = try resizer.prediction(input: input)
            let outputImage = CIImage(cvPixelBuffer: output.output_640) // Adjust as necessary for other output sizes
            return outputImage
        } catch {
            print("Error during resizing prediction: \(error)")
            return image
        }
    }

    private func drawBoundingBoxes(on image: CIImage, with observations: [VNRecognizedObjectObservation]) -> CIImage {
        var annotatedImage = image
        let context = CIContext()
        for observation in observations {
            let boundingBox = observation.boundingBox
            let color = CIColor(red: 1, green: 0, blue: 0, alpha: 1)
            annotatedImage = annotatedImage.applyingFilter("CISourceOverCompositing", parameters: [
                kCIInputImageKey: CIImage(color: color).cropped(to: CGRect(x: boundingBox.origin.x * image.extent.width, y: boundingBox.origin.y * image.extent.height, width: boundingBox.size.width * image.extent.width, height: boundingBox.size.height * image.extent.height)),
                kCIInputBackgroundImageKey: annotatedImage
            ])
        }
        return annotatedImage
    }

    private func loadResizerModel() -> MLModel? {
        guard let modelURL = Bundle.main.url(forResource: "MLresizer", withExtension: "mlmodelc") else {
            print("Model not found: MLresizer")
            return nil
        }
        do {
            return try MLModel(contentsOf: modelURL)
        } catch {
            print("Error loading model: \(error)")
            return nil
        }
    }
}

extension NSImage {
    func toCVPixelBuffer() -> CVPixelBuffer? {
        let width = Int(self.size.width)
        let height = Int(self.size.height)
        var pixelBuffer: CVPixelBuffer?
        let pixelBufferAttributes = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ] as CFDictionary
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, pixelBufferAttributes, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

        context?.translateBy(x: 0, y: CGFloat(height))
        context?.scaleBy(x: 1.0, y: -1.0)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context!, flipped: false)
        self.draw(at: CGPoint(x: 0, y: 0), from: CGRect(x: 0, y: 0, width: width, height: height), operation: .copy, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        return buffer
    }
}
