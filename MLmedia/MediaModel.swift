import SwiftUI

class MediaModel: ObservableObject {
    @Published var videos: [URL] = []
    @Published var selectedVideoURL: URL?
    
    func addVideos() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.allowedFileTypes = ["mp4", "mov"]
        if panel.runModal() == .OK {
            videos.append(contentsOf: panel.urls)
        }
    }
    
    func clearVideos() {
        videos.removeAll()
        selectedVideoURL = nil
    }
}
