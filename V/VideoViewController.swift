//
//  VideoViewController.swift
//  V
//
//  Created by Almahdi Morris on 4/6/24.
//
import UIKit
import AVKit
import Vision
import CoreML
import SwiftUI

class VideoViewController: UIViewController {
//    @State private var showDocumentPicker = false
    @State private var selectedURL: URL?

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var displayLink: CADisplayLink?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var selectedVNModel: VNCoreMLModel?
    private var detectionOverlay: CALayer! = nil
    private var metalProcessor: MetalVideoProcessor!
    private var faceVideoLayer: AVPlayerLayer?
    private var shouldPlayVideoInFaceBox = true // Default to play video
    private var videoURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupDetectionOverlay()
        metalProcessor = MetalVideoProcessor()
        setupButtons()

        loadModel()
    }

    func loadVideo(url: URL) {
        player = AVPlayer(url: url)
        let playerItem = player?.currentItem
        

        videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        playerItem?.add(videoOutput!)

        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidRefresh))
        displayLink?.add(to: .main, forMode: .default)

        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = view.bounds
        playerLayer?.videoGravity = .resizeAspect
        if let playerLayer = playerLayer {
            view.layer.addSublayer(playerLayer)
        }
        player?.play()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
        detectionOverlay.frame = view.bounds
    }

    @objc private func displayLinkDidRefresh() {
        guard let currentItem = player?.currentItem else { return }
        let currentTime = currentItem.currentTime()

        guard let videoOutput = videoOutput,
              videoOutput.hasNewPixelBuffer(forItemTime: currentTime),
              let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) else { return }
        guard let metalTexture = metalProcessor.process(pixelBuffer: pixelBuffer) else { return }

        processFrame(pixelBuffer: pixelBuffer)
    }

    private func setupDetectionOverlay() {
        detectionOverlay = CALayer()
        detectionOverlay.frame = view.bounds
        detectionOverlay.masksToBounds = true
        view.layer.addSublayer(detectionOverlay)
    }

    private func loadModel() {
        guard let modelURL = Bundle.main.url(forResource: "MLcopycontrol25k", withExtension: "mlmodelc") else {
            fatalError("Model file not found")
        }

        do {
            let model = try MLModel(contentsOf: modelURL)
            selectedVNModel = try VNCoreMLModel(for: model)
        } catch {
            fatalError("Error loading model: \(error)")
        }
    }

    private func processFrame(pixelBuffer: CVPixelBuffer) {
        guard let model = selectedVNModel else { return }

        let request = VNCoreMLRequest(model: model) { (request, error) in
            if let results = request.results as? [VNRecognizedObjectObservation] {
                self.handleDetections(results)
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
            try handler.perform([request])
        } catch {
            print("Failed to perform request: \(error)")
        }
    }

    private func handleDetections(_ observations: [VNRecognizedObjectObservation]) {
        DispatchQueue.main.async {
            self.detectionOverlay.sublayers?.forEach { $0.removeFromSuperlayer() }

            for observation in observations {
                let boundingBox = observation.boundingBox
                let convertedRect = self.convertBoundingBox(boundingBox)
                let layer = self.createBoundingBoxLayer(frame: convertedRect, color: .yellow)
                self.detectionOverlay.addSublayer(layer)
                                self.logDetection(observation)

            }
        }
    }

    private func convertBoundingBox(_ boundingBox: CGRect) -> CGRect {
        let width = boundingBox.width * view.bounds.width
        let height = boundingBox.height * view.bounds.height
        let x = boundingBox.origin.x * view.bounds.width
        let y = view.bounds.height - (boundingBox.origin.y * view.bounds.height + height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func createBoundingBoxLayer(frame: CGRect, color: UIColor) -> CALayer {
        let layer = CALayer()
        layer.frame = frame
        layer.borderColor = color.cgColor
        layer.borderWidth = 2.0
        return layer
    }
    private func processFaceObservations(_ observations: [VNFaceObservation]) {
        DispatchQueue.main.async {
            self.detectionOverlay.sublayers?.removeAll(where: { $0.name == "faceBox" })
            
            for observation in observations {
                let boundingBox = observation.boundingBox
                let convertedRect = self.convertBoundingBox(boundingBox)
                let boundingBoxLayer = self.createBoundingBoxLayer(frame: convertedRect, color: UIColor.systemBlue)
                self.detectionOverlay.addSublayer(boundingBoxLayer)
                
                if self.shouldPlayVideoInFaceBox {
                    self.playVideoInFaceBox(rect: convertedRect)
                }

                self.logFaceDetection(observation)
            }
        }
    }

 @objc private func toggleVideoInFaceBox() {
    shouldPlayVideoInFaceBox.toggle()
}
private func playVideoInFaceBox(rect: CGRect) {
    guard let videoURL = Bundle.main.url(forResource: "matrix", withExtension: "mov") else { return }

    let player = AVPlayer(url: videoURL)
    faceVideoLayer = AVPlayerLayer(player: player)
    faceVideoLayer?.frame = rect
    faceVideoLayer?.videoGravity = .resizeAspectFill
    detectionOverlay.addSublayer(faceVideoLayer!)
    player.play()
}


    private func roundedString(_ value: CGFloat) -> String {
        return String(format: "%.4f", value)
    }

    private func currentDTG() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "ddMMMHHmm"
        return dateFormatter.string(from: Date())
    }

    private func logFileURL(for filename: String) -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "ddMMMyyHH'h'"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "\(filename)_\(timestamp).txt"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(fileName)
    }

    private func appendToLogFile(_ message: String, filename: String) {
        let logURL = logFileURL(for: filename)
        do {
            let data = message.data(using: .utf8)!
            if FileManager.default.fileExists(atPath: logURL.path) {
                let fileHandle = try FileHandle(forWritingTo: logURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            } else {
                try data.write(to: logURL, options: .atomic)
            }
        } catch {
            print("Failed to log detection: \(error)")
        }
    }

    private func logDetection(_ observation: VNRecognizedObjectObservation) {
        let label = observation.labels.first?.identifier ?? "Unknown"
        let boundingBox = observation.boundingBox
        let logMessage = "\(currentDTG()) Object detected: \(label) at (x: \(roundedString(boundingBox.origin.x)), y: \(roundedString(boundingBox.origin.y)), width: \(roundedString(boundingBox.width)), height: \(roundedString(boundingBox.height)))\n"
        if let videoURL = videoURL {
            appendToLogFile(logMessage, filename: videoURL.deletingPathExtension().lastPathComponent)
        }
    }

    private func logFaceDetection(_ observation: VNFaceObservation) {
        let boundingBox = observation.boundingBox
        let logMessage = "\(currentDTG()) Face detected at (x: \(roundedString(boundingBox.origin.x)), y: \(roundedString(boundingBox.origin.y)), width: \(roundedString(boundingBox.width)), height: \(roundedString(boundingBox.height)))\n"
        if let videoURL = videoURL {
            appendToLogFile(logMessage, filename: videoURL.deletingPathExtension().lastPathComponent)
        }
    }

 private func setupButtons() {
        let playButton = UIButton(type: .system)
        playButton.setTitle("Toggle Video in Face Box", for: .normal)
        playButton.addTarget(self, action: #selector(toggleVideoInFaceBox), for: .touchUpInside)
        playButton.frame = CGRect(x: 20, y: 40, width: 200, height: 40)
        view.addSubview(playButton)

        let browseButton = UIButton(type: .system)
        browseButton.setTitle("Open File", for: .normal)
        browseButton.addTarget(self, action: #selector(showDocumentPicker), for: .touchUpInside)
        browseButton.frame = CGRect(x: 240, y: 40, width: 200, height: 40)
        view.addSubview(browseButton)
    }

    @objc private func showDocumentPicker() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.movie, .image])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true, completion: nil)
    }    }
    


import SwiftUI

struct VideoView: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?

    func makeUIViewController(context: Context) -> VideoViewController {
        let viewController = VideoViewController()
        if let url = selectedURL {
            viewController.loadVideo(url: url)
        }
        return viewController
    }

    func updateUIViewController(_ uiViewController: VideoViewController, context: Context) {
        if let url = selectedURL {
            uiViewController.loadVideo(url: url)
        }
    }

    typealias UIViewControllerType = VideoViewController
}



extension VideoViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let url = urls.first {
            loadVideo(url: url)
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("Document picker was cancelled")
    }
}

