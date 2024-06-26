import SwiftUI
import Combine
import Vision
import CoreML
import ScreenCaptureKit
import AVFoundation

struct BoundingBox: Identifiable, Hashable {
  var id = UUID()
  var rect: CGRect
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
  
  static func == (lhs: BoundingBox, rhs: BoundingBox) -> Bool {
    return lhs.id == rhs.id
  }
}


class AppDelegate: NSObject, NSApplicationDelegate {
  var window: NSWindow!
  var viewModel = ScreenCaptureViewModel()
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    let contentView = MLcaptureMainView()
      .environmentObject(viewModel)
    
    window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
      styleMask: [.titled, .closable, .resizable, .miniaturizable],
      backing: .buffered, defer: false)
    window.center()
    window.setFrameAutosaveName("Main Window")
    window.contentView = NSHostingView(rootView: contentView)
    window.makeKeyAndOrderFront(nil)
  }
  
  func stopCapture() {
    viewModel.stopCapture()
  }
}

struct MLcaptureMainView: View {
  @EnvironmentObject var viewModel: ScreenCaptureViewModel
  
  var body: some View {
    NavigationView {
      VStack {
        HStack {
          Button(action: { viewModel.toggleCapture() }) {
            Text(viewModel.isCapturing ? "Stop Capture" : "Start Capture")
              .padding()
              .background(Color.blue)
              .foregroundColor(.white)
              .cornerRadius(8)
          }
          
          Button(action: { viewModel.toggleDisplay() }) {
            Text(viewModel.isDisplaying ? "Stop Display" : "Start Display")
              .padding()
              .background(Color.green)
              .foregroundColor(.white)
              .cornerRadius(8)
          }
          
          Button(action: { viewModel.toggleImmersiveMode() }) {
            Text(viewModel.isImmersive ? "Exit Immersive Mode" : "Enter Immersive Mode")
              .padding()
              .background(Color.orange)
              .foregroundColor(.white)
              .cornerRadius(8)
          }
          
          Button(action: { viewModel.selectAppWindow() }) {
            Text("Select Window")
              .padding()
              .background(Color.purple)
              .foregroundColor(.white)
              .cornerRadius(8)
          }
        }
        .padding()
        
        StatusBarView(status: viewModel.status)
        
        Spacer()
        
        if viewModel.isDisplaying {
          MLcaptureCaptureView()
            .environmentObject(viewModel)
            .background(CaptureClickThroughWrapperView())
        }
      }
      .frame(minWidth: 150)
    }
  }
}

struct StatusBarView: View {
  let status: String
  
  var body: some View {
    Text(status)
      .padding()
      .background(Color.gray.opacity(0.1))
      .frame(maxWidth: .infinity)
  }
}

struct MLcaptureCaptureView: View {
  @EnvironmentObject var viewModel: ScreenCaptureViewModel
  
  var body: some View {
    VStack {
      if let pixelBuffer = viewModel.capturedPixelBuffer {
        PixelBufferView(pixelBuffer: pixelBuffer, boundingBoxes: viewModel.boundingBoxes)
          .scaledToFit()
      } else {
        Text("Waiting for capture to start")
          .foregroundColor(.gray)
      }
    }
    .background(Color.clear)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct PixelBufferView: NSViewRepresentable {
  let pixelBuffer: CVPixelBuffer
  let boundingBoxes: [BoundingBox]
  
  func makeNSView(context: Context) -> NSView {
    return PixelBufferNSView(pixelBuffer: pixelBuffer, boundingBoxes: boundingBoxes)
  }
  
  func updateNSView(_ nsView: NSView, context: Context) {
    if let pixelBufferView = nsView as? PixelBufferNSView {
      pixelBufferView.pixelBuffer = pixelBuffer
      pixelBufferView.boundingBoxes = boundingBoxes
      pixelBufferView.setNeedsDisplay(pixelBufferView.bounds)
    }
  }
}

class PixelBufferNSView: NSView {
  var pixelBuffer: CVPixelBuffer
  var boundingBoxes: [BoundingBox]
  
  init(pixelBuffer: CVPixelBuffer, boundingBoxes: [BoundingBox]) {
    self.pixelBuffer = pixelBuffer
    self.boundingBoxes = boundingBoxes
    super.init(frame: .zero)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    
    // Draw the pixel buffer
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let ciContext = CIContext(cgContext: context, options: nil)
    ciContext.draw(ciImage, in: bounds, from: ciImage.extent)
    
    // Draw bounding boxes
    context.setStrokeColor(NSColor.red.cgColor)
    context.setLineWidth(2)
    
    for box in boundingBoxes {
      let rect = CGRect(x: box.rect.origin.x * bounds.width,
                        y: (1 - box.rect.origin.y - box.rect.height) * bounds.height,
                        width: box.rect.width * bounds.width,
                        height: box.rect.height * bounds.height)
      context.stroke(rect)
    }
  }
}

struct CaptureClickThroughWrapperView: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    view.wantsLayer = true
    DispatchQueue.main.async {
      if let window = view.window {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.styleMask = [.borderless]
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.level = .floating
      }
    }
    return view
  }
  
  func updateNSView(_ nsView: NSView, context: Context) {
    // No need to update the view
  }
}

class ScreenCaptureViewModel: NSObject, ObservableObject {
  @Published var capturedPixelBuffer: CVPixelBuffer? = nil
  @Published var isCapturing = false
  @Published var isDisplaying = false
  @Published var isImmersive = false
  @Published var selectedWindow: SCWindow? = nil
  @Published var status: String = "Ready"
  @Published var boundingBoxes: [BoundingBox] = []
  
  var captureProcessor: MLcaptureCaptureProcessor?
  let model = try! VNCoreMLModel(for: IO_cashtrack().model)
  var captureStream: SCStream?
  var captureConfig: SCStreamConfiguration?
  
  func toggleCapture() {
    if isCapturing {
      stopCapture()
    } else {
      startCapture()
    }
  }
  
  func toggleDisplay() {
    isDisplaying.toggle()
  }
  
  func toggleImmersiveMode() {
    isImmersive.toggle()
    DispatchQueue.main.async {
      guard let window = NSApplication.shared.windows.first else { return }
      if self.isImmersive {
        window.styleMask = [.borderless]
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
      } else {
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.level = .normal
        window.isOpaque = true
        window.backgroundColor = .white
        window.ignoresMouseEvents = false
        window.collectionBehavior = []
      }
    }
  }
  
  func startCapture() {
    Task {
      do {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let excludedApps = content.applications.filter { app in
          Bundle.main.bundleIdentifier == app.bundleIdentifier
        }
        guard let screen = NSScreen.main else { return }
        guard let display = content.displays.first else { return }
        
        let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: selectedWindow != nil ? [selectedWindow!] : [])
        
        captureConfig = SCStreamConfiguration()
        captureConfig?.queueDepth = 5
        captureConfig?.width = 1024
        captureConfig?.height = 576
        captureConfig?.pixelFormat = kCVPixelFormatType_32BGRA
        
        captureProcessor = MLcaptureCaptureProcessor(viewModel: self, model: model)
        
        captureStream = SCStream(filter: filter, configuration: captureConfig!, delegate: captureProcessor)
        try captureStream?.addStreamOutput(captureProcessor!, type: .screen, sampleHandlerQueue: DispatchQueue(label: "captureQueue"))
        try await captureStream?.startCapture()
        
        DispatchQueue.main.async {
          self.isCapturing = true
          self.status = "Capturing"
        }
      } catch {
        DispatchQueue.main.async {
          self.status = "Failed to start capture: \(error)"
        }
      }
    }
  }
  
  func stopCapture() {
    captureStream?.stopCapture { error in
      if let error = error {
        DispatchQueue.main.async {
          self.status = "Failed to stop capture: \(error)"
        }
      }
      self.captureStream = nil
      self.captureProcessor = nil
      DispatchQueue.main.async {
        self.isCapturing = false
        self.status = "Stopped"
      }
    }
  }
  
  func selectAppWindow() {
    let alert = NSAlert()
    alert.messageText = "Select Application Window"
    alert.informativeText = "Choose an application window to capture:"
    
    let applications = NSWorkspace.shared.runningApplications
    
    alert.addButton(withTitle: "Cancel")
    applications.forEach { app in
      alert.addButton(withTitle: app.localizedName ?? "Unnamed App")
    }
    
    let result = alert.runModal()
    guard result != .alertFirstButtonReturn else {
      selectedWindow = nil
      return
    }
    
    let selectedButtonIndex = alert.buttons.firstIndex { $0 == alert.buttons[result.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue] } ?? 0
    if selectedButtonIndex > 0 {
      let selectedApp = applications[selectedButtonIndex - 1]
      // Fetch windows of the selected application
      Task {
        let content = try? await SCShareableContent.current
        let windows = content?.windows.filter { $0.owningApplication?.bundleIdentifier == selectedApp.bundleIdentifier }
        // Select the first window of the application
        selectedWindow = windows?.first
      }
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
      self.viewModel.capturedPixelBuffer = pixelBuffer
      self.viewModel.boundingBoxes = results.map { BoundingBox(rect: $0.boundingBox) }
    }
  }
}
