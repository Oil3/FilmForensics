//
//  ObjectsCoordinatesProcessors.swift
//  MLmedia
//
//  Created by Almahdi Morris on 28/6/24.
//

import SwiftUI
import Vision

struct BoundingBoxModifier: ViewModifier {
  var observations: [VNDetectedObjectObservation]
  var color: NSColor
  var scale: CGFloat
  
  func body(content: Content) -> some View {
    content.overlay(
      ZStack {
        ForEach(observations, id: \.self) { observation in
          drawBoundingBox(for: observation, color: color, scale: scale)
        }
      }
    )
  }
  
  private func drawBoundingBox(for observation: VNDetectedObjectObservation, color: NSColor, scale: CGFloat) -> some View {
    GeometryReader { geometry in
      let boundingBox = observation.boundingBox
      let width = geometry.size.width
      let height = geometry.size.height
      let normalizedRect = CGRect(
        x: boundingBox.minX * width,
        y: (1 - boundingBox.maxY) * height,
        width: boundingBox.width * width * scale,
        height: boundingBox.height * height * scale
      )
      
      Rectangle()
        .stroke(Color(color), lineWidth: 2)
        .frame(width: normalizedRect.width, height: normalizedRect.height)
        .position(x: normalizedRect.midX, y: normalizedRect.midY)
    }
  }
}

struct HandJointModifier: ViewModifier {
  var hands: [VNHumanHandPoseObservation]
  var color: NSColor
  
  func body(content: Content) -> some View {
    content.overlay(
      ZStack {
        ForEach(hands, id: \.self) { hand in
          drawHandJoints(for: hand, color: color)
        }
      }
    )
  }
  
  private func drawHandJoints(for observation: VNHumanHandPoseObservation, color: NSColor) -> some View {
    GeometryReader { geometry in
      let points = observation.availableJointNames.compactMap { try? observation.recognizedPoint($0) }
      let normalizedPoints = points.map { CGPoint(x: $0.location.x * geometry.size.width, y: (1 - $0.location.y) * geometry.size.height) }
      
      ForEach(normalizedPoints.indices, id: \.self) { index in
        Circle()
          .fill(Color(color))
          .frame(width: 5, height: 5)
          .position(normalizedPoints[index])
      }
    }
  }
}

