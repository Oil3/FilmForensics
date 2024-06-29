//
//  MainImageView.swift
//  FilmForensics
//
//  Created by Almahdi Morris on 28/6/24.
//

import SwiftUI

struct MainImageView: View {
  @StateObject var imageModel = ImageModel()

  var body: some View {
    NavigationView {
      imageGallery
      imagePreview
    }
  }
  private var imageGallery: some View {
    VStack {
      Button("Add Images") {
        selectImages { images in
          imageModel.images = images
        }
    }
      .padding()
      List {
          ForEach(Array(imageModel.images.enumerated()), id: \.element) { index, image in
            HStack {
              Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .contextMenu {
//                  Button("Save Image") {
//                    saveImage(image: image)
//                  }
//                  Button("Copy Image") {
//                    copyImage(image: image)
//                  }
//                  Button("Show in Finder") {
//                    showInFinder(image: image)
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
    
    
    
    
    
    }
    
  private var imagePreview: some View {
    ScrollView {
      HStack{
    }
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
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
}

