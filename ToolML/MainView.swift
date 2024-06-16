import SwiftUI
import CoreML
import Vision
import AVKit

struct MainView: View {
    @State private var selectedMediaModel: MediaModel? {
        didSet {
            handleSelectionChange()
        }
    }
    @State private var detectedObjects: [VNRecognizedObjectObservation] = []
    @State private var galleryMediaModels: [MediaModel] = []
    @State private var imageSize: CGSize = .zero
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationSplitView {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack {
                        ForEach(galleryMediaModels.indices, id: \.self) { index in
                            let mediaModel = galleryMediaModels[index]
                            MediaView(mediaModel: mediaModel)
                                .frame(width: 100, height: 100)
                                .padding(2)
                                .background(selectedMediaModel?.id == mediaModel.id ? Color.blue.opacity(0.3) : Color.clear)
                                .onTapGesture {
                                    self.selectedMediaModel = mediaModel
                                }
                                .id(index)
                        }
                    }
                    .padding()
                }
                .onChange(of: selectedMediaModel) { _ in
                    scrollToSelectedMedia(proxy: proxy)
                }
            }
            .frame(width: 120)
            .onDrop(of: ["public.file-url"], isTargeted: nil, perform: handleDrop)
            .onMoveCommand(perform: handleMoveCommand)
            .focused($isFocused)
            .scrollIndicators(.never)
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
        .overlay(
            VStack {
                Button(action: moveSelectionUp) {
                    Text("")
                }
                .keyboardShortcut(.upArrow, modifiers: [])
                .opacity(0)

                Button(action: moveSelectionDown) {
                    Text("")
                }
                .keyboardShortcut(.downArrow, modifiers: [])
                .opacity(0)
            }
        )
    }

    func handleSelectionChange() {
        guard let mediaModel = selectedMediaModel else { return }
        detectedObjects.removeAll()

        if mediaModel.type == .image {
            if mediaModel.image == nil {
                mediaModel.loadImage()
                
                    if let image = mediaModel.image {
                      runModel(on: image)
                    }
                
            } else {
                if let image = mediaModel.image {
                    runModel(on: image)
                }
            }
        } else if mediaModel.type == .video {
            mediaModel.startVideo()
            mediaModel.extractFrame()
        }
    }
    
    func handleMoveCommand(direction: MoveCommandDirection) {
        switch direction {
        case .left, .up:
            moveSelection(by: -1)
        case .right, .down:
            moveSelection(by: 1)
        default:
            break
        }
    }

    func moveSelection(by offset: Int) {
        if let currentIndex = galleryMediaModels.firstIndex(where: { $0.id == selectedMediaModel?.id }) {
            let newIndex = (currentIndex + offset + galleryMediaModels.count) % galleryMediaModels.count
            selectedMediaModel = galleryMediaModels[newIndex]
        }
    }

    func moveSelectionUp() {
        moveSelection(by: -1)
    }

    func moveSelectionDown() {
        moveSelection(by: 1)
    }

    func scrollToSelectedMedia(proxy: ScrollViewProxy) {
        if let selectedIndex = galleryMediaModels.firstIndex(where: { $0.id == selectedMediaModel?.id }) {
            withAnimation {
                proxy.scrollTo(selectedIndex, anchor: nil)
            }
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
        panel.allowedContentTypes = [.image, .movie]
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
        let model = try! VNCoreMLModel(for: ccashier3().model)

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
            if mediaModel.type == .image, let thumbnail = mediaModel.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .onAppear {
                        mediaModel.generateImageThumbnail()
                    }
            } else if mediaModel.type == .video, let thumbnail = mediaModel.videoThumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .onAppear {
                        mediaModel.generateVideoThumbnail()
                    }
            } else {
                Color.gray
            }
        }
    }
}
