//
//  ImageModel.swift
//  FilmForensics
//
//  Created by Almahdi Morris on 27/6/24.
//
import SwiftUI

class ImageModel: ObservableObject {
  @Published var images: [NSImage] = []
  @Published var processedImages: [NSImage] = []
  @Published var processedImage: NSImage?
  @Published var threshold: Float = 50.0 // Default threshold value
  @Published var outputDirectory: URL?
  @Published var statusText: String = ""
  @Published var isProcessing: Bool = false
  
  let processor = ForensicImageProcessor()
  
  func compareNextImage() {
    guard images.count > 1 else {
      statusText = "Not enough images to compare."
      return
    }
    
    for i in 0..<(images.count - 1) {
      let ciImage1 = CIImage(data: images[i].tiffRepresentation!)
      let ciImage2 = CIImage(data: images[i + 1].tiffRepresentation!)
      
      if let result = processor.compareImages(image1: ciImage1!, image2: ciImage2!, threshold: threshold) {
        processedImage = result
        processedImages.append(result)
        statusText = "Comparison completed."
        return
      }
    }
    statusText = "Comparison failed."
  }
  
  func alignAndCropFaces() {
    guard let outputDirectory = outputDirectory else {
      statusText = "Output directory not selected."
      return
    }
    
    isProcessing = true
    statusText = "Processing images..."
    
    DispatchQueue.global(qos: .userInitiated).async {
      for image in self.images {
        let ciImage = CIImage(data: image.tiffRepresentation!)!
        self.processor.detectFaceLandmarks(image: ciImage) { [weak self] faceObservation in
          guard let self = self, let faceObservation = faceObservation else { return }
          if let alignedImage = self.processor.alignAndCropFace(image: ciImage, faceObservation: faceObservation) {
            let outputPath = outputDirectory.appendingPathComponent(UUID().uuidString + ".png")
            if let cgImage = self.processor.context.createCGImage(alignedImage, from: alignedImage.extent) {
              let nsImage = NSImage(cgImage: cgImage, size: alignedImage.extent.size)
              if let tiffData = nsImage.tiffRepresentation, let bitmapImage = NSBitmapImageRep(data: tiffData) {
                let pngData = bitmapImage.representation(using: .png, properties: [:])
                try? pngData?.write(to: outputPath)
                DispatchQueue.main.async {
                  self.processedImages.append(nsImage)
                }
              }
            }
          }
        }
      }
      DispatchQueue.main.async {
        self.isProcessing = false
        self.statusText = "Face alignment and cropping completed."
      }
    }
  }
}
