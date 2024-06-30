import SwiftUI
import AVFoundation
import CoreImage
import CoreML

struct CoreVideoPlayer: View {
  @State private var videoURL: URL?
  @State private var ciContext = CIContext()
  @State private var selectedFilter: CIFilter?
  @State private var mlModel: MLModel?
  @State private var applyFilter = false
  @State private var applyMLModel = false
  @State private var brightness: CGFloat = 0.0
  @State private var contrast: CGFloat = 1.0
  @State private var saturation: CGFloat = 1.0
  @State private var inputEV: CGFloat = 0.0
  @State private var gamma: CGFloat = 1.0
  @State private var hue: CGFloat = 0.0
  @State private var highlightAmount: CGFloat = 1.0
  @State private var shadowAmount: CGFloat = 0.0
  @State private var temperature: CGFloat = 6500.0
  @State private var tint: CGFloat = 0.0
  @State private var whitePoint: CGFloat = 1.0
  @State private var selectedFilterName: String?
  @State private var selectedSize = "1024x576"
  @State private var player: AVPlayer?
  @State private var playerLayer: AVPlayerLayer?
  @State private var invert = false
  @State private var posterize = false
  @State private var sharpenLuminance = false
  @State private var unsharpMask = false
  @State private var edges = false
  @State private var gaborGradients = false
  
  let sizes = ["640x640", "1024x576", "576x1024", "1280x720"]
  let filters = ["CIDocumentEnhancer", "CIColorHistogram"]
  
  var body: some View {
    VStack {
      HStack {
        Button("Choose Video") {
          chooseVideo()
        }
        Button("Choose CoreML Model") {
          chooseModel()
        }
        Picker("Filter", selection: $selectedFilterName) {
          ForEach(filters, id: \.self) { filter in
            Text(filter).tag(filter as String?)
          }
        }
        .onChange(of: selectedFilterName) { newFilter in
          selectedFilter = CIFilter(name: newFilter ?? "")
          updateVideoProcessing()
        }
      }
      HStack {
        Toggle("Apply Filter", isOn: $applyFilter)
        Toggle("Apply CoreML Model", isOn: $applyMLModel)
      }
      Picker("View Size", selection: $selectedSize) {
        ForEach(sizes, id: \.self) { size in
          Text(size).tag(size)
        }
      }
      .pickerStyle(MenuPickerStyle())
      VStack {
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
        Slider(value: $gamma, in: 0.1...3.0, step: 0.1) {
          Text("Gamma")
        }
        Slider(value: $hue, in: 0...2 * .pi, step: 0.1) {
          Text("Hue")
        }
        Slider(value: $highlightAmount, in: 0...1, step: 0.1) {
          Text("Highlight Amount")
        }
        Slider(value: $shadowAmount, in: -1...1, step: 0.1) {
          Text("Shadow Amount")
        }
        Slider(value: $temperature, in: 1000...10000, step: 100) {
          Text("Temperature")
        }
        Slider(value: $tint, in: -200...200, step: 1) {
          Text("Tint")
        }
        Slider(value: $whitePoint, in: 0...2, step: 0.1) {
          Text("White Point")
        }
        Toggle("CIColorInvert", isOn: $invert)
        Toggle("CIColorPosterize", isOn: $posterize)
        Toggle("CISharpenLuminance", isOn: $sharpenLuminance)
        Toggle("CIUnsharpMask", isOn: $unsharpMask)
        Toggle("CIEdges", isOn: $edges)
        Toggle("CIGaborGradients", isOn: $gaborGradients)
      }
      CoreVideoPlayerView(videoURL: $videoURL, applyFilter: $applyFilter, selectedFilter: $selectedFilter, applyMLModel: $applyMLModel, mlModel: $mlModel, brightness: $brightness, contrast: $contrast, saturation: $saturation, inputEV: $inputEV, gamma: $gamma, hue: $hue, highlightAmount: $highlightAmount, shadowAmount: $shadowAmount, temperature: $temperature, tint: $tint, whitePoint: $whitePoint, invert: $invert, posterize: $posterize, sharpenLuminance: $sharpenLuminance, unsharpMask: $unsharpMask, edges: $edges, gaborGradients: $gaborGradients, selectedSize: $selectedSize, player: $player, playerLayer: $playerLayer, ciContext: $ciContext)
        .onChange(of: applyFilter) { _ in updateVideoProcessing() }
        .onChange(of: applyMLModel) { _ in updateVideoProcessing() }
        .onChange(of: selectedSize) { _ in updateVideoSize() }
        .onChange(of: brightness) { _ in updateVideoProcessing() }
        .onChange(of: contrast) { _ in updateVideoProcessing() }
        .onChange(of: saturation) { _ in updateVideoProcessing() }
        .onChange(of: inputEV) { _ in updateVideoProcessing() }
        .onChange(of: gamma) { _ in updateVideoProcessing() }
        .onChange(of: hue) { _ in updateVideoProcessing() }
        .onChange(of: highlightAmount) { _ in updateVideoProcessing() }
        .onChange(of: shadowAmount) { _ in updateVideoProcessing() }
        .onChange(of: temperature) { _ in updateVideoProcessing() }
        .onChange(of: tint) { _ in updateVideoProcessing() }
        .onChange(of: whitePoint) { _ in updateVideoProcessing() }
        .onChange(of: invert) { _ in updateVideoProcessing() }
        .onChange(of: posterize) { _ in updateVideoProcessing() }
        .onChange(of: sharpenLuminance) { _ in updateVideoProcessing() }
        .onChange(of: unsharpMask) { _ in updateVideoProcessing() }
        .onChange(of: edges) { _ in updateVideoProcessing() }
        .onChange(of: gaborGradients) { _ in updateVideoProcessing() }
    }
    .padding()
  }
  
  private func chooseVideo() {
    let panel = NSOpenPanel()
    panel.allowedFileTypes = ["mp4", "mov"]
    if panel.runModal() == .OK {
      videoURL = panel.url
      setupPlayer()
    }
  }
  
  private func chooseModel() {
    let panel = NSOpenPanel()
    panel.allowedFileTypes = ["mlmodel"]
    if panel.runModal() == .OK, let url = panel.url {
      do {
        mlModel = try MLModel(contentsOf: url)
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
    guard let playerLayer = playerLayer, let size = sizes.first(where: { $0 == selectedSize }) else { return }
    
    let dimensions = size.split(separator: "x").compactMap { Int($0) }
    if dimensions.count == 2 {
      let width = CGFloat(dimensions[0])
      let height = CGFloat(dimensions[1])
      playerLayer.frame.size = CGSize(width: width, height: height)
    }
  }
  
  private func setupPlayer() {
    guard let videoURL = videoURL else { return }
    let asset = AVAsset(url: videoURL)
    let playerItem = AVPlayerItem(asset: asset)
    player = AVPlayer(playerItem: playerItem)
    
    let videoComposition = AVVideoComposition(asset: asset) { request in
      var ciImage = request.sourceImage.clampedToExtent()
      
      if applyFilter {
        if let selectedFilter = selectedFilter {
          selectedFilter.setValue(ciImage, forKey: kCIInputImageKey)
          ciImage = selectedFilter.outputImage ?? ciImage
        }
        
        if invert {
          let filter = CIFilter(name: "CIColorInvert")
          filter?.setValue(ciImage, forKey: kCIInputImageKey)
          ciImage = filter?.outputImage ?? ciImage
        }
        
        if posterize {
          let filter = CIFilter(name: "CIColorPosterize")
          filter?.setValue(ciImage, forKey: kCIInputImageKey)
          ciImage = filter?.outputImage ?? ciImage
        }
        
        if sharpenLuminance {
          let filter = CIFilter(name: "CISharpenLuminance")
          filter?.setValue(ciImage, forKey: kCIInputImageKey)
          ciImage = filter?.outputImage ?? ciImage
        }
        
        if unsharpMask {
          let filter = CIFilter(name: "CIUnsharpMask")
          filter?.setValue(ciImage, forKey: kCIInputImageKey)
          ciImage = filter?.outputImage ?? ciImage
        }
        
        if edges {
          let filter = CIFilter(name: "CIEdges")
          filter?.setValue(ciImage, forKey: kCIInputImageKey)
          ciImage = filter?.outputImage ?? ciImage
        }
        
        if gaborGradients {
          let filter = CIFilter(name: "CIGaborGradients")
          filter?.setValue(ciImage, forKey: kCIInputImageKey)
          ciImage = filter?.outputImage ?? ciImage
        }
        
        let colorControlsFilter = CIFilter(name: "CIColorControls")
        colorControlsFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        colorControlsFilter?.setValue(brightness, forKey: kCIInputBrightnessKey)
        colorControlsFilter?.setValue(contrast, forKey: kCIInputContrastKey)
        colorControlsFilter?.setValue(saturation, forKey: kCIInputSaturationKey)
        ciImage = colorControlsFilter?.outputImage ?? ciImage
        
        let gammaFilter = CIFilter(name: "CIGammaAdjust")
        gammaFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        gammaFilter?.setValue(gamma, forKey: "inputPower")
        ciImage = gammaFilter?.outputImage ?? ciImage
        
        let hueFilter = CIFilter(name: "CIHueAdjust")
        hueFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        hueFilter?.setValue(hue, forKey: kCIInputAngleKey)
        ciImage = hueFilter?.outputImage ?? ciImage
        
        let highlightShadowFilter = CIFilter(name: "CIHighlightShadowAdjust")
        highlightShadowFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        highlightShadowFilter?.setValue(highlightAmount, forKey: "inputHighlightAmount")
        highlightShadowFilter?.setValue(shadowAmount, forKey: "inputShadowAmount")
        ciImage = highlightShadowFilter?.outputImage ?? ciImage
        
        let temperatureAndTintFilter = CIFilter(name: "CITemperatureAndTint")
        temperatureAndTintFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        temperatureAndTintFilter?.setValue(CIVector(x: temperature, y: tint), forKey: "inputNeutral")
        ciImage = temperatureAndTintFilter?.outputImage ?? ciImage
        
        let whitePointAdjustFilter = CIFilter(name: "CIWhitePointAdjust")
        whitePointAdjustFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        whitePointAdjustFilter?.setValue(CIColor(red: CGFloat(Float(whitePoint)), green: CGFloat(Float(whitePoint)), blue: CGFloat(Float(whitePoint))), forKey: kCIInputColorKey)
        ciImage = whitePointAdjustFilter?.outputImage ?? ciImage
      }
      
      if let mlModel = mlModel, applyMLModel {
        let mlFilter = CIFilter(name: "CICoreMLModelFilter")!
        mlFilter.setValue(mlModel, forKey: "inputModel")
        mlFilter.setValue(ciImage, forKey: kCIInputImageKey)
        ciImage = mlFilter.outputImage ?? ciImage
      }
      
      request.finish(with: ciImage, context: nil)
    }
    
    playerItem.videoComposition = videoComposition
    
    if playerLayer == nil {
      playerLayer = AVPlayerLayer(player: player)
      playerLayer?.frame = .zero
    }
    
    playerLayer?.player = player
  }
}

struct CoreVideoPlayerView: NSViewRepresentable {
  @Binding var videoURL: URL?
  @Binding var applyFilter: Bool
  @Binding var selectedFilter: CIFilter?
  @Binding var applyMLModel: Bool
  @Binding var mlModel: MLModel?
  @Binding var brightness: CGFloat
  @Binding var contrast: CGFloat
  @Binding var saturation: CGFloat
  @Binding var inputEV: CGFloat
  @Binding var gamma: CGFloat
  @Binding var hue: CGFloat
  @Binding var highlightAmount: CGFloat
  @Binding var shadowAmount: CGFloat
  @Binding var temperature: CGFloat
  @Binding var tint: CGFloat
  @Binding var whitePoint: CGFloat
  @Binding var invert: Bool
  @Binding var posterize: Bool
  @Binding var sharpenLuminance: Bool
  @Binding var unsharpMask: Bool
  @Binding var edges: Bool
  @Binding var gaborGradients: Bool
  @Binding var selectedSize: String
  @Binding var player: AVPlayer?
  @Binding var playerLayer: AVPlayerLayer?
  @Binding var ciContext: CIContext
  
  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    view.wantsLayer = true
    return view
  }
  
  func updateNSView(_ nsView: NSView, context: Context) {
    guard let playerLayer = playerLayer else { return }
    
    if playerLayer.superlayer == nil {
      playerLayer.frame = nsView.bounds
      nsView.layer?.addSublayer(playerLayer)
    }
    
    player?.play()
  }
}

