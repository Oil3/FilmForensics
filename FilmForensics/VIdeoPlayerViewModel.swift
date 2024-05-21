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
    @Published var hue: Float = 0 {
        didSet {
            applyFilter()
        }
    }
    @Published var gamma: Float = 1 {
        didSet {
            applyFilter()
        }
    }
    @Published var vibrance: Float = 0 {
        didSet {
            applyFilter()
        }
    }
    @Published var exposure: Float = 0 {
        didSet {
            applyFilter()
        }
    }
    @Published var temperature: Float = 6500 {
        didSet {
            applyFilter()
        }
    }
    @Published var sepiaTone: Float = 0 {
        didSet {
            applyFilter()
        }
    }
    @Published var colorInvert: Float = 0 {
        didSet {
            applyFilter()
        }
    }
    @Published var areaAverage: Float = 0 {
        didSet {
            applyFilter()
        }
    }
    @Published var histogram: Float = 0 {
        didSet {
            applyFilter()
        }
    }
    @Published var gaussianBlur: Float = 0 {
        didSet {
            applyFilter()
        }
    }
    @Published var motionBlur: Float = 0 {
        didSet {
            applyFilter()
        }
    }
    @Published var zoomBlur: Float = 0 {
        didSet {
            applyFilter()
        }
    }
    @Published var noiseReduction: Float = 0 {
        didSet {
            applyFilter()
        }
    }
    
    @Published var ciImage: CIImage? = nil
    @Published var isPlaying: Bool = false
    @Published var presets: [FilterPreset]? = []
    @Published var selectedPreset: FilterPreset?
    
    let player = AVPlayer()
    private let context = CIContext()
    private let videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    private var timer: Timer?
    
    private var defaultSettings: [String: Float] {
        return [
            "brightness": 0,
            "contrast": 1,
            "saturation": 1,
            "hue": 0,
            "gamma": 1,
            "vibrance": 0,
            "exposure": 0,
            "temperature": 6500,
            "sepiaTone": 0,
            "colorInvert": 0,
            "areaAverage": 0,
            "histogram": 0,
            "gaussianBlur": 0,
            "motionBlur": 0,
            "zoomBlur": 0,
            "noiseReduction": 0
        ]
    }
    
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
            isPlaying = true
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
        
        filteredImage = filteredImage.applyingFilter("CIHueAdjust", parameters: [
            "inputAngle": hue
        ])
        
        filteredImage = filteredImage.applyingFilter("CIGammaAdjust", parameters: [
            "inputPower": gamma
        ])
        
        filteredImage = filteredImage.applyingFilter("CIVibrance", parameters: [
            "inputAmount": vibrance
        ])
        
        filteredImage = filteredImage.applyingFilter("CIExposureAdjust", parameters: [
            kCIInputEVKey: exposure
        ])
        
        filteredImage = filteredImage.applyingFilter("CITemperatureAndTint", parameters: [
            "inputNeutral": CIVector(x: CGFloat(temperature), y: 0)
        ])
        
        filteredImage = filteredImage.applyingFilter("CISepiaTone", parameters: [
            kCIInputIntensityKey: sepiaTone
        ])
        
        if colorInvert != 0 {
            filteredImage = filteredImage.applyingFilter("CIColorInvert")
        }
        
        filteredImage = filteredImage.applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: gaussianBlur
        ])
        
        filteredImage = filteredImage.applyingFilter("CIMotionBlur", parameters: [
            kCIInputRadiusKey: motionBlur,
            kCIInputAngleKey: 0
        ])
        
        filteredImage = filteredImage.applyingFilter("CIZoomBlur", parameters: [
            kCIInputAmountKey: zoomBlur
        ])
        
        filteredImage = filteredImage.applyingFilter("CINoiseReduction", parameters: [
            "inputNoiseLevel": noiseReduction,
            "inputSharpness": 0.4
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
    
    func playPause() {
        if player.rate == 0 {
            player.play()
            isPlaying = true
        } else {
            player.pause()
            isPlaying = false
        }
    }
    
    func loopVideo() {
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            self.player.seek(to: CMTime.zero)
            self.player.play()
        }
    }
    
    func stepFrame(by count: Int) {
        guard let currentItem = player.currentItem else { return }
        let currentTime = currentItem.currentTime()
        let frameDuration = CMTimeMake(value: 1, timescale: 30)
        let newTime = count > 0 ? CMTimeAdd(currentTime, frameDuration) : CMTimeSubtract(currentTime, frameDuration)
        player.seek(to: newTime)
    }
    
    func resetFilters() {
        brightness = defaultSettings["brightness"]!
        contrast = defaultSettings["contrast"]!
        saturation = defaultSettings["saturation"]!
        hue = defaultSettings["hue"]!
        gamma = defaultSettings["gamma"]!
        vibrance = defaultSettings["vibrance"]!
        exposure = defaultSettings["exposure"]!
        temperature = defaultSettings["temperature"]!
        sepiaTone = defaultSettings["sepiaTone"]!
        colorInvert = defaultSettings["colorInvert"]!
        areaAverage = defaultSettings["areaAverage"]!
        histogram = defaultSettings["histogram"]!
        gaussianBlur = defaultSettings["gaussianBlur"]!
        motionBlur = defaultSettings["motionBlur"]!
        zoomBlur = defaultSettings["zoomBlur"]!
        noiseReduction = defaultSettings["noiseReduction"]!
    }
    
    func savePreset() {
        let preset = FilterPreset(
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            hue: hue,
            gamma: gamma,
            vibrance: vibrance,
            exposure: exposure,
            temperature: temperature,
            sepiaTone: sepiaTone,
            colorInvert: colorInvert,
            areaAverage: areaAverage,
            histogram: histogram,
            gaussianBlur: gaussianBlur,
            motionBlur: motionBlur,
            zoomBlur: zoomBlur,
            noiseReduction: noiseReduction
        )
        
        presets?.append(preset)
        savePresets()
    }
    
    func loadPreset(preset: FilterPreset) {
        brightness = preset.brightness
        contrast = preset.contrast
        saturation = preset.saturation
        hue = preset.hue
        gamma = preset.gamma
        vibrance = preset.vibrance
        exposure = preset.exposure
        temperature = preset.temperature
        sepiaTone = preset.sepiaTone
        colorInvert = preset.colorInvert
        areaAverage = preset.areaAverage
        histogram = preset.histogram
        gaussianBlur = preset.gaussianBlur
        motionBlur = preset.motionBlur
        zoomBlur = preset.zoomBlur
        noiseReduction = preset.noiseReduction
    }
    
    private func savePresets() {
        // Code to save presets to disk
    }
    
    private func loadPresets() {
        // Code to load presets from disk
    }
}

struct FilterPreset: Identifiable, Hashable, Equatable {
    let id = UUID()
    let brightness: Float
    let contrast: Float
    let saturation: Float
    let hue: Float
    let gamma: Float
    let vibrance: Float
    let exposure: Float
    let temperature: Float
    let sepiaTone: Float
    let colorInvert: Float
    let areaAverage: Float
    let histogram: Float
    let gaussianBlur: Float
    let motionBlur: Float
    let zoomBlur: Float
    let noiseReduction: Float
    
    var name: String {
        return "Preset \(id.uuidString.prefix(4))"
    }
}
