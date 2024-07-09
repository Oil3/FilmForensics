  //
  //  CoreMLProcessorView.swift
  //  V
  //
  // Copyright Almahdi Morris - 4/6/24.
  //
import SwiftUI
import AVKit
import Vision
import QuickLook

struct CoreMLProcessView: View {
    @EnvironmentObject var processor: CoreMLProcessor
    @State private var processingFiles: [URL] = []
    @State private var selectedMediaItem: URL?
    @State private var selectedDetectionFrames: Set<CoreMLProcessor.DetectionFrame> = []
    @State private var isStatsEnabled: Bool = true
    @State private var currentFileIndex: Int = 0
    @State private var currentDetectionFrameIndex: Int = 0
    @State private var previewItem: IdentifiableURL?

    var body: some View {
        VStack {
            HStack {
                Button("Select Files") {
                    processor.selectFiles { urls in
                        processingFiles = urls
                        print("Selected files: \(processingFiles)") // Debug message
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

                Button("Clear Frames", action: clearFrames)
                    .padding()

                Button("Export Selected", action: exportSelectedFrames)
                    .padding()

                Button("Export All", action: exportAllFrames)
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

            Text("Local Files (\(currentFileIndex + 1)/\(processingFiles.count))")
                .font(.headline)
                .padding()

            ScrollView(.horizontal, showsIndicators: true) {
                LazyHStack(spacing: 10) {
                    ForEach(processingFiles.indices, id: \.self) { index in
                        let file = processingFiles[index]
                        Image(uiImage: thumbnail(for: file))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 150, height: 150)
                            .contextMenu {
                                Button("Copy", action: { copyFile(file) })
                                Button("Export", action: { exportFile(file) })
                                Button("Select All", action: { selectAllFiles() })
                            }
                            .onTapGesture {
                                selectedMediaItem = file
                                currentFileIndex = index
                                print("Selected file: \(file)")
                            }
                            .onTapGesture(count: 2) {
                                previewItem = IdentifiableURL(url: file)
                            }
                    }
                }
            }
            .frame(height: 200)
            .padding()
            .onAppear {
                if processingFiles.count > 0 {
                    selectedMediaItem = processingFiles[currentFileIndex]
                }
            }
            .onKeyDown { key in
                handleKeyDown(key)
            }

            Text("Detection Frames (\(currentDetectionFrameIndex + 1)/\(processor.detectionFrames.count))")
                .font(.headline)
                .padding()

            ScrollView(.horizontal, showsIndicators: true) {
                LazyHStack(spacing: 10) {
                    ForEach(processor.detectionFrames.indices, id: \.self) { index in
                        let frame = processor.detectionFrames[index]
                        if let imageData = try? Data(contentsOf: frame.imageURL), let image = UIImage(data: imageData) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 150, height: 150)
                                .overlay(
                                    Text("\(String(format: "%.2f", frame.timestamp))s")
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.7))
                                        .padding(4),
                                    alignment: .bottom
                                )
                                .border(selectedDetectionFrames.contains(frame) ? Color.blue : Color.clear, width: 3)
                                .contextMenu {
                                    Button("Copy", action: { copyFrame(frame) })
                                    Button("Export", action: { exportFrame(frame) })
                                    Button("Select All", action: { selectAllFrames() })
                                    Button("Select All Before", action: { selectAllFrames(before: frame) })
                                    Button("Select All After", action: { selectAllFrames(after: frame) })
                                }
                                .onTapGesture {
                                    if selectedDetectionFrames.contains(frame) {
                                        selectedDetectionFrames.remove(frame)
                                    } else {
                                        selectedDetectionFrames.insert(frame)
                                    }
                                    currentDetectionFrameIndex = index
                                }
                                .onTapGesture(count: 2) {
                                    previewItem = IdentifiableURL(url: frame.imageURL)
                                }
                        }
                    }
                }
            }
            .frame(height: 200)
            .padding()

            if let selectedImage = processor.selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .overlay(
                        BoundingBoxViewWrapper(observations: $processor.currentObservations, image: selectedImage)
                    )
                    .padding()
            }

            if let selectedVideo = processor.selectedVideo {
                VideoPlayer(player: AVPlayer(url: selectedVideo))
                    .frame(maxHeight: 300)
                    .padding()
            }

            // Thumbnail, Detection Frame, and Resized Image views have been omitted for brevity.
            // They should be adapted similarly with correct APIs and handling for macOS.
        }
        .padding()
        .sheet(item: $previewItem) { item in
            QuickLookPreview(url: item.url)
        }
    }

    private func clearFrames() {
        processor.detectionFrames.removeAll()
        selectedDetectionFrames.removeAll()
    }

    private func exportSelectedFrames() {
        let selectedURLs = selectedDetectionFrames.map { $0.imageURL }
        exportImages(from: selectedURLs)
    }

    private func exportAllFrames() {
        let allURLs = processor.detectionFrames.map { $0.imageURL }
        exportImages(from: allURLs)
    }

    private func copyFrame(_ frame: CoreMLProcessor.DetectionFrame) {
        if let imageData = try? Data(contentsOf: frame.imageURL), let image = UIImage(data: imageData) {
            UIPasteboard.general.image = image
        }
    }

    private func exportFrame(_ frame: CoreMLProcessor.DetectionFrame) {
        exportImages(from: [frame.imageURL])
    }

    private func exportImages(from urls: [URL]) {
        var images: [UIImage] = []
        for url in urls {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                images.append(image)
            }
        }
        guard !images.isEmpty else { return }
        let activityViewController = UIActivityViewController(activityItems: images, applicationActivities: nil)
        guard let window = UIApplication.shared.windows.first else { return }
        window.rootViewController?.present(activityViewController, animated: true, completion: nil)
    }

    private func selectAllFrames() {
        selectedDetectionFrames = Set(processor.detectionFrames)
    }

    private func selectAllFrames(before frame: CoreMLProcessor.DetectionFrame) {
        if let index = processor.detectionFrames.firstIndex(of: frame) {
            selectedDetectionFrames = Set(processor.detectionFrames.prefix(index))
        }
    }

    private func selectAllFrames(after frame: CoreMLProcessor.DetectionFrame) {
        if let index = processor.detectionFrames.firstIndex(of: frame) {
            selectedDetectionFrames = Set(processor.detectionFrames.suffix(from: index))
        }
    }

    private func thumbnail(for url: URL) -> UIImage {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        let timestamp = CMTime(seconds: 1, preferredTimescale: 60)
        do {
            let imageRef = try imageGenerator.copyCGImage(at: timestamp, actualTime: nil)
            return UIImage(cgImage: imageRef)
        } catch {
            return UIImage()
        }
    }

    private func copyFile(_ url: URL) {
        UIPasteboard.general.url = url
    }

    private func exportFile(_ url: URL) {
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let window = UIApplication.shared.windows.first else { return }
        window.rootViewController?.present(activityViewController, animated: true, completion: nil)
    }

    private func selectAllFiles() {
        // Implement your select all files functionality
    }

    private func handleKeyDown(_ key: Key) {
        switch key {
        case .leftArrow:
            if currentFileIndex > 0 {
                currentFileIndex -= 1
                selectedMediaItem = processingFiles[currentFileIndex]
            }
        case .rightArrow:
            if currentFileIndex < processingFiles.count - 1 {
                currentFileIndex += 1
                selectedMediaItem = processingFiles[currentFileIndex]
            }
        default:
            break
        }
    }
}

struct KeyDownModifier: ViewModifier {
    let keyDownHandler: (Key) -> Void

    func body(content: Content) -> some View {
        content
            .background(KeyDownHandlingView(keyDownHandler: keyDownHandler))
    }
}

extension View {
    func onKeyDown(perform action: @escaping (Key) -> Void) -> some View {
        self.modifier(KeyDownModifier(keyDownHandler: action))
    }
}

struct KeyDownHandlingView: UIViewRepresentable {
    let keyDownHandler: (Key) -> Void

    class Coordinator: NSObject, UIKeyInput {
        var keyDownHandler: (Key) -> Void

        init(keyDownHandler: @escaping (Key) -> Void) {
            self.keyDownHandler = keyDownHandler
        }

        var hasText: Bool = false

        func insertText(_ text: String) {}

        func deleteBackward() {}

         func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            guard let key = presses.first?.key else { return }

            switch key.keyCode {
            case .keyboardLeftArrow:
                keyDownHandler(.leftArrow)
            case .keyboardRightArrow:
                keyDownHandler(.rightArrow)
            default:
                break
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(keyDownHandler: keyDownHandler)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.becomeFirstResponder()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        uiView.resignFirstResponder()
    }
}

enum Key {
    case leftArrow
    case rightArrow
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        var parent: QuickLookPreview

        init(_ parent: QuickLookPreview) {
            self.parent = parent
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            parent.url as NSURL
        }
    }
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}
