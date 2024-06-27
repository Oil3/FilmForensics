import SwiftUI
import Vision
import CoreML
import CoreImage

struct FaceContentView: View {
  @State private var selectedTab = 0
  @State private var folders: [URL] = []
  @State private var images: [URL] = []
  @State private var selectedImages: Set<URL> = []
  @State private var faceNetModel: facenetfromtf?
  @State private var embeddings: [[Double]] = []
  @State private var groupedImages: [[URL]] = []
  @State private var errorMessage: String?
  
  var body: some View {
    
    NavigationView {
      List {
        ForEach(folders, id: \.self) { folder in
          NavigationLink(destination: ImageGridView(folder: folder, images: $images, selectedImages: $selectedImages)) {
            HStack {
              Image(systemName: "folder")
              Text(folder.lastPathComponent)
            }
          }
        }
      }
      .navigationTitle("Folders")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button(action: addFolder) {
            Image(systemName: "folder.badge.plus")
          }
        }
      }
      .frame(minWidth: 200)
      
      VStack {
        if selectedTab == 0 {
          ImageEditorView(images: images, selectedImages: Array(selectedImages))
        } else {
          CoreMLView(images: images, faceNetModel: faceNetModel, embeddings: $embeddings, groupedImages: $groupedImages, errorMessage: $errorMessage)
        }
      }
      .navigationTitle("Details")
      .toolbar {
          Picker("Tabs", selection: $selectedTab) {
            Text("Image Editor").tag(0)
            Text("CoreML").tag(1)
          }
          .pickerStyle(SegmentedPickerStyle())
        }
    }
    .onAppear {
      loadFaceNetModel()
    }
  }
  
  private func addFolder() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canCreateDirectories = false
    panel.allowsMultipleSelection = true
    if panel.runModal() == .OK {
      folders.append(contentsOf: panel.urls)
    }
  }
  
  private func loadFaceNetModel() {
    do {
      faceNetModel = try facenetfromtf(contentsOf: facenetfromtf.urlOfModelInThisBundle)
    } catch {
      errorMessage = "Failed to load FaceNet model: \(error.localizedDescription)"
    }
  }
}

struct ImageGridView: View {
  let folder: URL
  @Binding var images: [URL]
  @Binding var selectedImages: Set<URL>
  
  var body: some View {
    ScrollView {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {

        ForEach(images, id: \.self) { image in
          Image(nsImage: NSImage(contentsOf: image) ?? NSImage())
            .resizable()
            .scaledToFit()
            .frame(width: 100, height: 100)
            .border(selectedImages.contains(image) ? Color.blue : Color.clear, width: 2)
            .onTapGesture {
              if selectedImages.contains(image) {
                selectedImages.remove(image)
              } else {
                selectedImages.insert(image)
              }
            }
        }
      }
      .padding()
    }
    .onAppear {
      loadImages()
    }
  }
  
  private func loadImages() {
    let fileManager = FileManager.default
    if let urls = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
      images = urls.filter { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "png" }
    }
  }
}

struct ImageEditorView: View {
  @State var images: [URL]
  @State var selectedImages: [URL]
  @State private var currentFilter: CIFilter = CIFilter.sharpenLuminance()
  @State private var inputIntensity: Float = 0.3
  
  var body: some View {
    ScrollView {
      VStack {
        ForEach(selectedImages, id: \.self) { imageURL in
          if let image = NSImage(contentsOf: imageURL) {
            Image(nsImage: applyFilter(to: image))
              .resizable()
              .scaledToFit()
              .frame(maxWidth: 500, maxHeight: 300)
          }
        }
      }
        }
      HStack {

      Slider(value: $inputIntensity, in: 0...1)
        .padding()
        Button("Sharpen Luminance") {
          currentFilter = CIFilter.sharpenLuminance()
        }
        Button("Unsharp Mask") {
          currentFilter = CIFilter.unsharpMask()
        }
      }
      .padding()
    }
  
  private func applyFilter(to image: NSImage) -> NSImage {
    let ciImage = CIImage(data: image.tiffRepresentation!)
    currentFilter.setValue(ciImage, forKey: kCIInputImageKey)
    currentFilter.setValue(inputIntensity, forKey: kCIInputIntensityKey)
    
    let context = CIContext()
    if let outputImage = currentFilter.outputImage,
       let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
      return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    return image
  }
}

struct CoreMLView: View {
  @State var images: [URL]
  @State var faceNetModel: facenetfromtf?
  @Binding var embeddings: [[Double]]
  @Binding var groupedImages: [[URL]]
  @Binding var errorMessage: String?
  
  var body: some View {
    VStack {
      if let errorMessage = errorMessage {
        Text(errorMessage).foregroundColor(.red)
      }
      Button("Extract Embeddings") {
        extractEmbeddings()
      }
      
      if !embeddings.isEmpty {
        Button("Cluster Images") {
          clusterImages()
        }
      }
      
      if !groupedImages.isEmpty {
        ScrollView {
          ForEach(groupedImages.indices, id: \.self) { index in
            VStack {
              Text("Group \(index + 1)")
              LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                ForEach(groupedImages[index], id: \.self) { image in
                  Image(nsImage: NSImage(contentsOf: image) ?? NSImage())
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                }
              }
            }
            .padding()
          }
        }
      }
    }
    .padding()
  }
  
  private func extractEmbeddings() {
    guard let faceNetModel = faceNetModel else { return }
    var newEmbeddings: [[Double]] = []
    
    for image in images {
      if let nsImage = NSImage(contentsOf: image), let embedding = generateEmbedding(for: nsImage) {
        newEmbeddings.append(embedding)
      }
    }
    
    embeddings = newEmbeddings
  }
  
  private func generateEmbedding(for image: NSImage) -> [Double]? {
    guard let faceNetModel = faceNetModel else { return nil }
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
      errorMessage = "Failed to create CGImage from NSImage."
      return nil
    }
    
    do {
      let input = try facenetfromtfInput(input__0With: cgImage)
      let prediction = try faceNetModel.prediction(input: input)
      return prediction.embeddings__0.arrayOfDouble()
    } catch {
      errorMessage = "Failed to generate embedding: \(error.localizedDescription)"
      return nil
    }
  }
  
  private func clusterImages() {
    let k = 10 // Assuming we know there are 10 different individuals
    groupedImages = clusterEmbeddings(embeddings, k: k)
  }
  
  private func clusterEmbeddings(_ embeddings: [[Double]], k: Int) -> [[URL]] {
    // K-means clustering implementation here
    // For now, we will return dummy data
    return []
  }
}

extension MLMultiArray {
  func arrayOfDouble() -> [Double] {
    var array: [Double] = []
    for i in 0..<self.count {
      array.append(self[i].doubleValue)
    }
    return array
  }
}
