import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

class ImageModel: ObservableObject {
  @Published var images: [NSImage] = []
  @Published var processedImage: NSImage?
  @Published var outputDirectory: URL?
  @Published var statusText: String = ""
  @Published var isProcessing: Bool = false
  
  // Filter settings
  @Published var exposure: CGFloat = 0.0
  @Published var brightness: CGFloat = 0.0
  @Published var contrast: CGFloat = 1.0
  @Published var saturation: CGFloat = 1.0
  @Published var sharpness: CGFloat = 0.4
  @Published var highlights: CGFloat = 1.0
  @Published var shadows: CGFloat = 0.0
  @Published var temperature: CGFloat = 6500.0
  @Published var tint: CGFloat = 0.0
  @Published var sepia: CGFloat = 0.0
  @Published var gamma: CGFloat = 1.0
  @Published var hue: CGFloat = 0.0
  @Published var whitePoint: CGFloat = 1.0
  @Published var bumpRadius: CGFloat = 300.0
  @Published var bumpScale: CGFloat = 0.5
  @Published var pixelate: CGFloat = 10.0
  @Published var convolution: [CGFloat] = [0, 0, 0, 0, 1, 0, 0, 0, 0]
  
  let context = CIContext()
  
  func applyFilters() {
    guard let originalImage = images.first, let ciImage = CIImage(data: originalImage.tiffRepresentation!) else { return }
    
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
    filter.neutral = CIVector(x: temperature, y: 0)
    filter.targetNeutral = CIVector(x: tint, y: 0)
    return filter.outputImage ?? inputImage
  }
  
  private func applyWhitePoint(inputImage: CIImage) -> CIImage {
    let filter = CIFilter.whitePointAdjust()
    filter.inputImage = inputImage
    filter.color = CIColor(red: whitePoint, green: whitePoint, blue: whitePoint)
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
    let convolutionFloat = convolution.map { CGFloat($0) }
    filter.inputImage = inputImage
    filter.weights = CIVector(values: convolutionFloat, count: 9)
    return filter.outputImage ?? inputImage
  }
}
