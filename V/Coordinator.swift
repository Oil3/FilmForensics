import AVKit
import Vision
import AppKit
import SwiftUI
import CoreML
import AVFoundation

class Coordinator: NSObject, ObservableObject {
    var playerView: AVPlayerView?
    var detectionOverlay: CALayer = CALayer()
    var videoOutput: AVPlayerItemVideoOutput?
    var displayLink: CVDisplayLink?
    private var bufferSize: CGSize = .zero
    private var yoloModel: IO_cashtrack?
    private var selectedVNModel: VNCoreMLModel?
    private var audioPlayer: AVAudioPlayer?
    private var lastDetectionTime: CFTimeInterval = 0

    @Binding var showBoundingBoxes: Bool
    @Binding var logDetections: Bool
    @EnvironmentObject var detectionStats: DetectionStats

    init(showBoundingBoxes: Binding<Bool>, logDetections: Binding<Bool>) {
        _showBoundingBoxes = showBoundingBoxes
        _logDetections = logDetections
        super.init()
        loadModel()
        loadSound()
    }

    func loadModel() {
        guard let modelUrl = Bundle.main.url(forResource: "IO_cashtrack", withExtension: "mlmodelc") else {
            fatalError("Model file not found")
        }

        do {
            let model = try MLModel(contentsOf: modelUrl)
            yoloModel = IO_cashtrack(model: model)
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
    }

    func setupDetectionOverlay() {
        guard let layer = playerView?.layer else { return }
        detectionOverlay.frame = layer.bounds
        detectionOverlay.masksToBounds = true
        layer.addSublayer(detectionOverlay)
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
        guard let model = yoloModel else { return }

        let input = IO_cashtrackInput(image: pixelBuffer, iouThreshold: 0.45, confidenceThreshold: 0.25)
        guard let output = try? model.prediction(input: input) else {
//            self.detectionStats.addMultiple([], removeAllFirst: false)
            return
        }

        DispatchQueue.main.async {
            self.handleDetectionOutput(output)
        }
    }

    private func handleDetectionOutput(_ output: IO_cashtrackOutput) {
        let confidence = output.confidence
        let coordinates = output.coordinates

        var stats = [Stats]()
        var observations = [VNRecognizedObjectObservation]()
        var detectedObjectsCount = 0

        for i in 0..<confidence.shape[0].intValue {
            let confidenceValues = (0..<confidence.shape[1].intValue).map { confidence[[i, $0] as [NSNumber]].floatValue }
            let maxConfidence = confidenceValues.max() ?? 0
            let maxIndex = confidenceValues.firstIndex(of: maxConfidence) ?? 0

            if maxConfidence > 0.25 {
                let x = coordinates[[i, 0] as [NSNumber]].floatValue
                let y = coordinates[[i, 1] as [NSNumber]].floatValue
                let width = coordinates[[i, 2] as [NSNumber]].floatValue
                let height = coordinates[[i, 3] as [NSNumber]].floatValue

                let boundingBox = CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
                let objectObservation = VNRecognizedObjectObservation(boundingBox: boundingBox)
                observations.append(objectObservation)

                let label = "Object \(maxIndex)"
                stats.append(Stats(key: label, value: String(format: "%.2f", maxConfidence)))
                detectedObjectsCount += 1
            }
        }

        detectionStats.addMultiple(stats, removeAllFirst: false)

        if showBoundingBoxes {
            drawVisionRequestResults(observations)
        }

        if detectedObjectsCount > 0 {
            playSound()
            updateDetectionTime()
        }
    }

    private func updateDetectionTime() {
        let currentTime = CACurrentMediaTime()
        let detectionInterval = currentTime - lastDetectionTime
        lastDetectionTime = currentTime

        let fps = 1.0 / detectionInterval
        detectionStats.addMultiple([Stats(key: "FPS", value: String(format: "%.2f", fps))], removeAllFirst: false)
    }

    func drawVisionRequestResults(_ results: [VNRecognizedObjectObservation]) {
        CATransaction.begin()
        CATransaction.setValue(true, forKey: kCATransactionDisableActions)
        detectionOverlay.sublayers = nil // remove all the old recognized objects
        for observation in results {
            let objectBounds = VNImageRectForNormalizedRect(observation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
            let shapeLayer = self.createRoundedRectLayerWithBounds(objectBounds)
            detectionOverlay.addSublayer(shapeLayer)
        }
        self.updateLayerGeometry()
        CATransaction.commit()
    }

    func updateLayerGeometry() {
        let bounds = rootLayer.bounds
        var scale: CGFloat

        let xScale: CGFloat = bounds.size.width / bufferSize.height
        let yScale: CGFloat = bounds.size.height / bufferSize.width

        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(true, forKey: kCATransactionDisableActions)

        detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)

        CATransaction.commit()
    }

    func setupLayers() {
        detectionOverlay = CALayer()
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0.0, y: 0.0, width: bufferSize.width, height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        rootLayer.addSublayer(detectionOverlay)
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
}
