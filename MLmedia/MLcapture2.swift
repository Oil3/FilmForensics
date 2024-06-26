import SwiftUI
import Combine
import Vision
import CoreML
import ScreenCaptureKit


struct MLcaptureMainView: View {
  @StateObject private var viewModel = ScreenCaptureViewModel()
  
  var body: some View {
    NavigationView {
      VStack {
        Button("Start Capture") {
          viewModel.startCapture()
        }
        .padding()
        
        Button("Stop Capture") {
          viewModel.stopCapture()
          
        }
        .padding()
        
        Spacer()
      }
      .frame(minWidth: 150)
      
      MLcaptureCaptureView(viewModel: viewModel)
    }
  }
}

struct MLcaptureCaptureView: View {
  @ObservedObject var viewModel: ScreenCaptureViewModel
  
  var body: some View {
    VStack {
      if let capturedImage = viewModel.capturedImage {
        CaptureContentView(capturedImage: capturedImage)
      } else {
        Text("Waiting for capture to start")
          .foregroundColor(.gray)
      }
    }
    .background(Color.clear)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct CaptureContentView: NSViewRepresentable {
  let capturedImage: NSImage
  
  func makeNSView(context: Context) -> NSImageView {
    let imageView = NSImageView()
    imageView.image = capturedImage
    imageView.imageScaling = .scaleAxesIndependently
    imageView.autoresizingMask = [.width, .height]
    imageView.wantsLayer = true
    setupWindowProperties(for: imageView)
    return imageView
  }
  
  func updateNSView(_ nsView: NSImageView, context: Context) {
    nsView.image = capturedImage
  }
  
  private func setupWindowProperties(for imageView: NSImageView) {
    DispatchQueue.main.async {
      if let window = imageView.window {
        window.isOpaque = true
        window.backgroundColor = .clear
        window.styleMask = [.borderless]
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.level = .floating
      }
    }
  }
}

class ScreenCaptureViewModel: NSObject, ObservableObject {
  @Published var capturedImage: NSImage? = nil
  
  var captureProcessor: MLcaptureCaptureProcessor?
  let model = try! VNCoreMLModel(for: IO_cashtrack().model)
  var captureStream: SCStream?
  var captureConfig: SCStreamConfiguration?
  
  func startCapture() {
    Task {
      do {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let excludedApps = content.applications.filter { app in
          Bundle.main.bundleIdentifier == app.bundleIdentifier
        }
       // guard let screen = NSScreen.main else { return }
        guard let display = content.displays.first else { return }
        
        let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
        
        captureConfig = SCStreamConfiguration()
        captureConfig?.queueDepth = 5
        captureConfig?.width = display.width - 10
        captureConfig?.height = display.height - 100
        captureConfig?.capturesAudio = false
        captureConfig?.ignoreShadowsDisplay = true
        captureConfig?.presenterOverlayPrivacyAlertSetting = .always
        captureConfig?.pixelFormat = kCVPixelFormatType_32BGRA
        
        captureProcessor = MLcaptureCaptureProcessor(viewModel: self, model: model)
        
        captureStream = SCStream(filter: filter, configuration: captureConfig!, delegate: captureProcessor)
        try captureStream?.addStreamOutput(captureProcessor!, type: .screen, sampleHandlerQueue: DispatchQueue(label: "captureQueue"))
        try await captureStream?.startCapture()
        
      } catch {
        print("Failed to start capture: \(error)")
      }
    }
  }
  
  func stopCapture() {
    captureStream?.stopCapture { error in
      if let error = error {
        print("Failed to stop capture: \(error)")
      }
      self.captureStream = nil
      self.captureProcessor = nil
    }
  }
}

class MLcaptureCaptureProcessor: NSObject, SCStreamOutput, SCStreamDelegate {
  let viewModel: ScreenCaptureViewModel
  let model: VNCoreMLModel
  
  init(viewModel: ScreenCaptureViewModel, model: VNCoreMLModel) {
    self.viewModel = viewModel
    self.model = model
  }
  
  func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
    processBuffer(sampleBuffer)
  }
  
  func processBuffer(_ sampleBuffer: CMSampleBuffer) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    
    let request = VNCoreMLRequest(model: model) { request, error in
      if let results = request.results as? [VNRecognizedObjectObservation] {
        self.handleResults(results, from: pixelBuffer)
      }
    }
    
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
    try? handler.perform([request])
  }
  
  private func handleResults(_ results: [VNRecognizedObjectObservation], from pixelBuffer: CVPixelBuffer) {
    DispatchQueue.main.async {
      // Process the results and update the view model
      self.viewModel.capturedImage = self.createImage(from: pixelBuffer)
    }
  }
  
  private func createImage(from pixelBuffer: CVPixelBuffer) -> NSImage? {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let context = CIContext(options: nil)
    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
    return NSImage(cgImage: cgImage, size: NSSize(width: ciImage.extent.width, height: ciImage.extent.height))
  }
}
