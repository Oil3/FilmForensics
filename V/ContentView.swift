<<<<<<< refs/remotes/origin/main2
=======
//
//  ContentView.swift
//  V
//
// Copyright Almahdi Morris - 4/6/24.
//

>>>>>>> fixed abnormal memory usage (with lazy loading frames -10,000 png images kinda weight)
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
<<<<<<< refs/remotes/origin/main2
                NavigationLink(destination: GalleryView()) {
                    Label("Gallery", systemImage: "photo.on.rectangle")
                }
                NavigationLink(destination: SettingsView()) {
=======
//                NavigationLink(destination: GalleryView(selectedURL: $selectedURL)) {
//                    Label("Gallery", systemImage: "photo.on.rectangle")
//                }
                NavigationLink(destination: SettingsView())  {
>>>>>>> fixed abnormal memory usage (with lazy loading frames -10,000 png images kinda weight)
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
