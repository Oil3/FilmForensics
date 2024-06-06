//
//  ContentView.swift
//  Machine Security System
//
// Copyright Almahdi Morris - 04/25/24.
//
import SwiftUI

struct ContentView: View {
  //  @Binding var videoURL: URL

    var body: some View {
        NavigationView {
            Sidebar()
          VideoView()

                  }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
    }
}
