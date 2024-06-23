//
//  ContentView.swift
//  MLmedia
//
//  Created by Almahdi Morris on 17/6/24.
//
import SwiftUI

struct ContentView: View {
  var body: some View {
    TabView {
      MainVideoView()
        .tabItem {
          Label("Main Video View", systemImage: "video")
        }
      VideoToolsView()
        .tabItem {
          Label("Video Tools View", systemImage: "wrench")
        }
      MLcaptureMainView()
        .tabItem {
          Label("MLcaptureMainView", systemImage: "bolt")
        }
    }
  }
}
