import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

class ImageModel: ObservableObject {
  @Published var images: [NSImage] = []
  @Published var processedImage: NSImage?
  @Published var previewImage: NSImage?
  @Published var outputDirectory: URL?
  @Published var statusText: String = ""
  @Published var isProcessing: Bool = false
  
  // Filter settings as regular properties
  var exposure: CGFloat = 0.0
  var brightness: CGFloat = 0.0
  var contrast: CGFloat = 1.0
  var saturation: CGFloat = 1.0
  var sharpness: CGFloat = 0.4
  var highlights: CGFloat = 1.0
  var shadows: CGFloat = 0.0
  var temperature: CGFloat = 6500.0
  var tint: CGFloat = 0.0
  var sepia: CGFloat = 0.0
  var gamma: CGFloat = 1.0
  var hue: CGFloat = 0.0
  var whitePoint: CGFloat = 1.0
  var bumpRadius: CGFloat = 300.0
  var bumpScale: CGFloat = 0.5
  var pixelate: CGFloat = 10.0
  var convolution: [CGFloat] = [0, 0, 0, 0, 1, 0, 0, 0, 0]
  
  let context: CIContext = CIContext()
  
  func applyFilters() {
    guard let originalImage: NSImage = images.first,
          let tiffData: Data = originalImage.tiffRepresentation,
          let ciImage: CIImage = CIImage(data: tiffData) else { return }
    
    var currentImage: CIImage = ciImage
    
    currentImage = applyColorControls(inputImage: currentImage)
    currentImage = applyExposure(inputImage: currentImage)
    currentImage = applyGamma(inputImage: currentImage)
    currentImage = applyHue(inputImage: currentImage)
    currentImage = applyTemperatureAndTint(inputImage: currentImage)
    currentImage = applyWhitePoint(inputImage: currentImage)
    currentImage = applySepia(inputImage: currentImage)
    currentImage = applySharpness(inputImage: currentImage)
    currentImage = applyHighlightShadowAdjust(inputImage: currentImage)
    currentImage = applyBumpDistortion(inputImage: currentImage)
    currentImage = applyPixelate(inputImage: currentImage)
    currentImage = applyConvolution(inputImage: currentImage)
    
    if let cgImage: CGImage = context.createCGImage(currentImage, from: currentImage.extent) {
      processedImage = NSImage(cgImage: cgImage, size: currentImage.extent.size)
    }
  }
  
  private func applyColorControls(inputImage: CIImage) -> CIImage {
    let filter = CIFilter.colorControls()
    filter.inputImage = inputImage
    filter.brightness = Float(brightness)
    filter.contrast = Float(contrast)
    filter.saturation = Float(saturation)
    return filter.outputImage ?? inputImage
  }
  
  private func applyExposure(inputImage: CIImage) -> CIImage {
    let filter = CIFilter.exposureAdjust()
    filter.inputImage = inputImage
    filter.ev = Float(exposure)
    return filter.outputImage ?? inputImage
  }
  
  private func applyGamma(inputImage: CIImage) -> CIImage {
    let filter = CIFilter.gammaAdjust()
    filter.inputImage = inputImage
    filter.power = Float(gamma)
    return filter.outputImage ?? inputImage
  }
  
  private func applyHue(inputImage: CIImage) -> CIImage {
    let filter = CIFilter.hueAdjust()
    filter.inputImage = inputImage
    filter.angle = Float(hue)
    return filter.outputImage ?? inputImage
  }
  
  private func applyTemperatureAndTint(inputImage: CIImage) -> CIImage {
    let filter = CIFilter.temperatureAndTint()
    filter.inputImage = inputImage
    filter.neutral = CIVector(x: CGFloat(temperature), y: 0)
    filter.targetNeutral = CIVector(x: CGFloat(tint), y: 0)
    return filter.outputImage ?? inputImage
  }
  
  private func applyWhitePoint(inputImage: CIImage) -> CIImage {
    let filter = CIFilter.whitePointAdjust()
    filter.inputImage = inputImage
    filter.color = CIColor(red: CGFloat(Float(whitePoint)), green: CGFloat(Float(whitePoint)), blue: CGFloat(Float(whitePoint)))
    return filter.outputImage ?? inputImage
  }
  
  private func applySepia(inputImage: CIImage) -> CIImage {
    let filter = CIFilter.sepiaTone()
    filter.inputImage = inputImage
    filter.intensity = Float(sepia)
    return filter.outputImage ?? inputImage
  }
  
  private func applySharpness(inputImage: CIImage) -> CIImage {
    let filter = CIFilter.sharpenLuminance()
    filter.inputImage = inputImage
    filter.sharpness = Float(sharpness)
    return filter.outputImage ?? inputImage
  }
  
  private func applyHighlightShadowAdjust(inputImage: CIImage) -> CIImage {
    let filter = CIFilter.highlightShadowAdjust()
    filter.inputImage = inputImage
    filter.highlightAmount = Float(highlights)
    filter.shadowAmount = Float(shadows)
    return filter.outputImage ?? inputImage
  }
  
  private func applyBumpDistortion(inputImage: CIImage) -> CIImage {
    let filter = CIFilter.bumpDistortion()
    filter.inputImage = inputImage
    filter.radius = Float(bumpRadius)
    filter.scale = Float(bumpScale)
    return filter.outputImage ?? inputImage
  }
  
  private func applyPixelate(inputImage: CIImage) -> CIImage {
    let filter = CIFilter.pixellate()
    filter.inputImage = inputImage
    filter.scale = Float(pixelate)
    return filter.outputImage ?? inputImage
  }
  
  private func applyConvolution(inputImage: CIImage) -> CIImage {
    let filter = CIFilter.convolution3X3()
    let convolutionFloat: [CGFloat] = convolution.map { CGFloat($0) }
    filter.inputImage = inputImage
    filter.weights = CIVector(values: convolutionFloat, count: 9)
    return filter.outputImage ?? inputImage
  }
  
  func updateFilters() {
    self.objectWillChange.send()
    applyFilters()
  }
  
  func resetFilters() {
    exposure = 0.0
    brightness = 0.0
    contrast = 1.0
    saturation = 1.0
    sharpness = 0.4
    highlights = 1.0
    shadows = 0.0
    temperature = 6500.0
    tint = 0.0
    sepia = 0.0
    gamma = 1.0
    hue = 0.0
    whitePoint = 1.0
    bumpRadius = 300.0
    bumpScale = 0.5
    pixelate = 10.0
    convolution = [0, 0, 0, 0, 1, 0, 0, 0, 0]
    updateFilters()
  }
  
  func saveChanges() {
    guard let outputDirectory = outputDirectory, let processedImage = processedImage else { return }
    let outputPath = outputDirectory.appendingPathComponent(UUID().uuidString + ".png")
    if let tiffData = processedImage.tiffRepresentation, let bitmapImage = NSBitmapImageRep(data: tiffData) {
      let pngData = bitmapImage.representation(using: .png, properties: [:])
      try? pngData?.write(to: outputPath)
    }
  }
  
  func applyToAll() {
    for image in images {
      guard let tiffData = image.tiffRepresentation, let ciImage = CIImage(data: tiffData) else { continue }
      var currentImage = ciImage
      currentImage = applyColorControls(inputImage: currentImage)
      currentImage = applyExposure(inputImage: currentImage)
      currentImage = applyGamma(inputImage: currentImage)
      currentImage = applyHue(inputImage: currentImage)
      currentImage = applyTemperatureAndTint(inputImage: currentImage)
      currentImage = applyWhitePoint(inputImage: currentImage)
      currentImage = applySepia(inputImage: currentImage)
      currentImage = applySharpness(inputImage: currentImage)
      currentImage = applyHighlightShadowAdjust(inputImage: currentImage)
      currentImage = applyBumpDistortion(inputImage: currentImage)
      currentImage = applyPixelate(inputImage: currentImage)
      currentImage = applyConvolution(inputImage: currentImage)
      
      if let cgImage = context.createCGImage(currentImage, from: currentImage.extent) {
        let processedImage = NSImage(cgImage: cgImage, size: currentImage.extent.size)
        saveImage(image: processedImage)
      }
    }
  }
  func saveImage(image: NSImage) {
    let panel = NSSavePanel()
    panel.allowedFileTypes = ["png"]
    panel.begin { response in
      if response == .OK, let url: URL = panel.url {
        if let tiffData: Data = image.tiffRepresentation, let bitmapImage: NSBitmapImageRep = NSBitmapImageRep(data: tiffData) {
          let pngData: Data? = bitmapImage.representation(using: .png, properties: [:])
          try? pngData?.write(to: url)
        }
      }
    }
  }
  
  func saveAll() {
    for image in images {
      guard let tiffData = image.tiffRepresentation, let ciImage = CIImage(data: tiffData) else { continue }
      var currentImage = ciImage
      currentImage = applyColorControls(inputImage: currentImage)
      currentImage = applyExposure(inputImage: currentImage)
      currentImage = applyGamma(inputImage: currentImage)
      currentImage = applyHue(inputImage: currentImage)
      currentImage = applyTemperatureAndTint(inputImage: currentImage)
      currentImage = applyWhitePoint(inputImage: currentImage)
      currentImage = applySepia(inputImage: currentImage)
      currentImage = applySharpness(inputImage: currentImage)
      currentImage = applyHighlightShadowAdjust(inputImage: currentImage)
      currentImage = applyBumpDistortion(inputImage: currentImage)
      currentImage = applyPixelate(inputImage: currentImage)
      currentImage = applyConvolution(inputImage: currentImage)
      
      if let cgImage = context.createCGImage(currentImage, from: currentImage.extent) {
        let processedImage = NSImage(cgImage: cgImage, size: currentImage.extent.size)
        saveImage(image: processedImage)
      }
    }
  }
}
