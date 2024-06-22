//
//  Logs.swift
//  MLmedia
//
//  Created by Almahdi Morris on 21/6/24.
//
import SwiftUI

struct DetectionLog: Codable {
    let videoURL: String
    let creationDate: String
    var frames: [FrameLog]
}

struct FrameLog: Codable {
    let frameNumber: Int
    let detections: [Detection]
}

struct Detection: Codable {
    let boundingBox: CGRect
    let identifier: String?
    let confidence: Float
}
