//
//  CameraView.swift
//  Machine Security System
//
//  Created by Almahdi Morris on 31/5/24.
//
import SwiftUI

struct CameraView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CameraViewController {
        return CameraViewController()
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        // Perform any updates to the UI based on changes in SwiftUI environment if necessary.
    }

    typealias UIViewControllerType = CameraViewController
}
