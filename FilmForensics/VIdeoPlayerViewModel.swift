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
import UniformTypeIdentifiers
import AppKit

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
    
    @Published var ciImage: CIImage? = nil
    let player = AVPlayer()
    private let context = CIContext()
    private let videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    private var timer: Timer?
    
    func setupPlayer() {
        // Initial setup can be left empty if we plan to open files dynamically
    }
    
    func openFilePicker() {
        let dialog = NSOpenPanel()
        dialog.title = "Choose a video or image file"
        dialog.allowedContentTypes = [UTType.movie, UTType.image]
        dialog.allowsMultipleSelection = false
        dialog.canChooseDirectories = false
        dialog.canCreateDirectories = false
        
        if dialog.runModal() == .OK, let result = dialog.url {
            loadFile(url: result)
        }
    }
    
    private func loadFile(url: URL) {
        ciImage = nil
        if url.pathExtension == "mp4" || url.pathExtension == "mov" {
            let playerItem = AVPlayerItem(url: url)
            playerItem.add(videoOutput)
            player.replaceCurrentItem(with: playerItem)
            player.play()
            setupTimer()
        } else if url.pathExtension == "jpg" || url.pathExtension == "png" {
            if let image = CIImage(contentsOf: url) {
                ciImage = image
                applyFilter()
            }
        }
    }
    
    private func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 1.0 / 30.0, target: self, selector: #selector(updateVideoFrame), userInfo: nil, repeats: true)
    }
    
    @objc private func updateVideoFrame() {
        guard let currentItem = player.currentItem else { return }
        let currentTime = currentItem.currentTime()
        
        guard let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) else { return }
        
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        ciImage = applyFilters(to: ciImage)
        
        DispatchQueue.main.async {
            self.ciImage = ciImage
        }
    }
    
    private func applyFilters(to image: CIImage) -> CIImage {
        var filteredImage = image
        
        filteredImage = filteredImage.applyingFilter("CIColorControls", parameters: [
            kCIInputBrightnessKey: brightness,
            kCIInputContrastKey: contrast,
            kCIInputSaturationKey: saturation
        ])
        
        filteredImage = filteredImage.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: CGFloat(red), y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: CGFloat(green), z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: CGFloat(blue), w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])
        
        return filteredImage
    }
    
    private func applyFilter() {
        if let ciImage = ciImage {
            self.ciImage = applyFilters(to: ciImage)
        } else {
            updateVideoFrame()
        }
    }
}
