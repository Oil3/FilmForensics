//
//  VideoPicker.swift
//  FilmForensics
//
// Copyright Almahdi Morris - 05/22/24.
//
import SwiftUI
import AVKit
import UniformTypeIdentifiers

struct VideoPicker: NSViewControllerRepresentable {
    @Binding var videoURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSViewController(context: Context) -> NSViewController {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = [UTType.movie.identifier]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.videoURL = url
            }
            context.environment.presentationMode.wrappedValue.dismiss()
        }
        return NSViewController()
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}

    class Coordinator: NSObject, NSOpenSavePanelDelegate {
        let parent: VideoPicker

        init(parent: VideoPicker) {
            self.parent = parent
        }
    }
}

