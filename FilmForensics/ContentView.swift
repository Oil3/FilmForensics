  //
  //  ContentView.swift
  //  FilmForensics
  //
  // Copyright Almahdi Morris - 05/20/24.
  //
import SwiftUI
import AVKit
import AVFoundation

struct ContentView: View {
    @StateObject private var videoPlayerViewModel = VideoPlayerViewModel()
    @StateObject private var imageViewerModel = ImageViewerModel()
    @State private var showPicker = false
    @State private var isImagePicker = false

    var body: some View {
        NavigationSplitView {
            List {
                Section(header: Text("Open")) {
                    Button("Open Video") {
                        isImagePicker = false
                        showPicker = true
                    }
                    Button("Open Image") {
                        isImagePicker = true
                        showPicker = true
                    }
                }
                Section(header: Text("Actions")) {
                    Button("Load CoreML Model") {
                        // Action for loading CoreML model
                    }
                    Button("View Log") {
                        // Action for viewing log
                    }
                    Button("Export") {
                        // Action for exporting
                    }
                    Button("Automatic") {
                        // Action for automatic processing
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)
        } content: {
            TabView {
                VideoView(videoPlayerViewModel: videoPlayerViewModel)
                    .tabItem {
                        Label("Video", systemImage: "video")
                    }
                ImageView(imageViewerModel: imageViewerModel)
                    .tabItem {
                        Label("Image", systemImage: "photo")
                    }
            }
            .fileImporter(isPresented: $showPicker, allowedContentTypes: isImagePicker ? [.image] : [.movie]) { result in
                switch result {
                case .success(let url):
                    if isImagePicker {
                        imageViewerModel.loadImage(url: url)
                    } else {
                        videoPlayerViewModel.loadVideo(url: url)
                    }
                case .failure(let error):
                    print("Failed to load file: \(error.localizedDescription)")
                }
            }
        } detail: {
            FilterControlsView(videoPlayerViewModel: videoPlayerViewModel)
                .frame(minWidth: 300)
                .padding()
                ImageView(imageViewerModel: imageViewerModel)

        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct VideoView: View {
    @ObservedObject var videoPlayerViewModel: VideoPlayerViewModel

    var body: some View {
        VideoPlayerView(player: videoPlayerViewModel.player)
            .onAppear {
                videoPlayerViewModel.setupPlayer()
            }
    }
}

struct ImageView: View {
    @ObservedObject var imageViewerModel: ImageViewerModel

    var body: some View {
        if let ciImage = imageViewerModel.ciImage {
            Image(nsImage: ciImage.toNSImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay(Rectangle().stroke(Color.clear, lineWidth: 0)) // Ensure image is in front
        } else {
            Text("No image available")
                .foregroundColor(.white)
        }
    }
}
 
