//
//  Logs.swift
//  MLmedia
//
//  Created by Almahdi Morris on 21/6/24.
//
import SwiftUI

struct DetectionLog: Codable {
  var videoURL: String
  var creationDate: String
  var frames: [FrameLog]
  
  enum CodingKeys: String, CodingKey {
    case videoURL
    case creationDate
    case frames
    case metadata
  }
  
  struct Metadata: Codable {
    var videoFilename: String
    var modelFilename: String
    var totalFrames: Int
    var totalFramesWithDetections: Int
    var totalFramesWithoutDetections: Int
    var totalObjectsDetected: Int
    var totalObjectsBelowThreshold: Int
    var averageConfidence: Float
    var averageDetectionSpeed: Float
    var frameNumbersNotAnalysed: [Int]
  }
  
  var metadata: Metadata?
}


struct FrameLog: Codable {
  var frameNumber: Int
  var detections: [Detection]?
}

struct Detection: Codable {
  var boundingBox: CGRect
  var identifier: String
  var confidence: Float
}
extension CGFloat {
  func rounded(toPlaces places: Int) -> CGFloat {
    let divisor = pow(10.0, CGFloat(places))
    return (self * divisor).rounded() / divisor
  }
}

