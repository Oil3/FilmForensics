//
//  VideoView.swift
//  V
//
//  Created by Almahdi Morris on 4/6/24.
//

import SwiftUI

struct VideoView: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?

    func makeUIViewController(context: Context) -> VideoViewController {
        let viewController = VideoViewController()
        if let url = selectedURL {
            viewController.loadVideo(url: url)
        }
        return viewController
    }

    func updateUIViewController(_ uiViewController: VideoViewController, context: Context) {
        if let url = selectedURL {
            uiViewController.loadVideo(url: url)
        }
    }

    typealias UIViewControllerType = VideoViewController
}
