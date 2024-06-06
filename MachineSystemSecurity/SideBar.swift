//
//  SideBar.swift
//  Machine Security System
//
// Copyright Almahdi Morris - 31/5/24.
//

import SwiftUI

struct Sidebar: View {
    var body: some View {
        List {
            NavigationLink(destination: CameraView()) {
                Label("Camera", systemImage: "camera")
            }
            NavigationLink(destination: VideoView()) {
                Label("Video", systemImage: "video")
            }
            NavigationLink(destination: LogView()) {
                Label("View Logs", systemImage: "doc.text.magnifyingglass")
            }
            NavigationLink(destination: GalleryView()) {
                Label("Gallery", systemImage: "photo.on.rectangle.angled")
            }
            NavigationLink(destination: SettingsView()) {
                Label("Settings", systemImage: "gear")
            }
            NavigationLink(destination: CoreMLView()) {
                Label("CoreML", systemImage: "brain.head.profile")
            }
        }
                    .frame(minWidth: 70)

        .listStyle(SidebarListStyle())
        .navigationTitle("Menu")
    }
}
