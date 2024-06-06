//
//  VideoViewControllerWrapper.swift
//  Machine Security System
//
// Copyright Almahdi Morris - 31/5/24.
//
import SwiftUI

struct VideoViewControllerWrapper: UIViewControllerRepresentable {
    @Binding var videoURL: URL?

    func makeUIViewController(context: Context) -> VideoViewController {
        let viewController = VideoViewController()
        return viewController
    }

    func updateUIViewController(_ uiViewController: VideoViewController, context: Context) {
        if let url = videoURL {
            uiViewController.loadVideo(url: url)
        }
    }
}
