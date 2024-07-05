
//import SwiftUI
//import CoreML
//import Vision
//
//struct MainImageView: View {
//  @StateObject var imageModel = ImageModel()
//  
//  var body: some View {
//    NavigationSplitView {
//      ImageGalleryView(imageModel: imageModel)
//    } detail: {
//      ImageContentView(imageModel: imageModel)
//    }
//  }
//}
//
//struct ImageGalleryView: View {
//  @ObservedObject var imageModel: ImageModel
//  
//  var body: some View {
//    VStack {
//      Button("Add Images") {
//        selectImages { images in
//          imageModel.images.append(contentsOf: images)
//        }
//      }
//      Button("Select Model") {
//        selectModel { selectedModel in
//          imageModel.selectedModel = selectedModel
//        }
//      }
//      List {
//        ForEach(Array(imageModel.images.enumerated()), id: \.element) { index, image in
//          Image(nsImage: image)
//            .resizable()
//            .scaledToFit()
//            .frame(width: 80, height: 80)
//            .border(image == imageModel.previewImage ? Color.blue : Color.clear, width: 2)
//            .contextMenu {
//              Button("Delete") {
//                imageModel.previewImage = image
//                
//                imageModel.images.remove(at: index)
//              }
//              .onTapGesture(count: 2) {
//                imageModel.previewImage = image
//                imageModel.detectionsF = []  // Clear bounding boxes when changing image
//              }
//            }
//              Button("Run Prediction") {
//                imageModel.previewImage = image
//
//                runPrediction(on: image, imageModel: imageModel)
//              }
//
//        }
//      }
//      Button("Clear All") {
//        imageModel.images.removeAll()
//        imageModel.previewImage = nil
//        imageModel.detectionsF = []
//      }
//    }
//  }
//  
//  private func runPrediction(on image: NSImage, imageModel: ImageModel) {
//    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
//          let model = imageModel.selectedModel else { return }
//    
//    do {
//      let model = try VNCoreMLModel(for: model)
//      let request = VNCoreMLRequest(model: model) { request, error in
//        if let results = request.results as? [VNRecognizedObjectObservation] {
//          DispatchQueue.main.async {
//            imageModel.detections = results.map { Detection(boundingBox: $0.boundingBox, identifier: $0.labels.first?.identifier ?? "Unknown", confidence: $0.confidence) }
//          }
//        } else if let results = request.results as? [VNPixelBufferObservation] {
//          DispatchQueue.main.async {
//            if let resultBuffer = results.first?.pixelBuffer {
//              imageModel.generatedImage = NSImage(cgImage: CIImage(cvPixelBuffer: resultBuffer).cgImage!, size: NSSize(width: cgImage.width, height: cgImage.height))
//            }
//          }
//        }
//      }
//      
//      let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
//      try handler.perform([request])
//    } catch {
//      print("Failed to perform prediction: \(error)")
//    }
//  }
//}
//
//struct ImageContentView: View {
//  @ObservedObject var imageModel: ImageModel
//  
//  var body: some View {
//    ScrollView {
//      if let previewImage = imageModel.previewImage {
//        GeometryReader { geo in
//          ZStack {
//            Image(nsImage: previewImage)
//              .resizable()
//              .scaledToFit()
//              .frame(width: geo.size.width, height: geo.size.height)
//            
//            ForEach(imageModel.detectionsF) { detection in
//              drawBoundingBox(for: detection, in: geo.size, color: .red)
//            }
//          }
//        }
//        .frame(width: 640, height: 640, alignment: .center)
//      } else if let generatedImage = imageModel.generatedImage {
//        Image(nsImage: generatedImage)
//          .resizable()
//          .scaledToFit()
//          .frame(width: 640, height: 640, alignment: .center)
//      } else {
//        Text("Select an image to preview")
//      }
//    }
//    .frame(width: 640, height: 640, alignment: .center)
//  }
//  
//  private func drawBoundingBox(for detection: DetectionF, in parentSize: CGSize, color: NSColor) -> some View {
//    let boundingBox = detection.boundingBoxF
//    let normalizedRect = CGRect(
//      x: boundingBox.origin.x * parentSize.width,
//      y: (1 - boundingBox.origin.y - boundingBox.height) * parentSize.height,
//      width: boundingBox.width * parentSize.width,
//      height: boundingBox.height * parentSize.height
//    )
//    
//    return Rectangle()
//      .stroke(Color(color), lineWidth: 2)
//      .frame(width: normalizedRect.width, height: normalizedRect.height)
//      .position(x: normalizedRect.midX, y: normalizedRect.midY)
//  }
//}
//
//func selectImages(completion: @escaping ([NSImage]) -> Void) {
//  let panel = NSOpenPanel()
//  panel.allowedContentTypes = [.image]
//  panel.allowsMultipleSelection = true
//  panel.begin { response in
//    if response == .OK {
//      let images: [NSImage] = panel.urls.compactMap { url -> NSImage? in
//        return NSImage(contentsOf: url)
//      }
//      completion(images)
//    }
//  }
//}
//
//func selectModel(completion: @escaping (MLModel) -> Void) {
//  let panel = NSOpenPanel()
//  panel.allowedContentTypes = [.mlmodel]
//  panel.allowsMultipleSelection = false
//  panel.begin { response in
//    if response == .OK, let url = panel.url {
//      do {
//        let compiledUrl = try MLModel.compileModel(at: url)
//        let model = try MLModel(contentsOf: compiledUrl)
//        completion(model)
//      } catch {
//        print("Failed to load model: \(error)")
//      }
//    }
//  }
//}
//
//func selectOutputDirectory(completion: @escaping (URL) -> Void) {
//  let panel = NSOpenPanel()
//  panel.canChooseDirectories = true
//  panel.canCreateDirectories = true
//  panel.allowsMultipleSelection = false
//  panel.begin { response in
//    if response == .OK, let url: URL = panel.url {
//      completion(url)
//    }
//  }
//}
