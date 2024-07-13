import SwiftUI
import Vision
import CoreML

struct MainImageView: View {
  @StateObject var imageModel = ImageModel()
  var body: some View {
    NavigationSplitView {
      ImageGalleryView(imageModel: imageModel)
    } detail: {
      ImageContentView(imageModel: imageModel)
    }
    .onAppear {
      imageModel.loadImages()
    }
    .onDisappear {
      imageModel.saveImages()
    }
  }
}

struct ImageGalleryView: View {
  @ObservedObject var imageModel: ImageModel
  @State private var selectedIndex: Int?
  
  var body: some View {
    VStack {
      Button("Add Images") {
        selectImages { images in
          imageModel.images.append(contentsOf: images)
          imageModel.saveImages()
        }
      }
      .padding()
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack {
            ForEach(Array(imageModel.images.enumerated()), id: \.element) { index, image in
              Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .border(index == selectedIndex ? Color.blue : Color.clear, width: 2)
                .onTapGesture {
                  selectedIndex = index
                  imageModel.previewImage = image
                  imageModel.detections = []
                  imageModel.detectionsF = []
                }
                .contextMenu {
                  Button("Delete") {
                    imageModel.images.remove(at: index)
                    imageModel.saveImages()
                  }
                  Button("Run Prediction") {
                    runPrediction(on: image, imageModel: imageModel)
                  }
                }
                .id(index)
            }
          }
          .padding()
        }
        .onChange(of: selectedIndex) { _ in
          if let selectedIndex = selectedIndex {
            withAnimation {
              proxy.scrollTo(selectedIndex, anchor: .center)
            }
          }
        }
      }
      Button("Clear All") {
        imageModel.images.removeAll()
        imageModel.previewImage = nil
        imageModel.detections = []
        imageModel.detectionsF = []
        imageModel.saveImages()
      }
      .padding()
    }
//    .onKeyDown { event in
//      handleKeyDown(event)
//    }
  }
  
  private func runPrediction(on image: NSImage, imageModel: ImageModel) {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let model = imageModel.selectedModel else { return }
    
    do {
      if isVisionModel(model: model) {
        let visionModel = try VNCoreMLModel(for: model)
        let request = VNCoreMLRequest(model: visionModel) { request, error in
          if let results = request.results as? [VNRecognizedObjectObservation] {
            DispatchQueue.main.async {
              imageModel.detections = results.map { Detection(boundingBox: $0.boundingBox, identifier: $0.labels.first?.identifier ?? "Unknown", confidence: $0.confidence) }
            }
          } else if let results = request.results as? [VNPixelBufferObservation] {
            DispatchQueue.main.async {
              if let resultBuffer = results.first?.pixelBuffer {
                imageModel.generatedImage = NSImage(cgImage: CIImage(cvPixelBuffer: resultBuffer).cgImage!, size: NSSize(width: cgImage.width, height: cgImage.height))
              }
            }
          }
        }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
      } else {
        let input = try terminal2p_nmslessInput(imageWith: cgImage)
        let nonVisionModel = try terminal2p_nmsless(configuration: MLModelConfiguration())
        let output = try nonVisionModel.prediction(input: input)
        parseNonVisionPredictionOutput(output.var_914, imageSize: CGSize(width: cgImage.width, height: cgImage.height), imageModel: imageModel, imageName: "image_\(imageModel.images.firstIndex(of: image) ?? 0).json")
      }
    } catch {
      print("Failed to perform prediction: \(error)")
    }
  }
  
  private func isVisionModel(model: MLModel) -> Bool {
    return !(model is terminal2p_nmsless)
  }
  
  private func parseNonVisionPredictionOutput(_ output: MLMultiArray, imageSize: CGSize, imageModel: ImageModel, imageName: String) {
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
      }
    }
    
    DispatchQueue.main.async {
      imageModel.detectionsF = detections
      saveDetectionsToFile(detections: detections, imageName: imageName)
    }
  }
  
  private func saveDetectionsToFile(detections: [DetectionF], imageName: String) {
    selectOutputDirectory { directoryURL in
      let fileURL = directoryURL.appendingPathComponent(imageName)
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      do {
        let data = try encoder.encode(detections)
        try data.write(to: fileURL)
      } catch {
        print("Failed to save detections to file: \(error)")
      }
    }
  }
  
  private func handleKeyDown(_ event: NSEvent) {
    if let selectedIndex = selectedIndex {
      if event.keyCode == 126 { // Up arrow key
        if selectedIndex > 0 {
          self.selectedIndex = selectedIndex - 1
        }
      } else if event.keyCode == 125 { // Down arrow key
        if selectedIndex < imageModel.images.count - 1 {
          self.selectedIndex = selectedIndex + 1
        }
      }
    }
  }
}

struct ImageContentView: View {
  @ObservedObject var imageModel: ImageModel
  
  var body: some View {
    ScrollView {
      if let previewImage = imageModel.previewImage {
        GeometryReader { geo in
          ZStack {
            Image(nsImage: previewImage)
              .resizable()
              .scaledToFit()
              .frame(width: geo.size.width, height: geo.size.height)
            
            ForEach(imageModel.detections) { detection in
              drawBoundingBox(for: detection, in: geo.size, color: .red)
            }
            
            ForEach(imageModel.detectionsF) { detection in
              drawBoundingBoxF(for: detection, in: geo.size, color: .blue)
            }
          }
        }
        .frame(width: 640, height: 640, alignment: .center)
      } else if let generatedImage = imageModel.generatedImage {
        Image(nsImage: generatedImage)
          .resizable()
          .scaledToFit()
          .frame(width: 640, height: 640, alignment: .center)
      } else {
        Text("Select an image to preview")
      }
    }
    .frame(width: 640, height: 640, alignment: .center)
  }
  
  private func drawBoundingBox(for detection: Detection, in parentSize: CGSize, color: NSColor) -> some View {
    let boundingBox = detection.boundingBox
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
  
  private func drawBoundingBoxF(for detection: DetectionF, in parentSize: CGSize, color: NSColor) -> some View {
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

func selectModel(completion: @escaping (MLModel) -> Void) {
  let panel = NSOpenPanel()
//  panel.allowedContentTypes = [.mlmodel]
  panel.allowsMultipleSelection = false
  panel.begin { response in
    if response == .OK, let url = panel.url {
      do {
        let compiledUrl = try MLModel.compileModel(at: url)
        let model = try MLModel(contentsOf: compiledUrl)
        completion(model)
      } catch {
        print("Failed to load model: (error)")
      }
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


