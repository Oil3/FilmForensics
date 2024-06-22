//
//  ContentView.swift
//  MLmedia
//
//  Created by Almahdi Morris on 17/6/24.
//
import SwiftUI

struct ContentView:  View {
    var body: some View {

TabView {
MainVideoView()
        .badge(2)
        .tabItem {
            Label("MainVideoView", systemImage: "tray.and.arrow.down.fill")
        }
    VideoToolsView()
        .tabItem {
            Label("VideoToolsView", systemImage: "tray.and.arrow.up.fill")
        }
            BatchProcessingView() //placeholder
        .tabItem {
            Label("BatchProcessingView", systemImage: "cube.box")
        }
}
   }
}
