import SwiftUI
import AVFoundation
import CoreImage
import Vision
import CoreML

struct CoreVideoPlayer: View {
  @State private var videoURL: URL?
  @State private var ciContext = CIContext()
  @State private var selectedFilter: CIFilter?
  @State private var mlModel: VNCoreMLModel?
  @State private var applyFilter = false
  @State private var applyMLModel = false
  @State private var sideBySide = false
  @State private var brightness: CGFloat = 0.0
  @State private var contrast: CGFloat = 1.0
  @State private var saturation: CGFloat = 1.0
  @State private var inputEV: CGFloat = 0.0
  @State private var selectedSize = "1024x576"
  @State private var player: AVPlayer?
  @State private var originalPlayerLayer: AVPlayerLayer?
  @State private var processedPlayerLayer: AVPlayerLayer?
  
  let sizes = ["640x640", "1024x576", "576x1024", "1280x720"]
  
  var body: some View {
    VStack {
      HStack {
        Button("Choose Video") {
          chooseVideo()
        }
        Button("Choose Filter") {
          chooseFilter()
        }
        Button("Choose CoreML Model") {
          chooseModel()
        }
      }
      HStack {
        Toggle("Apply Filter", isOn: $applyFilter)
        Toggle("Apply CoreML Model", isOn: $applyMLModel)
        Toggle("Side by Side", isOn: $sideBySide)
      }
      Picker("View Size", selection: $selectedSize) {
        ForEach(sizes, id: \.self) { size in
          Text(size).tag(size)
        }
      }
      .pickerStyle(MenuPickerStyle())
      HStack {
        Slider(value: $brightness, in: -1...1, step: 0.1) {
          Text("Brightness")
        }
        Slider(value: $contrast, in: 0...4, step: 0.1) {
          Text("Contrast")
        }
        Slider(value: $saturation, in: 0...4, step: 0.1) {
          Text("Saturation")
        }
        Slider(value: $inputEV, in: -2...2, step: 0.1) {
          Text("Exposure")
        }
      }
      ScrollView {
      CoreVideoPlayerView(videoURL: $videoURL, applyFilter: $applyFilter, selectedFilter: $selectedFilter, applyMLModel: $applyMLModel, mlModel: $mlModel, sideBySide: $sideBySide, brightness: $brightness, contrast: $contrast, saturation: $saturation, inputEV: $inputEV, selectedSize: $selectedSize, player: $player, originalPlayerLayer: $originalPlayerLayer, processedPlayerLayer: $processedPlayerLayer, ciContext: $ciContext)
        .onChange(of: applyFilter) { _ in updateVideoProcessing() }
        .onChange(of: applyMLModel) { _ in updateVideoProcessing() }
        .onChange(of: sideBySide) { _ in updateVideoSize() }
        .onChange(of: selectedSize) { _ in updateVideoSize() }
        .onChange(of: brightness) { _ in updateVideoProcessing() }
        .onChange(of: contrast) { _ in updateVideoProcessing() }
        .onChange(of: saturation) { _ in updateVideoProcessing() }
        .onChange(of: inputEV) { _ in updateVideoProcessing() }
    }
    .padding()
      }
  }
  
  private func chooseVideo() {
    let panel = NSOpenPanel()
    panel.allowedFileTypes = ["mp4", "mov"]
    if panel.runModal() == .OK {
      videoURL = panel.url
      setupPlayer()
    }
  }
  
  private func chooseFilter() {
    let filterNames = ["CISepiaTone", "CIColorInvert", "CIExposureAdjust"]
    let alert = NSAlert()
    alert.messageText = "Choose Filter"
    for filterName in filterNames {
      alert.addButton(withTitle: filterName)
    }
    alert.addButton(withTitle: "Cancel")
    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
      selectedFilter = CIFilter(name: filterNames[0])
    } else if response == .alertSecondButtonReturn {
      selectedFilter = CIFilter(name: filterNames[1])
    } else if response == .alertThirdButtonReturn {
      selectedFilter = CIFilter(name: filterNames[2])
    }
    updateVideoProcessing()
  }
  
  private func chooseModel() {
    let panel = NSOpenPanel()
    panel.allowedFileTypes = ["mlmodel"]
    if panel.runModal() == .OK, let url = panel.url {
      do {
        let model = try MLModel(contentsOf: url)
        mlModel = try VNCoreMLModel(for: model)
      } catch {
        print("Error loading CoreML model: \(error)")
      }
    }
    updateVideoProcessing()
  }
  
  private func updateVideoProcessing() {
    player?.seek(to: .zero)
    setupPlayer()
  }
  
  private func updateVideoSize() {
    guard let originalPlayerLayer = originalPlayerLayer, let processedPlayerLayer = processedPlayerLayer, let size = sizes.first(where: { $0 == selectedSize }) else { return }
    
    let dimensions = size.split(separator: "x").compactMap { Int($0) }
    if dimensions.count == 2 {
      let width = CGFloat(dimensions[0])
      let height = CGFloat(dimensions[1])
      if sideBySide {
        originalPlayerLayer.frame.size = CGSize(width: width / 2, height: height)
        processedPlayerLayer.frame.size = CGSize(width: width / 2, height: height)
        processedPlayerLayer.frame.origin.x = width / 2
      } else {
        originalPlayerLayer.frame.size = CGSize(width: width, height: height)
        processedPlayerLayer.frame.size = CGSize(width: width, height: height)
        processedPlayerLayer.frame.origin.x = 0
      }
    }
  }
  
  private func setupPlayer() {
    guard let videoURL = videoURL else { return }
    let asset = AVAsset(url: videoURL)
    let playerItem = AVPlayerItem(asset: asset)
    player = AVPlayer(playerItem: playerItem)
    
    let videoComposition = AVVideoComposition(asset: asset) { request in
      var ciImage = request.sourceImage.clampedToExtent()
      
      if let selectedFilter = selectedFilter, applyFilter {
        selectedFilter.setValue(ciImage, forKey: kCIInputImageKey)
        selectedFilter.setValue(brightness, forKey: kCIInputBrightnessKey)
        selectedFilter.setValue(contrast, forKey: kCIInputContrastKey)
        selectedFilter.setValue(saturation, forKey: kCIInputSaturationKey)
        selectedFilter.setValue(inputEV, forKey: kCIInputEVKey)
        ciImage = selectedFilter.outputImage ?? ciImage
      }
      
      if let mlModel = mlModel, applyMLModel {
        let request = VNCoreMLRequest(model: mlModel) { request, error in
          guard let results = request.results as? [VNPixelBufferObservation], let result = results.first else { return }
          let ciResultImage = CIImage(cvPixelBuffer: result.pixelBuffer)
          ciImage = ciResultImage
        }
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try? handler.perform([request])
      }
      
      request.finish(with: ciImage, context: nil)
    }
    
    
    playerItem.videoComposition = videoComposition
    
    if originalPlayerLayer == nil {
      originalPlayerLayer = AVPlayerLayer(player: player)
      originalPlayerLayer?.frame = .zero
    }
    
    if processedPlayerLayer == nil {
      processedPlayerLayer = AVPlayerLayer(player: player)
      processedPlayerLayer?.frame = .zero
    }
  }
}

struct CoreVideoPlayerView: NSViewRepresentable {
  @Binding var videoURL: URL?
  @Binding var applyFilter: Bool
  @Binding var selectedFilter: CIFilter?
  @Binding var applyMLModel: Bool
  @Binding var mlModel: VNCoreMLModel?
  @Binding var sideBySide: Bool
  @Binding var brightness: CGFloat
  @Binding var contrast: CGFloat
  @Binding var saturation: CGFloat
  @Binding var inputEV: CGFloat
  @Binding var selectedSize: String
  @Binding var player: AVPlayer?
  @Binding var originalPlayerLayer: AVPlayerLayer?
  @Binding var processedPlayerLayer: AVPlayerLayer?
  @Binding var ciContext: CIContext
  
  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    view.wantsLayer = true
    return view
  }
  
  func updateNSView(_ nsView: NSView, context: Context) {
    guard let player = player, let originalPlayerLayer = originalPlayerLayer, let processedPlayerLayer = processedPlayerLayer else { return }
    
    if originalPlayerLayer.superlayer == nil {
      originalPlayerLayer.frame = nsView.bounds
      nsView.layer?.addSublayer(originalPlayerLayer)
    }
    
    if sideBySide {
      if processedPlayerLayer.superlayer == nil {
        processedPlayerLayer.frame = nsView.bounds
        nsView.layer?.addSublayer(processedPlayerLayer)
      }
      processedPlayerLayer.frame = CGRect(x: nsView.bounds.width / 2, y: 0, width: nsView.bounds.width / 2, height: nsView.bounds.height)
    } else {
      processedPlayerLayer.removeFromSuperlayer()
    }
    
    player.play()
  }
}
