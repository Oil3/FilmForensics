//
//  CoreVideoFiltersView.swift
//  FilmForensics
//
//  Created by Almahdi Morris on 1/7/24.
//

import SwiftUI
import AVFoundation
import CoreImage
import CoreML
import AVKit

struct CoreVideoFiltersView: View {
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
  @State private var playerView: AVPlayerView?
  @State private var invert = false
  @State private var posterize = false
  @State private var sharpenLuminance = false
  @State private var unsharpMask = false
  @State private var edges = false
  @State private var gaborGradients = false
  @AppStorage("filterPreset") private var filterPresetData: Data?
  
  let sizes = ["640x640", "1024x576", "576x1024", "1280x720"]
  let filters = ["CIDocumentEnhancer", "CIColorHistogram"]
  
  var body: some View {
    NavigationSplitView(sidebar: {
      leftColumn
    }, detail: {
      HStack {
        VStack {
          videoPlayerView
          controlButtons
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        rightColumn
      }
    })
  }
  
  private var leftColumn: some View {
    VStack(alignment: .leading) {
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
        applyCurrentFilters()
      }
      Toggle("Apply Filter", isOn: $applyFilter)
      Toggle("Apply CoreML Model", isOn: $applyMLModel)
      Picker("View Size", selection: $selectedSize) {
        ForEach(sizes, id: \.self) { size in
          Text(size).tag(size)
        }
      }
      .pickerStyle(MenuPickerStyle())
      Spacer()
    }
    .padding()
    .frame(width: 200)
  }
  
  private var videoPlayerView: some View {
    ZStack {
      if let playerView = playerView {
        CoreVideoPlayerView(videoURL: $videoURL, applyFilter: $applyFilter, selectedFilter: $selectedFilter, applyMLModel: $applyMLModel, mlModel: $mlModel, brightness: $brightness, contrast: $contrast, saturation: $saturation, inputEV: $inputEV, gamma: $gamma, hue: $hue, highlightAmount: $highlightAmount, shadowAmount: $shadowAmount, temperature: $temperature, tint: $tint, whitePoint: $whitePoint, invert: $invert, posterize: $posterize, sharpenLuminance: $sharpenLuminance, unsharpMask: $unsharpMask, edges: $edges, gaborGradients: $gaborGradients, selectedSize: $selectedSize, player: $player, playerView: $playerView, ciContext: $ciContext)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        Text("Load a video to start")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color.black)
      }
    }
    .padding()
  }
  
  private var rightColumn: some View {
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
      Spacer()
    }
    .padding()
    .frame(width: 200)
  }
  
  private var controlButtons: some View {
    HStack {
      Button("Reset") {
        resetFilters()
      }
      Button("Save Preset") {
        savePreset()
      }
      Button("Restore Preset") {
        restorePreset()
      }
      Button("Play") {
        player?.play()
      }
      Button("Pause") {
        player?.pause()
      }
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
    applyCurrentFilters()
  }
  
  private func applyCurrentFilters() {
    guard let player = player else { return }
    player.currentItem?.videoComposition = AVVideoComposition(asset: player.currentItem!.asset) { request in
      var ciImage = request.sourceImage.clampedToExtent()
      ciImage = self.applyFilters(to: ciImage)
      request.finish(with: ciImage, context: self.ciContext)
    }
  }
  
  private func applyFilters(to image: CIImage) -> CIImage {
    var ciImage = image
    
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
    
    return ciImage
  }
  
  private func resetFilters() {
    brightness = 0.0
    contrast = 1.0
    saturation = 1.0
    inputEV = 0.0
    gamma = 1.0
    hue = 0.0
    highlightAmount = 1.0
    shadowAmount = 0.0
    temperature = 6500.0
    tint = 0.0
    whitePoint = 1.0
    invert = false
    posterize = false
    sharpenLuminance = false
    unsharpMask = false
    edges = false
    gaborGradients = false
    applyCurrentFilters()
  }
  
  private func savePreset() {
    let preset = FilterPreset(
      brightness: brightness,
      contrast: contrast,
      saturation: saturation,
      inputEV: inputEV,
      gamma: gamma,
      hue: hue,
      highlightAmount: highlightAmount,
      shadowAmount: shadowAmount,
      temperature: temperature,
      tint: tint,
      whitePoint: whitePoint,
      invert: invert,
      posterize: posterize,
      sharpenLuminance: sharpenLuminance,
      unsharpMask: unsharpMask,
      edges: edges,
      gaborGradients: gaborGradients
    )
    if let data = try? JSONEncoder().encode(preset) {
      filterPresetData = data
    }
  }
  
  private func restorePreset() {
    guard let data = filterPresetData, let preset = try? JSONDecoder().decode(FilterPreset.self, from: data) else { return }
    brightness = preset.brightness
    contrast = preset.contrast
    saturation = preset.saturation
    inputEV = preset.inputEV
    gamma = preset.gamma
    hue = preset.hue
    highlightAmount = preset.highlightAmount
    shadowAmount = preset.shadowAmount
    temperature = preset.temperature
    tint = preset.tint
    whitePoint = preset.whitePoint
    invert = preset.invert
    posterize = preset.posterize
    sharpenLuminance = preset.sharpenLuminance
    unsharpMask = preset.unsharpMask
    edges = preset.edges
    gaborGradients = preset.gaborGradients
    applyCurrentFilters()
  }
  
  private func setupPlayer() {
    guard let videoURL = videoURL else { return }
    let asset = AVAsset(url: videoURL)
    let playerItem = AVPlayerItem(asset: asset)
    player = AVPlayer(playerItem: playerItem)
    playerView = AVPlayerView()
    playerView?.player = player
    
    let videoComposition = AVVideoComposition(asset: asset) { request in
      var ciImage = request.sourceImage.clampedToExtent()
      ciImage = self.applyFilters(to: ciImage)
      request.finish(with: ciImage, context: self.ciContext)
    }
    
    playerItem.videoComposition = videoComposition
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
  @Binding var playerView: AVPlayerView?
  @Binding var ciContext: CIContext
  
  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    view.wantsLayer = true
    return view
  }
  
  func updateNSView(_ nsView: NSView, context: Context) {
    guard let playerView = playerView else { return }
    
    if playerView.superview == nil {
      playerView.frame = nsView.bounds
      nsView.addSubview(playerView)
    } else {
      playerView.frame = nsView.bounds
    }
    
    // playerView.player?.pause()
  }
}

struct FilterPreset: Codable {
  let brightness: CGFloat
  let contrast: CGFloat
  let saturation: CGFloat
  let inputEV: CGFloat
  let gamma: CGFloat
  let hue: CGFloat
  let highlightAmount: CGFloat
  let shadowAmount: CGFloat
  let temperature: CGFloat
  let tint: CGFloat
  let whitePoint: CGFloat
  let invert: Bool
  let posterize: Bool
  let sharpenLuminance: Bool
  let unsharpMask: Bool
  let edges: Bool
  let gaborGradients: Bool
}
