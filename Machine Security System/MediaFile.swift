//
//  MediaFile.swift
//  Machine Security System
//
//  Created by Almahdi Morris on 31/5/24.
//
import Foundation
import SwiftUI

enum MediaType {
    case image
    case video
}

struct MediaFile: Identifiable {
    let id: UUID
    let name: String
    let type: MediaType
    let url: URL
    var previewImage: UIImage? = nil
    
    init(name: String, type: MediaType, url: URL, previewImage: UIImage? = nil) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.url = url
        self.previewImage = previewImage
    }
}
