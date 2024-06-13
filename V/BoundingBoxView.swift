import SwiftUI
import Vision
import AppKit
import AVKit

class BoundingBoxView: NSView {
    private let strokeWidth: CGFloat = 2
    
    private var imageRect: CGRect = .zero
    var observations: [VNDetectedObjectObservation]? {
        didSet {
            self.needsDisplay = true
        }
    }
    
    func updateSize(for imageSize: CGSize) {
        imageRect = AVMakeRect(aspectRatio: imageSize, insideRect: self.bounds)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        guard let observations = observations, !observations.isEmpty else { return }
        
        for (i, observation) in observations.enumerated() {
            let color = NSColor(hue: CGFloat(i) / CGFloat(observations.count), saturation: 1, brightness: 1, alpha: 1)
            let rect = drawBoundingBox(context: context, observation: observation, color: color)
            if let recognizedObjectObservation = observation as? VNRecognizedObjectObservation {
                addLabel(on: rect, observation: recognizedObjectObservation, color: color)
            }
        }
    }
    
    func drawBoundingBox(context: CGContext, observation: VNDetectedObjectObservation, color: NSColor) -> CGRect {
        let convertedRect = VNImageRectForNormalizedRect(observation.boundingBox, Int(imageRect.width), Int(imageRect.height))
        let rect = CGRect(x: convertedRect.minX + imageRect.minX,
                          y: imageRect.maxY - convertedRect.minY - convertedRect.height,
                          width: convertedRect.width, height: convertedRect.height)
        
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(strokeWidth)
        context.stroke(rect)
        
        return rect
    }
    
    private func addLabel(on rect: CGRect, observation: VNRecognizedObjectObservation, color: NSColor) {
        guard let firstLabel = observation.labels.first?.identifier else { return }
        
        let label = NSTextField(labelWithString: firstLabel)
        label.font = NSFont.boldSystemFont(ofSize: 13)
        label.backgroundColor = color
        label.isBezeled = false
        label.drawsBackground = true
        label.frame = CGRect(x: rect.origin.x, y: rect.origin.y - label.frame.height, width: rect.width, height: label.frame.height)
        addSubview(label)
    }
}

struct BoundingBoxViewWrapper: NSViewRepresentable {
    @Binding var observations: [VNRecognizedObjectObservation]
    var image: NSImage

    func makeNSView(context: Context) -> BoundingBoxView {
        let view = BoundingBoxView()
        view.updateSize(for: image.size)
        view.observations = observations
        return view
    }

    func updateNSView(_ nsView: BoundingBoxView, context: Context) {
        nsView.updateSize(for: image.size)
        nsView.observations = observations
    }
}
