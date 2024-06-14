//
//  VideoViewContainer.swift
//  V
//
//  Created by Almahdi Morris on 13/6/24.
//
import SwiftUI
struct VideoViewContainer: View {
    @Binding var selectedURL: URL?

    var body: some View {
        VideoView(selectedURL: $selectedURL)
            .toolbar {
//                Toggle(isOn: $showBoundingBoxes) {
//                    Label("Bounding Boxes", systemImage: "rectangle")
//                }
//                .toggleStyle(SwitchToggleStyle())
//
//                Toggle(isOn: $logDetections) {
//                    Label("Log Detections", systemImage: "doc.text")
//                }
//                .toggleStyle(SwitchToggleStyle())
            }
    }
}


struct Stats: Identifiable {
    var id: UUID = UUID()
    var key: String
    var value: String
}
