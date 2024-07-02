import SwiftUI
import CoreML

struct MainImageView: View {
  @StateObject var imageModel = ImageModel()
  var body: some View {
    NavigationSplitView {
      imageGallery(imageModel: imageModel)
    } detail: {
      imageContentView(imageModel: imageModel)
    }
  }
}

struct imageGallery: View {
  @ObservedObject var imageModel: ImageModel
  
  var body: some View {
    VStack {
      Button("Add Images") {
        selectImages { images in
          imageModel.images = images
        }
      }
      List {
        ForEach(Array(imageModel.images.enumerated()), id: \.element) { index, image in
          HStack {
            Image(nsImage: image)
              .resizable()
              .scaledToFit()
              .frame(width: 100, height: 100)
              .contextMenu {
                Button("Delete from List") {
                  imageModel.images.remove(at: index)
                }
                Button("Quick Look") {
                  imageModel.previewImage = image
                }
                Button("Run Prediction") {
                  runPrediction(on: image, imageModel: imageModel)
                }
              }
              .onTapGesture(count: 2) {
                imageModel.processedImage = image
                imageModel.applyFilters()
              }
          }
        }
      }
    }
  }
  
  private func runPrediction(on image: NSImage, imageModel: ImageModel) {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
    
    do {
      let input = try yolovFloat10nNNInput(imageWith: cgImage)
      let model = try yolovFloat10nNN(configuration: MLModelConfiguration())
      let output = try model.prediction(input: input)
      parsePredictionOutput(output.var_1200, imageSize: CGSize(width: cgImage.width, height: cgImage.height), imageModel: imageModel)
    } catch {
      print("Failed to perform prediction: \(error)")
    }
  }
  
  private func parsePredictionOutput(_ output: MLMultiArray, imageSize: CGSize, imageModel: ImageModel) {
    var detections: [DetectionF] = []
    
    let outputPointer = UnsafeMutablePointer<Float>(OpaquePointer(output.dataPointer))
    let numDetections = output.count / 6
    
    for i in 0..<numDetections {
      let x = CGFloat(outputPointer[i * 6 + 0])
      let y = CGFloat(outputPointer[i * 6 + 1])
      let width = CGFloat(outputPointer[i * 6 + 2])
      let height = CGFloat(outputPointer[i * 6 + 3])
      let confidence = outputPointer[i * 6 + 4]
      let classNumber = Int(outputPointer[i * 6 + 5])
      
      if confidence > 0.5 {
        let boundingBox = CGRect(x: x, y: y, width: width, height: height)
        let detection = DetectionF(boundingBoxF: boundingBox, confidenceF: confidence, classNumberF: classNumber)
        detections.append(detection)
        print("Class: \(classNumber), Confidence: \(confidence), Bounding Box: \(boundingBox)")
      }
    }
    
    DispatchQueue.main.async {
      imageModel.detectionsF = detections
    }
  }
}

struct imageContentView: View {
  @ObservedObject var imageModel: ImageModel
  
  var body: some View {
    ScrollView {
      if let previewImage = imageModel.previewImage {
        GeometryReader { geo in
          ZStack {
            Image(nsImage: previewImage)
              .resizable()
              .scaledToFit()
              .padding()
            
            ForEach(imageModel.detectionsF) { detection in
              drawBoundingBox(for: detection, in: geo.size, color: .red)
            }
          }
        }
        .padding()
      } else {
        Text("Select an image to preview")
          .padding()
      }
    }
  }
  
  private func drawBoundingBox(for detection: DetectionF, in parentSize: CGSize, color: NSColor) -> some View {
    let boundingBox = detection.boundingBoxF
    let normalizedRect = CGRect(
      x: boundingBox.origin.x * parentSize.width,
      y: (1 - boundingBox.origin.y - boundingBox.height) * parentSize.height,
      width: boundingBox.width * parentSize.width,
      height: boundingBox.height * parentSize.height
    )
    
    return Rectangle()
      .stroke(Color(color), lineWidth: 2)
      .frame(width: normalizedRect.width, height: normalizedRect.height)
      .position(x: normalizedRect.midX, y: normalizedRect.midY)
  }
}

func selectImages(completion: @escaping ([NSImage]) -> Void) {
  let panel = NSOpenPanel()
  panel.allowedContentTypes = [.image]
  panel.allowsMultipleSelection = true
  panel.begin { response in
    if response == .OK {
      let images: [NSImage] = panel.urls.compactMap { url -> NSImage? in
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
    if response == .OK, let url: URL = panel.url {
      completion(url)
    }
  }
}
