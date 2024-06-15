import SwiftUI

struct VideoViewContainer: View {
    @Binding var selectedURL: URL?

    var body: some View {
        VStack {
            VideoView(selectedURL: $selectedURL)
                .toolbar {
//                    Toggle(isOn: $showBoundingBoxes) {
//                        Label("Bounding Boxes", systemImage: "rectangle")
//                    }
//                    .toggleStyle(SwitchToggleStyle())
//
//                    Toggle(isOn: $logDetections) {
//                        Label("Log Detections", systemImage: "doc.text")
//                    }
//                    .toggleStyle(SwitchToggleStyle())
                }

            DetectionStatsView()
                .frame(height: 200)
                .padding()
        }
        .environmentObject(DetectionStats.shared)
    }
}
