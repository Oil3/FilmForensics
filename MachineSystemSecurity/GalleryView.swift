//
//  GalleryView.swift
//  Machine Security System
//
// Copyright Almahdi Morris - 31/5/24.
//
import SwiftUI
import AVKit
import UIKit

struct GalleryView: View {
    @ObservedObject var viewModel = GalleryViewModel()
    @State private var selectedMediaIndex: Int? = nil

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Button(action: {
                        viewModel.selectFiles()
                    }) {
                        Label("Add Files", systemImage: "plus")
                    }
                    .padding()

                    Spacer()

                    Picker("Sort by", selection: $viewModel.sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue.capitalized).tag(option)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                }

                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
                            ForEach(viewModel.sortedFiles.indices, id: \.self) { index in
                                VStack {
                                    if let image = viewModel.sortedFiles[index].previewImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 100)
                                    } else {
                                        Rectangle()
                                            .fill(Color.gray)
                                            .frame(height: 100)
                                    }
                                    Text(viewModel.sortedFiles[index].name)
                                        .font(.caption)
                                }
                                .background(viewModel.sortedFiles[index].type == .video ? Color.blue.opacity(0.3) : Color.green.opacity(0.3))
                                .cornerRadius(10)
                                .onTapGesture {
                                    selectedMediaIndex = index
                                }
                            }
                        }
                        .padding()
                    }
                }
            }

            if let index = selectedMediaIndex {
                let mediaFile = viewModel.sortedFiles[index]
                if mediaFile.type == .video {
                    VideoPreviewView(videoURL: mediaFile.url, onDismiss: {
                        selectedMediaIndex = nil
                    })
                } else if let image = mediaFile.previewImage {
                    ImagePreviewView(image: image, onDismiss: {
                        selectedMediaIndex = nil
                    })
                }
            }
        }
        .navigationTitle("Gallery")
        .onAppear {
            viewModel.loadFiles()
        }
    }
}

struct ImagePreviewView: View {
    var image: UIImage
    var onDismiss: () -> Void

    var body: some View {
        VStack {
            HStack {
                Button(action: onDismiss) {
                    Text("Go Back")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                Spacer()
            }
            .padding()

            Spacer()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding()

            Spacer()
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .transition(.move(edge: .bottom))
        .animation(.easeInOut)
    }
}


