import AVKit
import Vision
import AppKit

class VideoViewController: NSViewController {
    var playerView: AVPlayerView!
    var detectionOverlay: CALayer!
    var videoOutput: AVPlayerItemVideoOutput?
    var displayLink: CVDisplayLink?
    var selectedVNModel: VNCoreMLModel?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer?.backgroundColor = NSColor.black.cgColor
        setupPlayerView()
        setupDetectionOverlay()
        loadModel()
    }

    private func setupPlayerView() {
        playerView = AVPlayerView()
        playerView.frame = view.bounds
        playerView.wantsLayer = true  // Ensure it creates a backing layer.
        view.addSubview(playerView)
    }

    private func setupDetectionOverlay() {
        detectionOverlay = CALayer()
        detectionOverlay.frame = view.bounds
        detectionOverlay.masksToBounds = true
        playerView.layer?.addSublayer(detectionOverlay)
    }

    func loadVideo(url: URL) {
        let player = AVPlayer(url: url)
        playerView.player = player
        setupVideoOutput(player: player)
        player.play()
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
            let controller = Unmanaged<VideoViewController>.fromOpaque(displayLinkContext!).takeUnretainedValue()
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

    private func loadModel() {
        guard let modelURL = Bundle.main.url(forResource: "MLcopycontrol25k", withExtension: "mlmodelc"),
              let model = try? MLModel(contentsOf: modelURL) else {
            fatalError("Failed to load model")
        }
        selectedVNModel = try? VNCoreMLModel(for: model)
    }

    private func processFrame(pixelBuffer: CVPixelBuffer) {
        guard let model = selectedVNModel else { return }
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedObjectObservation] else { return }
            self?.updateDetectionOverlay(observations: observations)
        }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    private func updateDetectionOverlay(observations: [VNRecognizedObjectObservation]) {
        DispatchQueue.main.async {
            self.detectionOverlay.sublayers?.forEach { $0.removeFromSuperlayer() }
            observations.forEach { observation in
                let boundingBox = observation.boundingBox
                let convertedRect = self.convertRect(fromVideoRect: boundingBox)
                let layer = self.createBoundingBoxLayer(frame: convertedRect, color: NSColor.red)
                self.detectionOverlay.addSublayer(layer)
            }
        }
    }

    private func createBoundingBoxLayer(frame: CGRect, color: NSColor) -> CALayer {
        let layer = CALayer()
        layer.frame = frame
        layer.borderColor = color.cgColor
        layer.borderWidth = 2
        return layer
    }

    private func convertRect(fromVideoRect videoRect: CGRect) -> CGRect {
        let width = view.bounds.width
        let height = view.bounds.height
        let x = videoRect.origin.x * width
        let y = (1 - videoRect.origin.y - videoRect.height) * height
        return CGRect(x: x, y: y, width: videoRect.width * width, height: videoRect.height * height)
    }
}
