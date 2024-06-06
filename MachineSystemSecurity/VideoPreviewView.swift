//
//  VideoPreviewView.swift
//  Machine Security System
//
// Copyright Almahdi Morris - 1/6/24.
//
import SwiftUI
import AVKit

struct VideoPreviewView: View {
    var videoURL: URL
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

            VideoPlayer(player: AVPlayer(url: videoURL))
                .frame(height: 300)

            Spacer()
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
//        .transition(.move(edge: .bottom))
//        .animation(.easeInOut)
    }
}
