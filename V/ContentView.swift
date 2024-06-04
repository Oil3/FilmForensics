//
//  ContentView.swift
//  V
//
//  Created by Almahdi Morris on 4/6/24.
//

import SwiftUI
struct ContentView: View {
    @State private var selectedURL: URL?
    @State private var showDocumentPicker = false

    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink(destination: VideoView(selectedURL: $selectedURL)) {
                    Label("Video", systemImage: "video")
                }
                NavigationLink(destination: Text("View Logs")) {
                    Label("View Logs", systemImage: "doc.text")
                }
//                NavigationLink(destination: GalleryView(selectedURL: $selectedURL)) {
//                    Label("Gallery", systemImage: "photo.on.rectangle")
//                }
                NavigationLink(destination: Text("Settings")) {
                    Label("Settings", systemImage: "gearshape")
                }
                NavigationLink(destination: CoreMLProcessView()) {
                    Label("CoreML", systemImage: "brain")
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Machine Security System")
        } detail: {
            Text("Select an item from the sidebar")
                .foregroundColor(.gray)
        }
    }
}
