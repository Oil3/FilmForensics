//
//  GalleryViewModel.swift
//  V
//
//  Created by Almahdi Morris on 13/6/24.
//

import SwiftUI
import Combine

class GalleryModel: ObservableObject {
    @Published var files: [FileItem] = []

    init() {
        loadFiles()
    }

    func loadFiles() {
        // Dummy function to simulate loading files
        // In practice, replace with actual file loading logic
    }
}

struct FileItem: Identifiable {
    let id = UUID()
    let url: URL
    var thumbnail: NSImage?
}
