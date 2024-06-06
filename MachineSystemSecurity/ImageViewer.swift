//
//  ImageViewer.swift
//  Machine Security System
//
// Copyright Almahdi Morris - 1/6/24.
//
import SwiftUI

struct ImageViewer: View {
    @StateObject var image: AnnotatedImage
    let scaleFactor: CGFloat
    let showAnnotationLabels: Bool
    let draftCoords: CGRect?

    @State private var creatingAnnotation = false
    @State private var movingAnnotation = false
    @State private var newAnnotationCenter = CGPoint.zero
    @State private var newAnnotationCorner = CGPoint.zero
    @State private var movingAnnotationSize = CGSize.zero
    @State private var lastUpdateTime = Date()
    @State private var movingAnnotationCenter = CGPoint.zero

    var newAnnotationSize: CGSize {
        CGSize(
            width: abs(newAnnotationCenter.x - newAnnotationCorner.x) * 2,
            height: abs(newAnnotationCenter.y - newAnnotationCorner.y) * 2
        )
    }

    var newAnnotation: CGRect {
        CGRect(origin: newAnnotationCenter, size: newAnnotationSize)
    }

    var body: some View {
        ZStack {
            if let uiImage = UIImage(contentsOfFile: image.url.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                self.handleDragChanged(value: value)
                            }
                            .onEnded { _ in
                                self.handleDragEnded()
                            }
                    )
                    .border(Color.accentColor, width: 1)
                
                self.annotationsBody
            } else {
                Text("Image could not be loaded")
            }
        }
    }

    private func handleDragChanged(value: DragGesture.Value) {
        let now = Date()
        if now.timeIntervalSince(self.lastUpdateTime) > 0.016 { // 60 FPS throttle
            self.lastUpdateTime = now
            if !self.creatingAnnotation {
                self.creatingAnnotation = true
                self.newAnnotationCenter = value.startLocation
            }
            self.newAnnotationCorner = value.location
        }
    }

    private func handleDragEnded() {
        if self.creatingAnnotation {
            self.image.addAnnotation(withCoordinates: self.newAnnotation.scaledBy(1 / self.scaleFactor))
            self.creatingAnnotation = false
        }
    }

    private func moveAnnotation(_ annotation: Annotation, to location: CGPoint) {
        if !self.movingAnnotation {
            self.movingAnnotation = true
            self.image.beginMoving(annotation: annotation)
            self.movingAnnotationSize = annotation.coordinates.size.scaledBy(self.scaleFactor)
        }
        self.movingAnnotationCenter = location
        self.image.move(annotation: annotation, to: location.scaledBy(1 / self.scaleFactor))
    }

    private var annotationsBody: some View {
        ZStack {
            if creatingAnnotation {
                Rectangle()
                    .frame(width: newAnnotationSize.width, height: newAnnotationSize.height)
                    .position(newAnnotationCenter)
                    .foregroundColor(.blue)
                    .opacity(0.5)
            }
            if movingAnnotation {
                Rectangle()
                    .frame(width: movingAnnotationSize.width, height: movingAnnotationSize.height)
                    .position(movingAnnotationCenter)
                    .foregroundColor(.green)
                    .opacity(0.5)
            }
            if let draftCoords = draftCoords {
                Rectangle()
                    .frame(width: draftCoords.size.scaledBy(self.scaleFactor).width, height: draftCoords.size.scaledBy(self.scaleFactor).height)
                    .position(draftCoords.origin.scaledBy(self.scaleFactor))
                    .foregroundColor(.green)
                    .opacity(0.5)
            }
            ForEach(image.annotations) { annotation in
                AnnotationView(annotation: annotation, scaleFactor: self.scaleFactor, showAnnotationLabels: self.showAnnotationLabels)
                    .onTapGesture {
                        self.image.toggle(annotation: annotation)
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let now = Date()
                                if now.timeIntervalSince(self.lastUpdateTime) > 0.016 { // 60 FPS throttle
                                    self.lastUpdateTime = now
                                    DispatchQueue.main.async {
                                        self.moveAnnotation(annotation, to: value.location)
                                    }
                                }
                            }
                            .onEnded { _ in
                                self.movingAnnotation = false
                                self.image.finalizeMoving(annotation: annotation)
                            }
                    )
            }
        }
    }
}

struct AnnotationView: View {
    let annotation: Annotation
    let scaleFactor: CGFloat
    let showAnnotationLabels: Bool

    var body: some View {
        Rectangle()
            .frame(width: annotation.coordinates.width * scaleFactor, height: annotation.coordinates.height * scaleFactor)
            .position(x: annotation.coordinates.origin.x * scaleFactor, y: annotation.coordinates.origin.y * scaleFactor)
            .foregroundColor(.clear)
            .border(Color.red, width: 2)
            .overlay(
                showAnnotationLabels ? Text("Annotation").foregroundColor(.white) : nil,
                alignment: .topLeading
            )
    }
}

extension CGRect {
    func scaledBy(_ scale: CGFloat) -> CGRect {
        CGRect(
            x: origin.x * scale,
            y: origin.y * scale,
            width: size.width * scale,
            height: size.height * scale
        )
    }
}

extension CGSize {
    func scaledBy(_ scale: CGFloat) -> CGSize {
        CGSize(width: width * scale, height: height * scale)
    }
}

extension CGPoint {
    func scaledBy(_ scale: CGFloat) -> CGPoint {
        CGPoint(x: x * scale, y: y * scale)
    }
}

