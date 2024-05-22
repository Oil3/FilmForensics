//
//  MLDetection.swift
//  FilmForensics
//
//  Created by Almahdi Morris on 05/22/24.
//

import SwiftUI
import CoreML
import Vision

class MLDetectionViewModel: ObservableObject {
    @Published var boundingBoxes: [CGRect] = []
    @Published var ciImage: CIImage? = nil
    
    private var yoloModel: VNCoreMLModel?
    
    init() {
        setupModel()
    }
    
    private func setupModel() {
        if let model = try? VNCoreMLModel(for: YOLOv5().model) {
            self.yoloModel = model
        }
    }
    
    func detectObjects(in image: CIImage) {
        guard let model = yoloModel else { return }
        
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            if let results = request.results as? [VNRecognizedObjectObservation] {
                self?.boundingBoxes = results.map { $0.boundingBox }
            }
        }
        
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try? handler.perform([request])
    }
}

struct MLDetectionView: View {
    @StateObject private var viewModel = MLDetectionViewModel()
    @ObservedObject var videoPlayerViewModel: VideoPlayerViewModel

    var body: some View {
        VStack {
            Text("YOLO Detection")
                .font(.headline)
                .padding()
            Toggle("Show Bounding Boxes", isOn: $videoPlayerViewModel.showBoundingBoxes)
                .padding()
            if let ciImage = videoPlayerViewModel.ciImage {
                ZStack {
                    Image(nsImage: ciImage.toNSImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    if videoPlayerViewModel.showBoundingBoxes {
                        ForEach(viewModel.boundingBoxes, id: \.self) { box in
                            Rectangle()
                                .stroke(Color.red, lineWidth: 2)
                                .frame(width: box.width * ciImage.extent.width, height: box.height * ciImage.extent.height)
                                .offset(x: box.minX * ciImage.extent.width, y: (1 - box.maxY) * ciImage.extent.height)
                        }
                    }
                }
                .onAppear {
                    viewModel.detectObjects(in: ciImage)
                }
            }
        }
        .padding()
    }
}
