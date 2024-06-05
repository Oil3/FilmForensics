//
//  VideoController.swift
//  V
//
//  Created by Almahdi Morris on 4/6/24.
//

import UIKit
import AVFoundation
import Vision
import CoreML

class Videoontroller: UIViewController, AVPlayerItemOutputPullDelegate {
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var playerItemOutput: AVPlayerItemVideoOutput?
    private var displayLink: CADisplayLink?
    private var selectedVNModel: VNCoreMLModel?
    private var detectionOverlay: CALayer! = nil
    private var metalProcessor: MetalVideoProcessor!
    private var videoURL: URL?
    private var shouldPlayVideoInFaceBox = true // Default to play video
    private var faceVideoLayer: AVPlayerLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupDetectionOverlay()
        loadModel()
        metalProcessor = MetalVideoProcessor()
        setupPlayButton() // Add this line
    }

    func loadVideo(url: URL) {
        videoURL = url
        setupPlayer(with: url)
    }

    private func setupPlayer(with url: URL) {
        player = AVPlayer(url: url)
        playerItem = player?.currentItem
        
        playerItemOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB
        ])
        
        if let playerItem = playerItem, let playerItemOutput = playerItemOutput {
            playerItem.add(playerItemOutput)
        }
        
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidRefresh))
        displayLink?.add(to: .main, forMode: .default)
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = view.bounds
        view.layer.addSublayer(playerLayer)
        
        player?.play()
    }

    private func setupDetectionOverlay() {
        detectionOverlay = CALayer()
        detectionOverlay.frame = view.bounds
        detectionOverlay.masksToBounds = true
        view.layer.addSublayer(detectionOverlay)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let playerLayer = view.layer.sublayers?.first(where: { $0 is AVPlayerLayer }) as? AVPlayerLayer {
            playerLayer.frame = view.bounds
        }
        detectionOverlay.frame = view.bounds
    }

    private func loadModel() {
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

    @objc private func displayLinkDidRefresh(displayLink: CADisplayLink) {
        guard let currentItem = player?.currentItem else { return }
        let currentTime = currentItem.currentTime()
        
        guard let playerItemOutput = playerItemOutput, playerItemOutput.hasNewPixelBuffer(forItemTime: currentTime) else { return }
        
        guard let pixelBuffer = playerItemOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) else { return }
        guard let metalTexture = metalProcessor.process(pixelBuffer: pixelBuffer) else { return }
        processFrame(pixelBuffer: pixelBuffer) // For simplicity, using original pixelBuffer
    }

    private func processFrame(pixelBuffer: CVPixelBuffer) {
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

    private func processObjectObservations(_ observations: [VNRecognizedObjectObservation]) {
        DispatchQueue.main.async {
            self.detectionOverlay.sublayers?.removeAll(where: { $0.name == "objectBox" })
            
            for observation in observations {
                let boundingBox = observation.boundingBox
                let convertedRect = self.convertBoundingBox(boundingBox)
                let boundingBoxLayer = self.createBoundingBoxLayer(frame: convertedRect, color: UIColor.yellow)
                self.detectionOverlay.addSublayer(boundingBoxLayer)
                
                self.logDetection(observation)
            }
        }
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
        layer.name = color == UIColor.yellow ? "objectBox" : "faceBox"
        return layer
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

private func setupPlayButton() {
    let playButton = UIButton(type: .system)
    playButton.setTitle("Toggle Video in Face Box", for: .normal)
    playButton.addTarget(self, action: #selector(toggleVideoInFaceBox), for: .touchUpInside)
    playButton.frame = CGRect(x: 20, y: 40, width: 200, height: 40)
    view.addSubview(playButton)
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


}
