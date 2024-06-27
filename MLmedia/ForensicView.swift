//
//  ForensicView.swift
//  FilmForensics
//
//  Created by Almahdi Morris on 27/6/24.
//

import SwiftUI

struct ForensicView: View {
  @StateObject var imageModel = ImageModel()
  
  var body: some View {
    NavigationView {
      VStack {
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
        
        List {
          Section(header: Text("Original Images")) {
            ForEach(Array(imageModel.images.enumerated()), id: \.element) { index, image in
              NavigationLink(destination: ImageDetailView(image: image)) {
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
                    Button("Select All") {
                      selectAllImages()
                    }
                  }
              }
            }
          }
          .headerProminence(.increased)
          .padding()
          
          Button("Clear All") {
            imageModel.images.removeAll()
          }
          .padding()
          
          Section(header: Text("Processed Images")) {
            ForEach(imageModel.processedImages, id: \.self) { image in
              NavigationLink(destination: ImageDetailView(image: image)) {
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
                      if let index = imageModel.processedImages.firstIndex(of: image) {
                        imageModel.processedImages.remove(at: index)
                      }
                    }
                    Button("Select All") {
                      selectAllProcessedImages()
                    }
                  }
              }
            }
          }
          .headerProminence(.increased)
          .padding()
        }
        .navigationTitle("Image Processing")
        
        VStack {
          VStack {
            Text("Threshold: \(Int(imageModel.threshold))")
            Slider(value: $imageModel.threshold, in: 0...100)
          }
          .padding()
          
          Button("Compare Next Images") {
            imageModel.compareNextImage()
          }
          .padding()
          
          Button("Align and Crop Faces") {
            imageModel.alignAndCropFaces()
          }
          .padding()
          
          if let processedImage = imageModel.processedImage {
            Image(nsImage: processedImage)
              .resizable()
              .scaledToFit()
              .frame(width: 400, height: 400)
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
      }
    }
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
  
  func saveImage(image: NSImage) {
    let panel = NSSavePanel()
    panel.allowedFileTypes = ["png"]
    panel.begin { response in
      if response == .OK, let url = panel.url {
        if let tiffData = image.tiffRepresentation, let bitmapImage = NSBitmapImageRep(data: tiffData) {
          let pngData = bitmapImage.representation(using: .png, properties: [:])
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
    if let tiffData = image.tiffRepresentation, let bitmapImage = NSBitmapImageRep(data: tiffData) {
      let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
      let tempFileURL = temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
      let pngData = bitmapImage.representation(using: .png, properties: [:])
      try? pngData?.write(to: tempFileURL)
      NSWorkspace.shared.activateFileViewerSelecting([tempFileURL])
    }
  }
  
  func selectAllImages() {
    imageModel.images = imageModel.images
  }
  
  func selectAllProcessedImages() {
    imageModel.processedImages = imageModel.processedImages
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
