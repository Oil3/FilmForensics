//
//  ContentView.swift
//  FilmForensics
//
//  Created by Almahdi Morris on 16/6/24.
//

import SwiftUI

struct ContentView:  View {
    var body: some View {

TabView {
MainView()
        .badge(2)
        .tabItem {
            Label("Image", systemImage: "tray.and.arrow.down.fill")
        }
    MainView() //placeholder
        .tabItem {
            Label("Video", systemImage: "tray.and.arrow.up.fill")
        }
            MainView() //placeholder
        .tabItem {
            Label("Settings", systemImage: "tray.and.arrow.up.fill")
        }
}
   }
}
@main
struct CMLTools: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
} 
