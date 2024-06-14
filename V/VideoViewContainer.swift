import SwiftUI

struct VideoViewContainer: View {
    @Binding var selectedURL: URL?
    @State private var showBoundingBoxes = true
    @State private var logDetections = true
    @EnvironmentObject var detectionStats: DetectionStats

    var body: some View {
        VideoView(selectedURL: $selectedURL, showBoundingBoxes: $showBoundingBoxes, logDetections: $logDetections)
            .toolbar {
                Toggle(isOn: $showBoundingBoxes) {
                    Label("Bounding Boxes", systemImage: "rectangle")
                }
                .toggleStyle(SwitchToggleStyle())

                Toggle(isOn: $logDetections) {
                    Label("Log Detections", systemImage: "doc.text")
                }
                .toggleStyle(SwitchToggleStyle())
            }
            .environmentObject(detectionStats)
    }
}
