//
//  ImagePicker.swift
//  FilmForensics
//
//  Created by Almahdi Morris on 05/22/24.
//
import SwiftUI
import AppKit

struct ImagePicker: NSViewControllerRepresentable {
    class Coordinator: NSObject, NSOpenSavePanelDelegate {
        let parent: ImagePicker

        init(parent: ImagePicker) {
            self.parent = parent
        }
    }

    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedImage: NSImage?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSViewController(context: Context) -> NSViewController {
        let panel = NSOpenPanel()
        panel.delegate = context.coordinator
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = ["jpg", "png"]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.selectedImage = NSImage(contentsOf: url)
            }
            self.presentationMode.wrappedValue.dismiss()
        }
        return NSViewController()
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}
}
