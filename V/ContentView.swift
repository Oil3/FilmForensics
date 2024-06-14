import SwiftUI

struct ContentView: View {
    @State private var selectedURL: URL?
    @State private var showDocumentPicker = false
    @State private var processingFiles: URL?

    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink(destination: VideoViewContainer(selectedURL: $selectedURL)) {
                    Label("Video", systemImage: "video")
                }
                NavigationLink(destination: LogView()) {
                    Label("View Logs", systemImage: "doc.text")
                }
                NavigationLink(destination: GalleryView()) {
                    Label("Gallery", systemImage: "photo.on.rectangle")
                }
                NavigationLink(destination: SettingsView())  {
                    Label("Settings", systemImage: "gearshape")
                }
                NavigationLink(destination: CoreMLProcessView()) {
                    Label("CoreML", systemImage: "brain")
                }
            }
            .listStyle(SidebarListStyle())
            .frame(maxWidth: .infinity)
            .navigationTitle("Machine Security System")
            .overlay(
                VStack {
                    Spacer()
                    DetectionStatsView()
                        .environmentObject(DetectionStats.shared)
                        .padding()
                }
            )
        } detail: {
            Text("Select an item from the sidebar")
                .foregroundColor(.gray)
        }
        .environmentObject(DetectionStats.shared)
    }
}
