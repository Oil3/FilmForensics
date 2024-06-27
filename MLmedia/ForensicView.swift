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
    HStack {
      VStack {
        Button("Select Images") {
          selectImages { images in
            imageModel.images = images
          }
        }
        .padding()
        
        List {
          ForEach(Array(imageModel.images.enumerated()), id: \.element) { index, image in
            Image(nsImage: image)
              .resizable()
              .scaledToFit()
              .frame(width: 100, height: 100)
          }
        }
        .padding()
        
        Button("Clear All") {
          imageModel.images.removeAll()
        }
        .padding()
      }
      .frame(minWidth: 200)
      
      VStack {
        ScrollView(.horizontal) {
          HStack {
            ForEach(imageModel.processedImages, id: \.self) { image in
              Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
            }
          }
        }
        HStack {
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

