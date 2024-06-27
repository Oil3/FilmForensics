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
      FaceContentView()
        .tabItem {
          Label("Video Tools View", systemImage: "wrench")
        }
      ForensicView()
        .tabItem {
          Label("ForensicView", systemImage: "wrench")
        }
}
    }
  }
//}
