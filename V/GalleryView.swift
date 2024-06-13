import SwiftUI
import AVFoundation

struct GalleryView: View {
    @State var processingFiles: [URL] = []
    @State private var thumbnails: [URL: NSImage] = [:]
    @State private var selectedURL: URL?
    @StateObject var galleryModel = GalleryModel()
    @State private var showVideoView = false

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationView {
        HStack {
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
                        .background(NavigationLink(destination: VideoView(selectedURL: $selectedURL), isActive: $showVideoView) {
                EmptyView()
            }.hidden())

            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: addFiles) {
                        Label("Add Files", systemImage: "plus")
                    }
                }
            }
}
.frame(minWidth: 600, maxWidth: 4000)
HStack{
            if let url = selectedURL {
                SidebarView(url: url)
                .frame(minWidth: 250, idealWidth: 250, maxWidth:255)
                .fixedSize()
            }
                                    }
        }
        .navigationTitle("Gallery")
        .frame(width: 150)
                    .onAppear {
                galleryModel.loadFiles()

    }
}
private func thumbnailView(for url: URL) -> some View {
    Image(nsImage: thumbnails[url] ?? NSImage())
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 100, height: 100)
        .contextMenu {
            Button("Detection") {
                selectedURL = url
                showVideoView = true  // Assuming 'showVideoView' triggers navigation
            }
            Button("Delete", action: { deleteFile(url) })
            // Other buttons...
        }
}

    private func addFiles() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.begin { response in
            if response == .OK {
                self.processingFiles.append(contentsOf: openPanel.urls)
                generateThumbnails()
            }
        }
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
        let fileExtension = url.pathExtension.lowercased()
        if fileExtension == "mov" || fileExtension == "mp4" {
            return generateVideoThumbnail(for: url)
        } else {
            return generateImageThumbnail(for: url)
        }
    }
    private func generateVideoThumbnail(for url: URL) -> NSImage? {
        let asset = AVAsset(url: url)
        let assetImageGenerator = AVAssetImageGenerator(asset: asset)
        assetImageGenerator.appliesPreferredTrackTransform = true
        let timestamp = CMTime(seconds: 1, preferredTimescale: 60)
        do {
            let imageRef = try assetImageGenerator.copyCGImage(at: timestamp, actualTime: nil)
            return NSImage(cgImage: imageRef, size: NSSize(width: 100, height: 100)) // Size can be adjusted
        } catch {
            print("Error generating video thumbnail: \(error)")
            return nil
        }
    }

    private func generateImageThumbnail(for url: URL) -> NSImage? {
        if let image = NSImage(contentsOf: url) {
            let targetSize = NSSize(width: 100, height: 100) // Specify your desired thumbnail size
            return image.resized(to: targetSize)
        }
        return nil
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
        VStack() {
            Text("File Information")
                .font(.headline)
            Text("Name: \(url.lastPathComponent)")
            Text("Size: \(fileSize(for: url))")
            Text("Path: \(url.path)")
                }
        .padding()
        .frame(minWidth: 100, idealWidth: 250, maxWidth: 300)
        .fixedSize(horizontal: true, vertical: false) // Fix the horizontal size but allow vertical flexibility
        .background(Color.gray.opacity(0.1)) // Optional: Add a background color to make the sidebar stand out
        .cornerRadius(10) // Optional: Add corner radius for better UI
    }
    
             

    private func fileSize(for url: URL) -> String {
        // Return formatted file size
        return "Unknown Size"
    }
}
extension NSImage {
    func resized(to newSize: NSSize) -> NSImage {
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: newSize),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .sourceOver,
                  fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}
