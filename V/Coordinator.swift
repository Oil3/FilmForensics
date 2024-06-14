import AVKit
import Vision
import AppKit
import SwiftUI

class Coordinator: NSObject {
    var playerView: AVPlayerView?
    var detectionOverlay: CALayer = CALayer()
    var videoOutput: AVPlayerItemVideoOutput?
    var displayLink: CVDisplayLink?
    private var requests = [VNRequest]()
    private var videoSize: CGSize = .zero

    @Binding var showBoundingBoxes: Bool
    @Binding var logDetections: Bool
    @EnvironmentObject var processor: CoreMLProcessor
    
    init(showBoundingBoxes: Binding<Bool>, logDetections: Binding<Bool>) {
        _showBoundingBoxes = showBoundingBoxes
        _logDetections = logDetections
    }

    func setupPlayerView(_ view: AVPlayerView) {
        playerView = view
        playerView?.wantsLayer = true
        setupDetectionOverlay()
    }

    func updatePlayerView(_ view: AVPlayerView, with url: URL?) {
        guard let url = url else { return }
        let player = AVPlayer(url: url)
        view.player = player
        setupVideoOutput(player: player)
        player.play()
        videoSize = getVideoSize(from: player.currentItem)
    }

    private func setupDetectionOverlay() {
        guard let layer = playerView?.layer else { return }
        detectionOverlay.frame = layer.bounds
        detectionOverlay.masksToBounds = true
        layer.addSublayer(detectionOverlay)
    }

    func setupDetection() -> NSError? {
        let error: NSError! = nil
        
        guard let modelURL = Bundle.main.url(forResource: processor.selectedModelName, withExtension: "mlmodelc") else {
            return NSError(domain: "Coordinator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model file is missing"])
        }
        do {
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            let VNDetection = VNCoreMLRequest(model: visionModel, completionHandler: { [weak self] request, error in
                if let results = request.results {
                    self?.drawVisionRequestResults(results)
                }
            })
            self.requests = [VNDetection]
        } catch let error as NSError {
            print("Model loading went wrong: \(error)")
        }
        
        return error
    }

    private func setupVideoOutput(player: AVPlayer) {
        let videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ])
        player.currentItem?.add(videoOutput)
        self.videoOutput = videoOutput
        setupDisplayLink()
    }

    private func setupDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        CVDisplayLinkSetOutputCallback(displayLink!, { (displayLink, inNow, inOutputTime, flagsIn, flagsOut, displayLinkContext) -> CVReturn in
            let controller = Unmanaged<Coordinator>.fromOpaque(displayLinkContext!).takeUnretainedValue()
            controller.processVideoFrame()
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(displayLink!)
    }

    private func processVideoFrame() {
        guard let videoOutput = self.videoOutput else { return }
        
        let currentTime = videoOutput.itemTime(forHostTime: CACurrentMediaTime())
        if videoOutput.hasNewPixelBuffer(forItemTime: currentTime), let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) {
            processFrame(pixelBuffer: pixelBuffer)
        }
    }

    private func processFrame(pixelBuffer: CVPixelBuffer) {
        guard let modelURL = Bundle.main.url(forResource: processor.selectedModelName, withExtension: "mlmodelc"),
              let model = try? VNCoreMLModel(for: MLModel(contentsOf: modelURL)) else {
            return
        }
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            guard let results = request.results else { return }
            self?.drawVisionRequestResults(results)
        }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    func drawVisionRequestResults(_ results: [Any]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionOverlay.sublayers = nil // remove all the old recognized objects
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                continue
            }
            let topLabelObservation = objectObservation.labels[0]
            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(videoSize.width), Int(videoSize.height))
            
            let shapeLayer = self.createRoundedRectLayerWithBounds(objectBounds)
            
            let textLayer = self.createTextSubLayerInBounds(objectBounds,
                                                            identifier: topLabelObservation.identifier,
                                                            confidence: topLabelObservation.confidence)
            shapeLayer.addSublayer(textLayer)
            detectionOverlay.addSublayer(shapeLayer)
        }
        self.updateLayerGeometry()
        CATransaction.commit()
    }

    func updateLayerGeometry() {
        let bounds = rootLayer.bounds
        var scale: CGFloat
        
        let xScale: CGFloat = bounds.size.width / videoSize.height
        let yScale: CGFloat = bounds.size.height / videoSize.width
        
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
    }

    func setupLayers() {
        detectionOverlay = CALayer()
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0.0, y: 0.0, width: videoSize.width, height: videoSize.height)
        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        rootLayer.addSublayer(detectionOverlay)
    }

    func createTextSubLayerInBounds(_ bounds: CGRect, identifier: String, confidence: VNConfidence) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.name = "Object Label"
        let formattedString = NSMutableAttributedString(string: String(format: "\(identifier)\nConfidence:  %.2f", confidence))
        formattedString.addAttributes([NSAttributedString.Key.font: NSFont.systemFont(ofSize: 13)], range: NSRange(location: 0, length: identifier.count))
        textLayer.string = formattedString
        textLayer.bounds = CGRect(x: 0, y: 0, width: bounds.size.height - 10, height: bounds.size.width - 10)
        textLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        textLayer.shadowOpacity = 0.7
        textLayer.shadowOffset = CGSize(width: 2, height: 2)
        textLayer.foregroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.0, 0.0, 0.0, 1.0])
        textLayer.contentsScale = 2.0 // retina rendering
        return textLayer
    }

    func createRoundedRectLayerWithBounds(_ bounds: CGRect) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = "Found Object"
        shapeLayer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1.0, 1.0, 0.2, 0.4])
        shapeLayer.cornerRadius = 7
        return shapeLayer
    }

    private var rootLayer: CALayer {
        return playerView?.layer ?? CALayer()
    }

    private func getVideoSize(from item: AVPlayerItem?) -> CGSize {
        guard let track = item?.asset.tracks(withMediaType: .video).first else {
            return .zero
        }
        let size = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(size.width), height: abs(size.height))
    }
}
