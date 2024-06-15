  //
  //  MainView.swift
  //  ToolML
  //
  //  Created by Almahdi Morris on 15/6/24.
  //
import SwiftUI
import CoreML
import Vision
import AVKit

struct MainView: View {
    @State private var selectedMediaModel: MediaModel? {
        didSet {
            if let mediaModel = selectedMediaModel {
                if mediaModel.type == .image {
                    mediaModel.loadImage()
                    if let image = mediaModel.image {
                        runModel(on: image)
                    }
                } else if mediaModel.type == .video {
                    mediaModel.startVideo()
                }
            }
        }
    }
    @State private var detectedObjects: [VNRecognizedObjectObservation] = []
    @State private var galleryMediaModels: [MediaModel] = []
    @State private var imageSize: CGSize = .zero
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationSplitView {
            List(galleryMediaModels, id: \.self, selection: $selectedMediaModel) { mediaModel in
                MediaView(mediaModel: mediaModel)
                    .frame(width: 100, height: 100)
                    .padding(2)
                    .background(selectedMediaModel?.id == mediaModel.id ? Color.blue.opacity(0.3) : Color.clear)
                    .onTapGesture {
                        self.selectedMediaModel = mediaModel
                    }
            }
            .frame(width: 120)
            .background(
                Rectangle()
                    .stroke(Color.gray, lineWidth: 1)
            )
            .onDrop(of: ["public.file-url"], isTargeted: nil, perform: handleDrop)
            .focused($isFocused)
        } detail: {
            VStack {
                if let mediaModel = selectedMediaModel {
                    GeometryReader { geometry in
                        ZStack {
                            if mediaModel.type == .image, let image = mediaModel.image {
                                Image(nsImage: image)
                                    .resizable()
                                    .background(GeometryReader { geo -> Color in
                                        DispatchQueue.main.async {
                                            self.imageSize = geo.size
                                        }
                                        return Color.clear
                                    })
                                ForEach(detectedObjects, id: \.self) { object in
                                    drawBoundingBox(for: object, in: geometry.size)
                                }
                            } else if mediaModel.type == .video {
                                if let videoPlayer = mediaModel.videoPlayer {
                                    VideoPlayer(player: videoPlayer)
                                        .background(GeometryReader { geo -> Color in
                                            DispatchQueue.main.async {
                                                self.imageSize = geo.size
                                            }
                                            return Color.clear
                                        })
                                        .overlay(
                                            GeometryReader { geo -> AnyView in
                                                if let frame = mediaModel.currentFrame {
                                                    DispatchQueue.main.async {
                                                        self.imageSize = geo.size
                                                        runModel(on: frame)
                                                    }
                                                    return AnyView(
                                                        ZStack {
                                                            Image(nsImage: frame)
                                                                .resizable()
                                                                .background(GeometryReader { geo -> Color in
                                                                    DispatchQueue.main.async {
                                                                        self.imageSize = geo.size
                                                                    }
                                                                    return Color.clear
                                                                })
                                                            ForEach(detectedObjects, id: \.self) { object in
                                                                drawBoundingBox(for: object, in: geo.size)
                                                            }
                                                        }
                                                    )
                                                } else {
                                                    return AnyView(EmptyView())
                                                }
                                            }
                                        )
                                        .onDisappear {
                                            mediaModel.pauseVideo()
                                        }
                                } else {
                                    Text("No Video Player Available")
                                }
                            }
                        }
                    }
                } else {
                    Text("No Media Selected")
                }
            }
        }
        .padding()
        .onAppear {
            isFocused = true
            addCommandShortcuts()
        }
    }

    func addCommandShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "o" {
                selectMedia()
                return nil
            }
            return event
        }
    }

    func selectMedia() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["png", "jpg", "jpeg", "mp4", "mov"]
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                let type: MediaType = url.pathExtension.lowercased() == "mp4" || url.pathExtension.lowercased() == "mov" ? .video : .image
                let mediaModel = MediaModel(url: url, type: type)
                galleryMediaModels.append(mediaModel)
                selectLatestMedia()
            }
        }
    }

    func clearMedia() {
        selectedMediaModel = nil
        detectedObjects.removeAll()
        galleryMediaModels.removeAll()
    }

    func selectLatestMedia() {
        if let latestMediaModel = galleryMediaModels.last {
            selectedMediaModel = latestMediaModel
        }
    }

    func runModel(on image: NSImage) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let model = try! VNCoreMLModel(for: best().model)

        let request = VNCoreMLRequest(model: model) { request, error in
            if let results = request.results as? [VNRecognizedObjectObservation] {
                DispatchQueue.main.async {
                    self.detectedObjects = results
                }
            }
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }

    func drawBoundingBox(for observation: VNRecognizedObjectObservation, in parentSize: CGSize) -> some View {
        let boundingBox = observation.boundingBox
        let imageWidth = imageSize.width
        let imageHeight = imageSize.height
        
        let normalizedRect = CGRect(
            x: boundingBox.minX * imageWidth,
            y: (1 - boundingBox.maxY) * imageHeight,
            width: boundingBox.width * imageWidth,
            height: boundingBox.height * imageHeight
        )
        
        return Rectangle()
            .stroke(Color.red, lineWidth: 2)
            .frame(width: normalizedRect.width, height: normalizedRect.height)
            .position(x: normalizedRect.midX, y: normalizedRect.midY)
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        var addedMediaModels = [MediaModel]()
        let dispatchGroup = DispatchGroup()

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                dispatchGroup.enter()
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        let type: MediaType = url.pathExtension.lowercased() == "mp4" || url.pathExtension.lowercased() == "mov" ? .video : .image
                        let mediaModel = MediaModel(url: url, type: type)
                        DispatchQueue.main.async {
                            addedMediaModels.append(mediaModel)
                        }
                    }
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            self.galleryMediaModels.append(contentsOf: addedMediaModels)
            self.selectLatestMedia()
        }

        return true
    }
}

struct MediaView: View {
    @ObservedObject var mediaModel: MediaModel

    var body: some View {
        Group {
            if mediaModel.type == .image, let image = mediaModel.image {
                Image(nsImage: image)
                    .resizable()
            } else if mediaModel.type == .video, let thumbnail = mediaModel.videoThumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .onAppear {
                        mediaModel.generateThumbnail()
                    }
            } else {
                Color.gray
            }
        }
    }
}

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
