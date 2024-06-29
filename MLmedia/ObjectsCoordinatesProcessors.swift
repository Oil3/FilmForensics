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
class CustomDetection: Identifiable, ObservableObject {
  var id = UUID()
  var boundingBox: CGRect
  
  init(boundingBox: CGRect) {
    self.boundingBox = boundingBox
  }
}
//private func drawHandJoints(for observation: VNHumanHandPoseObservation, in parentSize: CGSize, color: NSColor) -> some View {
//  let jointNames: [VNHumanHandPoseObservation.JointName] = [
//    .wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
//    .indexMCP, .indexPIP, .indexDIP, .indexTip,
//    .middleMCP, .middlePIP, .middleDIP, .middleTip,
//    .ringMCP, .ringPIP, .ringDIP, .ringTip,
//    .littleMCP, .littlePIP, .littleDIP, .littleTip
//  ]
//  
//  let points = jointNames.compactMap { try? observation.recognizedPoint($0) }
//  let normalizedPoints = points.map { CGPoint(x: $0.location.x * parentSize.width, y: (1 - $0.location.y) * parentSize.height) }
//  
//  // Define the connections between the hand joints
//  let connections: [(VNHumanHandPoseObservation.JointName, VNHumanHandPoseObservation.JointName)] = [
//    (.wrist, .thumbCMC), (.thumbCMC, .thumbMP), (.thumbMP, .thumbIP), (.thumbIP, .thumbTip),
//    (.wrist, .indexMCP), (.indexMCP, .indexPIP), (.indexPIP, .indexDIP), (.indexDIP, .indexTip),
//    (.wrist, .middleMCP), (.middleMCP, .middlePIP), (.middlePIP, .middleDIP), (.middleDIP, .middleTip),
//    (.wrist, .ringMCP), (.ringMCP, .ringPIP), (.ringPIP, .ringDIP), (.ringDIP, .ringTip),
//    (.wrist, .littleMCP), (.littleMCP, .littlePIP), (.littlePIP, .littleDIP), (.littleDIP, .littleTip)
//  ]
//  
//  let connectionsPoints: [(CGPoint, CGPoint)] = connections.compactMap { connection in
//    guard let startPoint = try? observation.recognizedPoint(connection.0),
//          let endPoint = try? observation.recognizedPoint(connection.1),
//          startPoint.confidence > 0.1, endPoint.confidence > 0.1 else { return nil }
//    return (CGPoint(x: startPoint.location.x * parentSize.width, y: (1 - startPoint.location.y) * parentSize.height),
//            CGPoint(x: endPoint.location.x * parentSize.width, y: (1 - endPoint.location.y) * parentSize.height))
//  }
//  
//  return ZStack {
//    // Draw lines
//    ForEach(Array(connectionsPoints.enumerated()), id: \.offset) { _, connection in
//      Line(start: connection.0, end: connection.1)
//        .stroke(Color(color), lineWidth: 2)
//    }
//    
//    // Draw points
//    ForEach(Array(normalizedPoints.enumerated()), id: \.offset) { _, point in
//      Circle()
//        .fill(Color(color))
//        .frame(width: 5, height: 5)
//        .position(point)
//    }
//  }
//}
//
//
//private func drawBodyJoints(for observation: VNHumanBodyPoseObservation, in parentSize: CGSize, color: NSColor) -> some View {
//  let jointNames: [VNHumanBodyPoseObservation.JointName] = [
//    .neck, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
//    .leftWrist, .rightWrist, .root, .leftHip, .rightHip,
//    .leftKnee, .rightKnee, .leftAnkle, .rightAnkle,
//    .leftEar, .leftEye, .rightEar, .rightEye, .nose
//  ]
//  
//  let points = jointNames.compactMap { try? observation.recognizedPoint($0) }
//  let normalizedPoints = points.map { CGPoint(x: $0.location.x * parentSize.width, y: (1 - $0.location.y) * parentSize.height) }
//  
//  // Define the connections between the joints
//  let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
//    (.neck, .leftShoulder), (.neck, .rightShoulder),
//    (.leftShoulder, .leftElbow), (.rightShoulder, .rightElbow),
//    (.leftElbow, .leftWrist), (.rightElbow, .rightWrist),
//    (.neck, .root),
//    (.root, .leftHip), (.root, .rightHip),
//    (.leftHip, .leftKnee), (.rightHip, .rightKnee),
//    (.leftKnee, .leftAnkle), (.rightKnee, .rightAnkle),
//    (.neck, .nose),
//    (.nose, .leftEye), (.nose, .rightEye),
//    (.leftEye, .leftEar), (.rightEye, .rightEar)
//  ]
//  
//  let connectionsPoints: [(CGPoint, CGPoint)] = connections.compactMap { connection in
//    guard let startPoint = try? observation.recognizedPoint(connection.0),
//          let endPoint = try? observation.recognizedPoint(connection.1),
//          startPoint.confidence > 0.1, endPoint.confidence > 0.1 else { return nil }
//    return (CGPoint(x: startPoint.location.x * parentSize.width, y: (1 - startPoint.location.y) * parentSize.height),
//            CGPoint(x: endPoint.location.x * parentSize.width, y: (1 - endPoint.location.y) * parentSize.height))
//  }
//  
//  return ZStack {
//    // Draw lines
//    ForEach(Array(connectionsPoints.enumerated()), id: \.offset) { _, connection in
//      Line(start: connection.0, end: connection.1)
//        .stroke(Color(color), lineWidth: 2)
//    }
//    
//    // Draw points
//    ForEach(Array(normalizedPoints.enumerated()), id: \.offset) { _, point in
//      Circle()
//        .fill(Color(color))
//        .frame(width: 5, height: 5)
//        .position(point)
//    }
//  }
//}

struct Line: Shape {
  var start: CGPoint
  var end: CGPoint
  
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: start)
    path.addLine(to: end)
    return path
  }
}
