//
//  VApp.swift
//  V
//
//  Created by Almahdi Morris on 4/6/24.
//

import SwiftUI

@main
struct VApp: App {
    @StateObject private var processor = CoreMLProcessor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                                .environmentObject(processor)

        }
    }
}
