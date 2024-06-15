import SwiftUI

struct ContentView: View {
    @State private var selectedURL: URL?
    @State private var showDocumentPicker = false
    @State private var processingFiles: URL?

    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink(destination: VideoViewContainer(selectedURL: $selectedURL).environmentObject(DetectionStats.shared)) {
                    Label("Video", systemImage: "video")
                }
                NavigationLink(destination: LogView()) {
                    Label("View Logs", systemImage: "doc.text")
                }
                NavigationLink(destination: GalleryView()) {
                    Label("Gallery", systemImage: "photo.on.rectangle")
                }
                NavigationLink(destination: SettingsView()) {
                    Label("Settings", systemImage: "gearshape")
                }
                NavigationLink(destination: CoreMLProcessView()) {
                    Label("CoreML", systemImage: "brain")
                }
            }
            .listStyle(SidebarListStyle())
            .frame(maxWidth: .infinity)
            .navigationTitle("Machine Security System")
        } detail: {
            VStack {
                Text("Select an item from the sidebar")
                    .foregroundColor(.gray)
                DetectionStatsView()
                    .environmentObject(DetectionStats.shared)
            }
        }
    }
}
