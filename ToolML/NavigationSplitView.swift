//
//  NavigationSplitView.swift
//  ToolML
//
//  Created by Almahdi Morris on 15/6/24.
//
import SwiftUI
import CoreML
import Vision

struct NavigationSplittView: View {
    @State private var selectedImage: NSImage? = nil
    @State private var detectedObjects: [VNRecognizedObjectObservation] = []
    @State private var galleryImages: [NSImage] = []
    @State private var highlightedImage: NSImage? = nil
    @State private var imageSize: CGSize = .zero

var body: some View {
        NavigationView {
        VStack {
                    ScrollView {
                        ForEach(galleryImages, id: \.self) { image in
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .padding(2)
                                .background(highlightedImage == image ? Color.blue.opacity(0.3) : Color.clear)
                                .onTapGesture {
                                    self.selectedImage = image
                                    self.highlightedImage = image
                                    runModel(on: image)
                                }
                        }
                    }
                    Spacer()
                    Button(action: selectImage) {
                        Text("Select Image")
                    }
                    Button(action: clearImages) {
                        Text("Clear")
                    }
                
                .frame(width: 120)
                .background(
                    Rectangle()
                        .stroke(Color.gray, lineWidth: 1)
                )
                .onDrop(of: ["public.file-url"], isTargeted: nil, perform: handleDrop)


        }
                 VStack {
                    if let image = selectedImage {
                        GeometryReader { geometry in
                            ZStack {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .background(GeometryReader { geo -> Color in
                                        DispatchQueue.main.async {
                                            self.imageSize = geo.size
                                        }
                                      Color.clear
                                    })
                                ForEach(detectedObjects, id: \.self) { object in
                                    drawBoundingBox(for: object, in: geometry.size)
                                }
                            }
                        }
                    } else {
                        Text("No Image Selected")
                    }
                }
            }
        
        .padding()
        .onAppear {
            addCommandShortcuts()
        }
    }

    func addCommandShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "o" {
                selectImage()
                return nil
            }
            return event
        }
    }

    func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["png", "jpg", "jpeg"]
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let image = NSImage(contentsOf: url) {
                    galleryImages.append(image)
                }
            }
        }
    }

    func clearImages() {
        selectedImage = nil
        detectedObjects.removeAll()
        galleryImages.removeAll()
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
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        if let image = NSImage(contentsOf: url) {
                            DispatchQueue.main.async {
                                self.galleryImages.append(image)
                            }
                        }
                    }
                }
                return true
            }
        }
        return false
    }
}
}
