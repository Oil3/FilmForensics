import SwiftUI
import AppKit

extension NSImage: Identifiable {
  public var id: UUID {
    return UUID()
  }
}

struct ForensicView: View {
  @StateObject var imageModel = ImageModel()
  
  var body: some View {
    NavigationView {
      VStack {
        HStack {
          // Image selection list
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
                      imageModel.applyFilters()
                    }
                }
              }
            }
          }
          .frame(width: 250)
          
          VStack {
            // Image and filter settings
            GeometryReader { geometry in
              if let processedImage = imageModel.processedImage {
                Image(nsImage: processedImage)
                  .resizable()
                  .scaledToFit()
                  .frame(width: geometry.size.width, height: geometry.size.height)
              } else {
                Text("No image selected")
                  .frame(width: geometry.size.width, height: geometry.size.height)
              }
            }
            
            ScrollView {
              VStack {
                FilterSliderView(label: "Exposure", value: $imageModel.exposure, range: -2...2, action: imageModel.updateFilters)
                FilterSliderView(label: "Brightness", value: $imageModel.brightness, range: -1...1, action: imageModel.updateFilters)
                FilterSliderView(label: "Contrast", value: $imageModel.contrast, range: 0...4, action: imageModel.updateFilters)
                FilterSliderView(label: "Saturation", value: $imageModel.saturation, range: 0...2, action: imageModel.updateFilters)
                FilterSliderView(label: "Sharpness", value: $imageModel.sharpness, range: 0...1, action: imageModel.updateFilters)
                FilterSliderView(label: "Highlights", value: $imageModel.highlights, range: 0...1, action: imageModel.updateFilters)
                FilterSliderView(label: "Shadows", value: $imageModel.shadows, range: -1...1, action: imageModel.updateFilters)
                FilterSliderView(label: "Temperature", value: $imageModel.temperature, range: 1000...10000, action: imageModel.updateFilters)
                FilterSliderView(label: "Tint", value: $imageModel.tint, range: -100...100, action: imageModel.updateFilters)
                FilterSliderView(label: "Sepia", value: $imageModel.sepia, range: 0...1, action: imageModel.updateFilters)
                FilterSliderView(label: "Gamma", value: $imageModel.gamma, range: 0.1...3, action: imageModel.updateFilters)
                FilterSliderView(label: "Hue", value: $imageModel.hue, range: -3.14...3.14, action: imageModel.updateFilters)
                FilterSliderView(label: "White Point", value: $imageModel.whitePoint, range: 0...2, action: imageModel.updateFilters)
                FilterSliderView(label: "Bump Radius", value: $imageModel.bumpRadius, range: 0...600, action: imageModel.updateFilters)
                FilterSliderView(label: "Bump Scale", value: $imageModel.bumpScale, range: -1...1, action: imageModel.updateFilters)
                FilterSliderView(label: "Pixelate", value: $imageModel.pixelate, range: 1...50, action: imageModel.updateFilters)
              }
            }
            .frame(width: 200)
          }
        }
        
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
          
          Button("Reset Filters") {
            imageModel.resetFilters()
          }
          .padding()
          
          Button("Save Changes") {
            imageModel.saveChanges()
          }
          .padding()
          
          Button("Apply to All") {
            imageModel.applyToAll()
          }
          .padding()
          
          Button("Save All") {
            imageModel.saveAll()
          }
          .padding()
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

struct FilterSliderView: View {
  let label: String
  @Binding var value: CGFloat
  let range: ClosedRange<CGFloat>
  let action: () -> Void
  
  var body: some View {
    VStack {
      Text(label)
      Slider(value: $value, in: range, onEditingChanged: { _ in
        action()
      })
    }
    .padding()
  }
}









//

//
//
//
//import SwiftUI
//import AppKit
//
//extension NSImage: Identifiable {
//  public var id: UUID {
//    return UUID()
//  }
//}
//
//struct ForensicView: View {
//  @StateObject var imageModel = ImageModel()
//  
//  var body: some View {
//    NavigationView {
//      VStack {
//        HStack {
//          // Image selection list
//          List {
//            Section(header: Text("Original Images")) {
//              ForEach(Array(imageModel.images.enumerated()), id: \.element) { index, image in
//                HStack {
//                  Image(nsImage: image)
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 100, height: 100)
//                    .contextMenu {
//                      Button("Save Image") {
//                        saveImage(image: image)
//                      }
//                      Button("Copy Image") {
//                        copyImage(image: image)
//                      }
//                      Button("Show in Finder") {
//                        showInFinder(image: image)
//                      }
//                      Button("Delete from List") {
//                        imageModel.images.remove(at: index)
//                      }
//                      Button("Quick Look") {
//                        imageModel.previewImage = image
//                      }
//                    }
//                    .onTapGesture(count: 2) {
//                      imageModel.processedImage = image
//                      imageModel.applyFilters()
//                    }
//                }
//              }
//            }
//          }
//          .frame(width: 250)
//          
//          VStack {
//            // Image and filter settings
//            GeometryReader { geometry in
//              if let processedImage = imageModel.processedImage {
//                Image(nsImage: processedImage)
//                  .resizable()
//                  .scaledToFit()
//                  .frame(width: geometry.size.width, height: geometry.size.height)
//              } else {
//                Text("No image selected")
//                  .frame(width: geometry.size.width, height: geometry.size.height)
//              }
//            }
//            
//            ScrollView {
//              VStack {
//                FilterSliderView(label: "Exposure", value: $imageModel.exposure, range: -2...2, action: imageModel.updateFilters)
//                FilterSliderView(label: "Brightness", value: $imageModel.brightness, range: -1...1, action: imageModel.updateFilters)
//                FilterSliderView(label: "Contrast", value: $imageModel.contrast, range: 0...4, action: imageModel.updateFilters)
//                FilterSliderView(label: "Saturation", value: $imageModel.saturation, range: 0...2, action: imageModel.updateFilters)
//                FilterSliderView(label: "Sharpness", value: $imageModel.sharpness, range: 0...1, action: imageModel.updateFilters)
//                FilterSliderView(label: "Highlights", value: $imageModel.highlights, range: 0...1, action: imageModel.updateFilters)
//                FilterSliderView(label: "Shadows", value: $imageModel.shadows, range: -1...1, action: imageModel.updateFilters)
//                FilterSliderView(label: "Temperature", value: $imageModel.temperature, range: 1000...10000, action: imageModel.updateFilters)
//                FilterSliderView(label: "Tint", value: $imageModel.tint, range: -100...100, action: imageModel.updateFilters)
//                FilterSliderView(label: "Sepia", value: $imageModel.sepia, range: 0...1, action: imageModel.updateFilters)
//                FilterSliderView(label: "Gamma", value: $imageModel.gamma, range: 0.1...3, action: imageModel.updateFilters)
//                FilterSliderView(label: "Hue", value: $imageModel.hue, range: -3.14...3.14, action: imageModel.updateFilters)
//                FilterSliderView(label: "White Point", value: $imageModel.whitePoint, range: 0...2, action: imageModel.updateFilters)
//                FilterSliderView(label: "Bump Radius", value: $imageModel.bumpRadius, range: 0...600, action: imageModel.updateFilters)
//                FilterSliderView(label: "Bump Scale", value: $imageModel.bumpScale, range: -1...1, action: imageModel.updateFilters)
//                FilterSliderView(label: "Pixelate", value: $imageModel.pixelate, range: 1...50, action: imageModel.updateFilters)
//              }
//            }
//            .frame(width: 200)
//          }
//        }
//        
//        HStack {
//          Button("Select Images") {
//            selectImages { images in
//              imageModel.images = images
//            }
//          }
//          .padding()
//          
//          Button("Select Output Directory") {
//            selectOutputDirectory { url in
//              imageModel.outputDirectory = url
//            }
//          }
//          .padding()
//          
//          Button("Reset Filters") {
//            imageModel.resetFilters()
//          }
//          .padding()
//          
//          Button("Save Changes") {
//            imageModel.saveChanges()
//          }
//          .padding()
//          
//          Button("Apply to All") {
//            imageModel.applyToAll()
//          }
//          .padding()
//          
//          Button("Save All") {
//            imageModel.saveAll()
//          }
//          .padding()
//        }
//        
//        if imageModel.isProcessing {
//          ProgressView()
//            .padding()
//        }
//        
//        Text(imageModel.statusText)
//          .padding()
//          .opacity(imageModel.statusText.isEmpty ? 0 : 1)
//          .animation(.easeInOut(duration: 2).delay(2), value: imageModel.statusText)
//      }
//      .padding()
//      .sheet(item: $imageModel.previewImage) { image in
//        ImageDetailView(image: image)
//      }
//    }
//  }
//  
//  func selectImages(completion: @escaping ([NSImage]) -> Void) {
//    let panel = NSOpenPanel()
//    panel.allowedFileTypes = ["png", "jpg", "jpeg"]
//    panel.allowsMultipleSelection = true
//    panel.begin { response in
//      if response == .OK {
//        let images: [NSImage] = panel.urls.compactMap { url -> NSImage? in
//          return NSImage(contentsOf: url)
//        }
//        completion(images)
//      }
//    }
//  }
//  
//  func selectOutputDirectory(completion: @escaping (URL) -> Void) {
//    let panel = NSOpenPanel()
//    panel.canChooseDirectories = true
//    panel.canCreateDirectories = true
//    panel.allowsMultipleSelection = false
//    panel.begin { response in
//      if response == .OK, let url: URL = panel.url {
//        completion(url)
//      }
//    }
//  }
//  
//  func saveImage(image: NSImage) {
//    let panel = NSSavePanel()
//    panel.allowedFileTypes = ["png"]
//    panel.begin { response in
//      if response == .OK, let url: URL = panel.url {
//        if let tiffData: Data = image.tiffRepresentation, let bitmapImage: NSBitmapImageRep = NSBitmapImageRep(data: tiffData) {
//          let pngData: Data? = bitmapImage.representation(using: .png, properties: [:])
//          try? pngData?.write(to: url)
//        }
//      }
//    }
//  }
//  
//  func copyImage(image: NSImage) {
//    NSPasteboard.general.clearContents()
//    NSPasteboard.general.writeObjects([image])
//  }
//  
//  func showInFinder(image: NSImage) {
//    if let tiffData: Data = image.tiffRepresentation, let bitmapImage: NSBitmapImageRep = NSBitmapImageRep(data: tiffData) {
//      let temporaryDirectory: URL = URL(fileURLWithPath: NSTemporaryDirectory())
//      let tempFileURL: URL = temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
//      let pngData: Data? = bitmapImage.representation(using: .png, properties: [:])
//      try? pngData?.write(to: tempFileURL)
//      NSWorkspace.shared.activateFileViewerSelecting([tempFileURL])
//    }
//  }
//}
//
//struct ImageDetailView: View {
//  let image: NSImage
//  
//  var body: some View {
//    Image(nsImage: image)
//      .resizable()
//      .scaledToFit()
//      .padding()
//      .navigationTitle("Image Detail")
//  }
//}
//
//struct FilterSliderView: View {
//  let label: String
//  @Binding var value: CGFloat
//  let range: ClosedRange<CGFloat>
//  let action: () -> Void
//  
//  var body: some View {
//    VStack {
//      Text(label)
//      Slider(value: $value, in: range, onEditingChanged: { _ in
//        action()
//      })
//    }
//    .padding()
//  }
//}

