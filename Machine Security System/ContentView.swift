//
//  ContentView.swift
//  Machine Security System
//
//  Created by Almahdi Morris on 04/25/24.
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
