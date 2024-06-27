import Cocoa
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

import Cocoa
import SwiftUI
import Vision

struct ForensicImageProcessor {
  let context = CIContext()
  
  func detectFaceLandmarks(image: CIImage, completion: @escaping (VNFaceObservation?) -> Void) {
    let request = VNDetectFaceLandmarksRequest { request, error in
      guard let results = request.results as? [VNFaceObservation], let faceObservation = results.first else {
        completion(nil)
        return
      }
      completion(faceObservation)
    }
    
    let handler = VNImageRequestHandler(ciImage: image, options: [:])
    do {
      try handler.perform([request])
    } catch {
      print("Failed to perform landmarks request: \(error)")
      completion(nil)
    }
  }
  
  func alignAndCropFace(image: CIImage, faceObservation: VNFaceObservation) -> CIImage? {
    guard let landmarks = faceObservation.landmarks,
          let leftEye = landmarks.leftEye?.normalizedPoints,
          let rightEye = landmarks.rightEye?.normalizedPoints,
          let nose = landmarks.nose?.normalizedPoints else {
      return nil
    }
    
    // Calculate eye line
    let leftEyePoint = CGPoint(x: leftEye[0].x * image.extent.width, y: leftEye[0].y * image.extent.height)
    let rightEyePoint = CGPoint(x: rightEye[0].x * image.extent.width, y: rightEye[0].y * image.extent.height)
    let eyeLine = (start: leftEyePoint, end: rightEyePoint)
    
    // Calculate nose point
    let nosePoint = CGPoint(x: nose[0].x * image.extent.width, y: nose[0].y * image.extent.height)
    
    // Calculate angle to align eyes horizontally
    let angle = atan2(eyeLine.end.y - eyeLine.start.y, eyeLine.end.x - eyeLine.start.x)
    let transform = CGAffineTransform(rotationAngle: -angle)
    
    // Apply transformation
    let transformedImage = image.transformed(by: transform)
    let transformHandler = VNImageRequestHandler(ciImage: transformedImage, options: [:])
    
    // Get bounding box for the face
    let faceBoundingBox = VNImageRectForNormalizedRect(faceObservation.boundingBox, Int(image.extent.width), Int(image.extent.height))
    
    // Crop the face
    let croppedImage = transformedImage.cropped(to: faceBoundingBox)
    
    return croppedImage
  }
  
  func compareImages(image1: CIImage, image2: CIImage, threshold: Float) -> NSImage? {
    // Ensure images have the same dimensions
    guard image1.extent == image2.extent else { return nil }
    
    let diffFilter = CIFilter.differenceBlendMode()
    diffFilter.inputImage = image1
    diffFilter.backgroundImage = image2
    
    guard let diffOutput = diffFilter.outputImage else {
      return nil
    }
    
    // Apply threshold to the difference image
    let thresholdFilter = CIFilter.colorMatrix()
    thresholdFilter.inputImage = diffOutput
    thresholdFilter.rVector = CIVector(x: 0, y: 0, z: 0, w: 0)
    thresholdFilter.gVector = CIVector(x: 0, y: 0, z: 0, w: 0)
    thresholdFilter.bVector = CIVector(x: 0, y: 0, z: 0, w: 0)
    thresholdFilter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1 - CGFloat((CGFloat(threshold) / 100)))
    
    guard let thresholdOutput = thresholdFilter.outputImage else {
      return nil
    }
    
    // Apply transparency based on the threshold
    if let cgImage = context.createCGImage(thresholdOutput, from: thresholdOutput.extent) {
      return NSImage(cgImage: cgImage, size: thresholdOutput.extent.size)
    }
    return nil
  }
}
import SwiftUI

class ImageModel: ObservableObject {
  @Published var images: [NSImage] = []
  @Published var processedImage: NSImage?
  @Published var threshold: Float = 50.0 // Default threshold value
  @Published var outputDirectory: URL?
  
  let processor = ForensicImageProcessor()
  
  func compareNextImage() {
    guard images.count > 1 else { return }
    
    for i in 0..<(images.count - 1) {
      let ciImage1 = CIImage(data: images[i].tiffRepresentation!)
      let ciImage2 = CIImage(data: images[i + 1].tiffRepresentation!)
      
      if let result = processor.compareImages(image1: ciImage1!, image2: ciImage2!, threshold: threshold) {
        processedImage = result
        break
      }
    }
  }
  
  func alignAndCropFaces() {
    guard let outputDirectory = outputDirectory else { return }
    for image in images {
      let ciImage = CIImage(data: image.tiffRepresentation!)!
      processor.detectFaceLandmarks(image: ciImage) { [weak self] faceObservation in
        guard let self = self, let faceObservation = faceObservation else { return }
        if let alignedImage = self.processor.alignAndCropFace(image: ciImage, faceObservation: faceObservation) {
          let outputPath = outputDirectory.appendingPathComponent(UUID().uuidString + ".png")
          if let cgImage = self.processor.context.createCGImage(alignedImage, from: alignedImage.extent) {
            let nsImage = NSImage(cgImage: cgImage, size: alignedImage.extent.size)
            if let tiffData = nsImage.tiffRepresentation, let bitmapImage = NSBitmapImageRep(data: tiffData) {
              let pngData = bitmapImage.representation(using: .png, properties: [:])
              try? pngData?.write(to: outputPath)
            }
          }
        }
      }
    }
  }
}

struct ForensicView: View {
  @StateObject var imageModel = ImageModel()
  
  var body: some View {
    VStack {
      ScrollView(.horizontal) {
        HStack {
          ForEach(imageModel.images, id: \.self) { image in
            Image(nsImage: image)
              .resizable()
              .scaledToFit()
              .frame(width: 100, height: 100)
          }
        }
      }
      HStack {
        Button("Select Images") {
          selectImages { images in
            imageModel.images = images
          }
        }
        Button("Select Output Directory") {
          selectOutputDirectory { url in
            imageModel.outputDirectory = url
          }
        }
      }
      VStack {
        Text("Threshold: \(Int(imageModel.threshold))")
        Slider(value: $imageModel.threshold, in: 0...100)
      }
      .padding()
      Button("Compare Next Images") {
        imageModel.compareNextImage()
      }
      Button("Align and Crop Faces") {
        imageModel.alignAndCropFaces()
      }
      if let processedImage = imageModel.processedImage {
        Image(nsImage: processedImage)
          .resizable()
          .scaledToFit()
          .frame(width: 400, height: 400)
      }
    }
    .padding()
  }
  
  func selectImages(completion: @escaping ([NSImage]) -> Void) {
    let panel = NSOpenPanel()
    panel.allowedFileTypes = ["png", "jpg", "jpeg"]
    panel.allowsMultipleSelection = true
    panel.begin { response in
      if response == .OK {
        let images = panel.urls.compactMap { url -> NSImage? in
          return NSImage(contentsOf: url)
        }
        completion(images)
      }
    }
  }
  
  func selectOutputDirectory(completion: @escaping (URL) -> Void) {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    panel.begin { response in
      if response == .OK, let url = panel.url {
        completion(url)
      }
    }
  }
}
