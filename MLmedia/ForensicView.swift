import SwiftUI

struct ForensicView: View {
  @StateObject var imageModel = ImageModel()
  
  var body: some View {
    NavigationView {
      List {
        Section(header: Text("Original Images")) {
          ForEach(Array(imageModel.images.enumerated()), id: \.element) { index, image in
            HStack {
              Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .contextMenu {
                  Button("Save Image") {
                    saveImage(image: image)
                  }
                  Button("Copy Image") {
                    copyImage(image: image)
                  }
                  Button("Show in Finder") {
                    showInFinder(image: image)
                  }
                  Button("Delete from List") {
                    imageModel.images.remove(at: index)
                  }
                  Button("Quick Look") {
                    imageModel.previewImage = image
                  }
                }
                .onTapGesture(count: 2) {
                  imageModel.processedImage = image
                }
            }
          }
        }
        .headerProminence(.increased)
        
        Button("Clear All") {
          imageModel.images.removeAll()
        }
        .padding()
        
        Section(header: Text("Processed Images")) {
          if let processedImage = imageModel.processedImage {
            Image(nsImage: processedImage)
              .resizable()
              .scaledToFit()
              .frame(width: 100, height: 100)
              .contextMenu {
                Button("Save Image") {
                  saveImage(image: processedImage)
                }
                Button("Copy Image") {
                  copyImage(image: processedImage)
                }
                Button("Show in Finder") {
                  showInFinder(image: processedImage)
                }
                Button("Delete from List") {
                  imageModel.processedImage = nil
                }
              }
          }
        }
        .headerProminence(.increased)
      }
      .navigationTitle("Image Processing")
      .toolbar {
        ToolbarItem(placement: .automatic) {
          HStack {
            Button("Select Images") {
              selectImages { images in
                imageModel.images = images
              }
            }
            .padding()
            
            Button("Select Output Directory") {
              selectOutputDirectory { url in
                imageModel.outputDirectory = url
              }
            }
            .padding()
          }
        }
      }
      
      VStack {
        HStack {
          ScrollView {
            VStack {
              SliderView(label: "Exposure", value: $imageModel.exposure, range: -2...2)
                .onChange(of: imageModel.exposure) { newValue in
                  imageModel.updateFilters()
                }
              SliderView(label: "Brightness", value: $imageModel.brightness, range: -1...1)
                .onChange(of: imageModel.brightness) { newValue in
                  imageModel.updateFilters()
                }
              SliderView(label: "Contrast", value: $imageModel.contrast, range: 0...4)
                .onChange(of: imageModel.contrast) { newValue in
                  imageModel.updateFilters()
                }
              SliderView(label: "Saturation", value: $imageModel.saturation, range: 0...2)
                .onChange(of: imageModel.saturation) { newValue in
                  imageModel.updateFilters()
                }
              SliderView(label: "Sharpness", value: $imageModel.sharpness, range: 0...1)
                .onChange(of: imageModel.sharpness) { newValue in
                  imageModel.updateFilters()
                }
              SliderView(label: "Highlights", value: $imageModel.highlights, range: 0...1)
                .onChange(of: imageModel.highlights) { newValue in
                  imageModel.updateFilters()
                }
              SliderView(label: "Shadows", value: $imageModel.shadows, range: -1...1)
                .onChange(of: imageModel.shadows) { newValue in
                  imageModel.updateFilters()
                }
              SliderView(label: "Temperature", value: $imageModel.temperature, range: 1000...10000)
                .onChange(of: imageModel.temperature) { newValue in
                  imageModel.updateFilters()
                }
              SliderView(label: "Tint", value: $imageModel.tint, range: -100...100)
                .onChange(of: imageModel.tint) { newValue in
                  imageModel.updateFilters()
                }
              SliderView(label: "Sepia", value: $imageModel.sepia, range: 0...1)
                .onChange(of: imageModel.sepia) { newValue in
                  imageModel.updateFilters()
                }
              SliderView(label: "Gamma", value: $imageModel.gamma, range: 0.1...3)
                .onChange(of: imageModel.gamma) { newValue in
                  imageModel.updateFilters()
                }
              SliderView(label: "Hue", value: $imageModel.hue, range: -3.14...3.14)
                .onChange(of: imageModel.hue) { newValue in
                  imageModel.updateFilters()
                }
              SliderView(label: "White Point", value: $imageModel.whitePoint, range: 0...2)
                .onChange(of: imageModel.whitePoint) { newValue in
                  imageModel.updateFilters()
                }
              SliderView(label: "Bump Radius", value: $imageModel.bumpRadius, range: 0...600)
                .onChange(of: imageModel.bumpRadius) { newValue in
                  imageModel.updateFilters()
                }
              SliderView(label: "Bump Scale", value: $imageModel.bumpScale, range: -1...1)
                .onChange(of: imageModel.bumpScale) { newValue in
                  imageModel.updateFilters()
                }
              SliderView(label: "Pixelate", value: $imageModel.pixelate, range: 1...50)
                .onChange(of: imageModel.pixelate) { newValue in
                  imageModel.updateFilters()
                }
            }
          }
          .frame(width: 200)
          
          Spacer()
          
          GeometryReader { geometry in
            if let processedImage = imageModel.processedImage {
              Image(nsImage: processedImage)
                .resizable()
                .scaledToFit()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .overlay(Button(action: {
                  // Show the original image as an overlay
                  if let originalImage = imageModel.images.first {
                    ImageOverlayView(image: originalImage)
                  }
                }) {
                  Text("Show Original")
                })
            } else {
              Text("No image selected")
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
          }
          
          Spacer()
          
          ScrollView {
            VStack {
              Convolution3x3View(convolution: $imageModel.convolution)
                .onChange(of: imageModel.convolution) { newValue in
                  imageModel.updateFilters()
                }
            }
          }
          .frame(width: 200)
        }
        
        if imageModel.isProcessing {
          ProgressView()
            .padding()
        }
        
        Text(imageModel.statusText)
          .padding()
          .opacity(imageModel.statusText.isEmpty ? 0 : 1)
          .animation(.easeInOut(duration: 2).delay(2), value: imageModel.statusText)
      }
      .padding()
      .sheet(item: $imageModel.previewImage) { image in
        ImageDetailView(image: image)
      }
    }
  }
  
  func selectImages(completion: @escaping ([NSImage]) -> Void) {
    let panel = NSOpenPanel()
    panel.allowedFileTypes = ["png", "jpg", "jpeg"]
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
  
  func copyImage(image: NSImage) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.writeObjects([image])
  }
  
  func showInFinder(image: NSImage) {
    if let tiffData: Data = image.tiffRepresentation, let bitmapImage: NSBitmapImageRep = NSBitmapImageRep(data: tiffData) {
      let temporaryDirectory: URL = URL(fileURLWithPath: NSTemporaryDirectory())
      let tempFileURL: URL = temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
      let pngData: Data? = bitmapImage.representation(using: .png, properties: [:])
      try? pngData?.write(to: tempFileURL)
      NSWorkspace.shared.activateFileViewerSelecting([tempFileURL])
    }
  }
  
  func selectAllImages() {
    imageModel.images = imageModel.images
  }
  
  func selectAllProcessedImages() {
    imageModel.processedImage = imageModel.processedImage
  }
}

struct ImageDetailView: View {
  let image: NSImage
  
  var body: some View {
    Image(nsImage: image)
      .resizable()
      .scaledToFit()
      .padding()
      .navigationTitle("Image Detail")
  }
}

struct SliderView: View {
  let label: String
  @Binding var value: CGFloat
  let range: ClosedRange<CGFloat>
  
  var body: some View {
    VStack {
      Text(label)
      Slider(value: $value, in: range)
    }
    .padding()
  }
}

struct Convolution3x3View: View {
  @Binding var convolution: [CGFloat]
  
  var body: some View {
    VStack {
      Text("Convolution 3x3")
      ForEach(0..<3) { row in
        HStack {
          ForEach(0..<3) { col in
            TextField("", value: $convolution[row * 3 + col], formatter: NumberFormatter())
              .frame(width: 50)
              .textFieldStyle(RoundedBorderTextFieldStyle())
          }
        }
      }
    }
    .padding()
  }
}

struct ImageOverlayView: View {
  let image: NSImage
  
  var body: some View {
    Image(nsImage: image)
      .resizable()
      .scaledToFit()
      .background(Color.black.opacity(0.5))
      .transition(.opacity)
  }
}
import AppKit

extension NSImage: Identifiable {
  public var id: UUID {
    return UUID()
  }
}
