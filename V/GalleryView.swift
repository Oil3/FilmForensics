//
//  GalleryView.swift
//  V
//
//  Created by Almahdi Morris on 11/6/24.
//
import SwiftUI
import AVFoundation

struct GalleryView: View {
    @Binding var processingFiles: [URL]
    @State private var thumbnails: [URL: NSImage] = [:]
    @State private var selectedURL: URL?

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(processingFiles, id: \.self) { url in
                        thumbnailView(for: url)
                            .contextMenu {
                                Button("Delete", action: { deleteFile(url) })
                                Button("Rename", action: { renameFile(url) })
                                Button("Tag", action: { tagFile(url) })
                                Button("Save to Project", action: { saveToProject(url) })
                                Button("Show in Finder", action: { showInFinder(url) })
                            }
                            .border(selectedURL == url ? Color.blue : Color.clear, width: 3)
                            .onTapGesture {
                                selectedURL = url
                            }
                            .onDrag {
                                NSItemProvider(object: url as NSURL)
                            }
                    }
                }
            }
            .onAppear {
                generateThumbnails()
            }
            .frame(minWidth: 400)

            if let url = selectedURL {
                SidebarView(url: url)
            }
        }
        .navigationTitle("Gallery")
    }

    private func thumbnailView(for url: URL) -> some View {
      Image(nsImage: thumbnails[url] ?? NSImage())
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 100, height: 100)
    }

    private func generateThumbnails() {
        processingFiles.forEach { url in
            DispatchQueue.global(qos: .userInitiated).async {
                let thumbnail = generateThumbnail(for: url)
                DispatchQueue.main.async {
                    thumbnails[url] = thumbnail
                }
            }
        }
    }

    private func generateThumbnail(for url: URL) -> NSImage? {
        let asset = AVAsset(url: url)
        let assetImageGenerator = AVAssetImageGenerator(asset: asset)
        assetImageGenerator.appliesPreferredTrackTransform = true
        let timestamp = CMTime(seconds: 1, preferredTimescale: 60)
        do {
            let imageRef = try assetImageGenerator.copyCGImage(at: timestamp, actualTime: nil)
          return NSImage(cgImage: imageRef, size: NSSize())
        } catch {
            print("Error generating thumbnail: \(error)")
            return nil
        }
    }

    private func deleteFile(_ url: URL) {
        if let index = processingFiles.firstIndex(of: url) {
            processingFiles.remove(at: index)
            thumbnails.removeValue(forKey: url)
        }
    }

    private func renameFile(_ url: URL) {
        // Implement renaming logic
    }

    private func tagFile(_ url: URL) {
        // Implement tagging logic
    }

    private func saveToProject(_ url: URL) {
        // Implement save to project logic
    }

    private func showInFinder(_ url: URL) {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }
}

struct SidebarView: View {
    var url: URL

    var body: some View {
        VStack(alignment: .leading) {
            Text("File Information")
                .font(.headline)
            Text("Name: \(url.lastPathComponent)")
            Text("Size: \(fileSize(for: url))")
            Text("Path: \(url.path)")
        }
        .padding()
    }

    private func fileSize(for url: URL) -> String {
        // Return formatted file size
        return "Unknown Size"
    }
}
