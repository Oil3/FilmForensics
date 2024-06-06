//
//  FilterControlsOverlay.swift
//  FilmForensics
//
// Copyright Almahdi Morris - 05/22/24.
//

import SwiftUI
import AVFoundation

struct FilterControlsOverlay: View {
    @ObservedObject var videoPlayerViewModel: VideoPlayerViewModel
    @State private var showHistogram = false

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack {
                    Button(action: {
                        showHistogram.toggle()
                    }) {
                        Text(showHistogram ? "Hide Histogram" : "Show Histogram")
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    if showHistogram {
                        HistogramView(image: videoPlayerViewModel.ciImage)
                            .frame(height: 150)
                            .padding()
                    }
                    FilterControls(videoPlayerViewModel: videoPlayerViewModel)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .padding()
                }
            }
        }
        .padding()
    }
}
