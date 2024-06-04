  //
  //  GalleryViewModel.swift
  //  Machine Security System
  //
  //  Created by Almahdi Morris on 31/5/24.
  //
import SwiftUI
import AVFoundation
import Vision
import UIKit
import UniformTypeIdentifiers

enum SortOption: String, CaseIterable, Identifiable {
    case name
    case type
    
    var id: String { self.rawValue }
}

class GalleryViewModel: NSObject, ObservableObject, UIDocumentPickerDelegate {
    @Published var files: [MediaFile] = []
    @Published var isLoading = false
    @Published var sortOption: SortOption = .name
    @Published var previewFileIndex: Int?
    @Published var selectedVideoURL: URL?

    func selectFiles() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.image, UTType.movie], asCopy: true)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = true
        
        if let rootVC = UIApplication.shared.windows.first?.rootViewController {
            rootVC.present(documentPicker, animated: true, completion: nil)
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        DispatchQueue.global(qos: .userInitiated).async {
            for file in urls {
                if !self.files.contains(where: { $0.url == file.standardizedFileURL }) {
                    let type: MediaType = file.pathExtension.lowercased() == "mov" || file.pathExtension.lowercased() == "mp4" ? .video : .image
                    let newFile = MediaFile(name: file.lastPathComponent, type: type, url: file.standardizedFileURL)
                    self.setPreviewImage(for: newFile)
                    DispatchQueue.main.async {
                        withAnimation {
                            self.files.append(newFile)
                        }
                    }
                }
            }
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    func setPreviewImage(for file: MediaFile) {
        switch file.type {
        case .image:
            if let image = UIImage(contentsOfFile: file.url.path) {
                updatePreviewImage(for: file, with: image)
            }
        case .video:
            let videoAsset = AVAsset(url: file.url)
            let generator = AVAssetImageGenerator(asset: videoAsset)
            let time = CMTime(value: 1, timescale: 1)
            
            generator.generateCGImageAsynchronously(for: time) { image, actualTime, error in
                if let img = image {
                    let previewImage = UIImage(cgImage: img)
                    self.updatePreviewImage(for: file, with: previewImage)
                }
            }
        }
    }
    
    private func updatePreviewImage(for file: MediaFile, with image: UIImage) {
        DispatchQueue.main.async {
            if let index = self.files.firstIndex(where: { $0.id == file.id }) {
                self.files[index].previewImage = image
            }
        }
    }
    
    func loadFiles() {
        // Load previously saved files if needed
    }
    
    var sortedFiles: [MediaFile] {
        switch sortOption {
        case .name:
            return files.sorted { $0.name < $1.name }
        case .type:
            return files.sorted { $0.type == .image && $1.type == .video }
        }
    }
}
