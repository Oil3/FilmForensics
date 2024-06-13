import SwiftUI
import AVKit
import Vision

struct CoreMLProcessView: View {
    @EnvironmentObject var processor: CoreMLProcessor
    @State private var processingFiles: [URL] = []
    @State private var selectedMediaItem: URL?
    @State private var selectedDetectionFrames: [CoreMLProcessor.DetectionFrame] = []
    @State private var isStatsEnabled: Bool = true
    @State private var currentFileIndex: Int = 0
    @State private var currentDetectionFrameIndex: Int = 0

    var body: some View {
        VStack {
            HStack {
                Button("Select Files") {
                    processor.selectFiles { urls in
                        processingFiles = urls
                        print("Selected files: \(processingFiles)")
                    }
                }
                .padding()

                Button("Start Processing") {
                    processor.startProcessing(urls: processingFiles, confidenceThreshold: 0.5, iouThreshold: 0.5, noVideoPlayback: false)
                }
                .padding()

                Button("Stop Processing") {
                    processor.stopProcessing()
                }
                .padding()

                Picker("Resized Output", selection: $processor.selectedResizedImageKey) {
                    Text("640x640").tag("output_640")
                    Text("416x416").tag("output_416")
                    Text("1280x720").tag("output_720p")
                    Text("512x512").tag("output_512")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                Spacer()

                VStack {
                    Text("Stats")
                        .font(.headline)
                        .padding()

                    Toggle("Show Stats", isOn: $isStatsEnabled)
                        .padding()

                    if isStatsEnabled {
                        Text(processor.stats)
                            .padding()
                    }
                }
                .padding(.trailing)
            }

            // Thumbnail, Detection Frame, and Resized Image views have been omitted for brevity.
            // They should be adapted similarly with correct APIs and handling for macOS.
        }
        .padding()
    }
}

// macOS-specific implementations for handling file operations, image processing, and previews.
extension CoreMLProcessView {
    private func thumbnail(for url: URL) -> NSImage {
        // Placeholder for thumbnail generation logic
        return NSImage()
    }

    private func selectAllFiles() {
        // Implement your select all files functionality
    }
}

//
struct IdentifiableURL: Identifiable {
    var id: URL { url }
    let url: URL
}

//extension CGRect: Hashable {
//    public var hashValue: Int {
//        return NSCoder.string(for: self).hashValue
//    }
//}
