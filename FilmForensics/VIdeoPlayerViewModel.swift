//
//  VIdeoPlayerViewModel.swift
//  FilmForensics
//
//  Created by Almahdi Morris on 05/20/24.
//

import SwiftUI
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

class VideoPlayerViewModel: ObservableObject {
    @Published var brightness: Float = 0 {
        didSet {
            applyFilter()
        }
    }
    @Published var contrast: Float = 1 {
        didSet {
            applyFilter()
        }
    }
    @Published var saturation: Float = 1 {
        didSet {
            applyFilter()
        }
    }
    @Published var red: Float = 1 {
        didSet {
            applyFilter()
        }
    }
    @Published var green: Float = 1 {
        didSet {
            applyFilter()
        }
    }
    @Published var blue: Float = 1 {
        didSet {
            applyFilter()
        }
    }
    
    let player = AVPlayer()
    private let context = CIContext()
    private let videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    
    func setupPlayer() {
        guard let url = Bundle.main.url(forResource: "sample", withExtension: "mp4") else { return }
        let playerItem = AVPlayerItem(url: url)
        playerItem.add(videoOutput)
        player.replaceCurrentItem(with: playerItem)
        player.play()
    }
    
    private func applyFilter() {
        guard let currentItem = player.currentItem else { return }
        
        videoOutput.requestNotificationOfMediaDataChange(withAdvanceInterval: 0.03)
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemTimeJumped, object: player.currentItem, queue: .main) { _ in
            self.updateVideoFrame()
        }
    }
    
    private func updateVideoFrame() {
        guard let currentItem = player.currentItem else { return }
        let currentTime = currentItem.currentTime()
        
        guard let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) else { return }
        
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        ciImage = ciImage.applyingFilter("CIColorControls", parameters: [
            kCIInputBrightnessKey: brightness,
            kCIInputContrastKey: contrast,
            kCIInputSaturationKey: saturation
        ])
        
        ciImage = ciImage.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: CGFloat(red), y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: CGFloat(green), z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: CGFloat(blue), w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])
        
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            DispatchQueue.main.async {
                // You can update the UI with the filtered image if necessary
            }
        }
    }
}
