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
            Label("Received", systemImage: "tray.and.arrow.down.fill")
        }
    MainView()
        .tabItem {
            Label("Sent", systemImage: "tray.and.arrow.up.fill")
        }
//    AccountView()
//        .badge("!")
//        .tabItem {
//            Label("Account", systemImage: "person.crop.circle.fill")
//        }
}
   }
}
