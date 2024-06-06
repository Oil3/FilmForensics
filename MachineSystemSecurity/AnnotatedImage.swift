  //
  //  AnnotatedImage.swift
  //  Machine Security System
  //
  // Copyright Almahdi Morris - 1/6/24.
  //
import SwiftUI
import Vision
import Foundation

class AnnotatedImage: ObservableObject {
  @Published var annotations: [Annotation] = []
  let url: URL
  
  init(url: URL) {
    self.url = url
  }
  
  func addAnnotation(withCoordinates coords: CGRect) {
    let annotation = Annotation(id: UUID(), coordinates: coords)
    annotations.append(annotation)
  }
  
  func beginMoving(annotation: Annotation) {
      // Implement logic for beginning to move an annotation
  }
  
  func move(annotation: Annotation, to location: CGPoint) {
      // Implement logic for moving an annotation
    if let index = annotations.firstIndex(where: { $0.id == annotation.id }) {
      annotations[index].coordinates.origin = location
    }
  }
  
  func finalizeMoving(annotation: Annotation) {
      // Implement logic for finalizing the move
  }
  
  func toggle(annotation: Annotation) {
      // Implement logic for toggling an annotation
  }
}

struct Annotation: Identifiable, Codable {
  let id: UUID
  var coordinates: CGRect
}

extension CGRect: Codable {
  public init(from decoder: Decoder) throws {
    var container = try decoder.unkeyedContainer()
    let x = try container.decode(CGFloat.self)
    let y = try container.decode(CGFloat.self)
    let width = try container.decode(CGFloat.self)
    let height = try container.decode(CGFloat.self)
    self.init(x: x, y: y, width: width, height: height)
    }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.unkeyedContainer()
    try container.encode(origin.x)
    try container.encode(origin.y)
    try container.encode(size.width)
    try container.encode(size.height)
  }
  
  func exportAnnotationsToJSON(image: AnnotatedImage, to url: URL) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    do {
      let data = try encoder.encode(image.annotations)
      try data.write(to: url)
    } catch {
      print("Error exporting annotations to JSON: \(error)")
    }
  }
}
