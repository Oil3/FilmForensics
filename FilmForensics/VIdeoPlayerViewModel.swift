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
import Vision

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
    @Published var colorInvert: Bool = false {
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
    @Published var sharpenLuminance: Float = 0 {
        didSet {
            applyFilter()
        }
    }
    @Published var unsharpMask: Float = 0 {
        didSet {
            applyFilter()
        }
    }
    @Published var additionCompositing: Float = 0 {
        didSet {
            applyFilter()
        }
    }
    @Published var multiplyCompositing: Float = 0 {
        didSet {
            applyFilter()
        }
    }
    @Published var convolution3X3: Float = 0 {
        didSet {
            applyFilter()
        }
    }
    @Published var convolution5X5: Float = 0 {
        didSet {
            applyFilter()
        }
    }
    
    @Published var ciImage: CIImage? = nil
    @Published var isPlaying: Bool = false
    @Published var presets: [FilterPreset]? = []
    @Published var selectedPreset: FilterPreset?
    @Published var showBoundingBoxes: Bool = false
    @Published var boundingBoxes: [CGRect] = []
    @Published var image: NSImage? {
        didSet {
            if let image = image {
                self.ciImage = CIImage(data: image.tiffRepresentation!)
                applyFilter()
            }
        }
    }
    @Published var videoURL: URL? {
        didSet {
            if let url = videoURL {
                loadVideo(url: url)
            }
        }
    }
    
    let player = AVPlayer()
    private let context = CIContext()
    private let videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB])
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
            "gaussianBlur": 0,
            "motionBlur": 0,
            "zoomBlur": 0,
            "noiseReduction": 0,
            "sharpenLuminance": 0,
            "unsharpMask": 0,
            "additionCompositing": 0,
            "multiplyCompositing": 0,
            "convolution3X3": 0,
            "convolution5X5": 0
        ]
    }
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(applyFilter), name: .sliderValueChanged, object: nil)
    }
    
    func setupPlayer() {
        // Initial setup can be left empty if we plan to open files dynamically
    }
    
    func loadImage(url: URL) {
        if let image = CIImage(contentsOf: url) {
            ciImage = image
            applyFilter()
        }
    }
    
    func loadVideo(url: URL) {
        player.pause()
        ciImage = nil
        let playerItem = AVPlayerItem(url: url)
        playerItem.add(videoOutput)
        player.replaceCurrentItem(with: playerItem)
        isPlaying = false
        setupTimer()
    }
    
    private func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            self.updateVideoFrame()
        }
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
        
        if brightness != 0 {
            filteredImage = filteredImage.applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: brightness,
                kCIInputContrastKey: contrast,
                kCIInputSaturationKey: saturation
            ])
        }

        if hue != 0 {
            filteredImage = filteredImage.applyingFilter("CIHueAdjust", parameters: [
                "inputAngle": hue
            ])
        }

        if gamma != 1 {
            filteredImage = filteredImage.applyingFilter("CIGammaAdjust", parameters: [
                "inputPower": gamma
            ])
        }

        if vibrance != 0 {
            filteredImage = filteredImage.applyingFilter("CIVibrance", parameters: [
                "inputAmount": vibrance
            ])
        }

        if exposure != 0 {
            filteredImage = filteredImage.applyingFilter("CIExposureAdjust", parameters: [
                kCIInputEVKey: exposure
            ])
        }

        if temperature != 6500 {
            filteredImage = filteredImage.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: CGFloat(temperature), y: 0)
            ])
        }

        if sepiaTone != 0 {
            filteredImage = filteredImage.applyingFilter("CISepiaTone", parameters: [
                kCIInputIntensityKey: sepiaTone
            ])
        }

        if colorInvert {
            filteredImage = filteredImage.applyingFilter("CIColorInvert")
        }

        if gaussianBlur != 0 {
            filteredImage = filteredImage.applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: gaussianBlur
            ])
        }

        if motionBlur != 0 {
            filteredImage = filteredImage.applyingFilter("CIMotionBlur", parameters: [
                kCIInputRadiusKey: motionBlur,
                kCIInputAngleKey: 0
            ])
        }

        if zoomBlur != 0 {
            filteredImage = filteredImage.applyingFilter("CIZoomBlur", parameters: [
                kCIInputAmountKey: zoomBlur
            ])
        }

        if noiseReduction != 0 {
            filteredImage = filteredImage.applyingFilter("CINoiseReduction", parameters: [
                "inputNoiseLevel": noiseReduction,
                "inputSharpness": 0.4
            ])
        }

        if sharpenLuminance != 0 {
            filteredImage = filteredImage.applyingFilter("CISharpenLuminance", parameters: [
                kCIInputSharpnessKey: sharpenLuminance
            ])
        }

        if unsharpMask != 0 {
            filteredImage = filteredImage.applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: unsharpMask,
                kCIInputIntensityKey: 1.0
            ])
        }

        if additionCompositing != 0 {
            filteredImage = filteredImage.applyingFilter("CIAdditionCompositing", parameters: [
                kCIInputBackgroundImageKey: filteredImage
            ])
        }

        if multiplyCompositing != 0 {
            filteredImage = filteredImage.applyingFilter("CIMultiplyCompositing", parameters: [
                kCIInputBackgroundImageKey: filteredImage
            ])
        }

        if convolution3X3 != 0 {
            filteredImage = filteredImage.applyingFilter("CIConvolution3X3", parameters: [
                "inputWeights": CIVector(values: [0, 1, 0, 1, -4, 1, 0, 1, 0], count: 9),
                kCIInputBiasKey: convolution3X3
            ])
        }

        if convolution5X5 != 0 {
            filteredImage = filteredImage.applyingFilter("CIConvolution5X5", parameters: [
                "inputWeights": CIVector(values: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], count: 25),
                kCIInputBiasKey: convolution5X5
            ])
        }

        return filteredImage
    }
    
    @objc private func applyFilter() {
        if let ciImage = ciImage {
            self.ciImage = applyFilters(to: ciImage)
        } else {
            updateVideoFrame()
        }
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
        colorInvert = false
        gaussianBlur = defaultSettings["gaussianBlur"]!
        motionBlur = defaultSettings["motionBlur"]!
        zoomBlur = defaultSettings["zoomBlur"]!
        noiseReduction = defaultSettings["noiseReduction"]!
        sharpenLuminance = defaultSettings["sharpenLuminance"]!
        unsharpMask = defaultSettings["unsharpMask"]!
        additionCompositing = defaultSettings["additionCompositing"]!
        multiplyCompositing = defaultSettings["multiplyCompositing"]!
        convolution3X3 = defaultSettings["convolution3X3"]!
        convolution5X5 = defaultSettings["convolution5X5"]!
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
            colorInvert: colorInvert ? 1 : 0,
            gaussianBlur: gaussianBlur,
            motionBlur: motionBlur,
            zoomBlur: zoomBlur,
            noiseReduction: noiseReduction,
            sharpenLuminance: sharpenLuminance,
            unsharpMask: unsharpMask,
            additionCompositing: additionCompositing,
            multiplyCompositing: multiplyCompositing,
            convolution3X3: convolution3X3,
            convolution5X5: convolution5X5
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
        colorInvert = preset.colorInvert == 1
        gaussianBlur = preset.gaussianBlur
        motionBlur = preset.motionBlur
        zoomBlur = preset.zoomBlur
        noiseReduction = preset.noiseReduction
        sharpenLuminance = preset.sharpenLuminance
        unsharpMask = preset.unsharpMask
        additionCompositing = preset.additionCompositing
        multiplyCompositing = preset.multiplyCompositing
        convolution3X3 = preset.convolution3X3
        convolution5X5 = preset.convolution5X5
    }
    
    private func savePresets() {
        // Code to save presets to disk
    }
    
    private func loadPresets() {
        // Code to load presets from disk
    }

    func detectObjects(in image: CIImage) {
        guard let model = try? VNCoreMLModel(for: MLcopycontrol25k().model) else { return }

        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            if let results = request.results as? [VNRecognizedObjectObservation] {
                self?.boundingBoxes = results.map { $0.boundingBox }
            }
        }
        
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try? handler.perform([request])
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
    let gaussianBlur: Float
    let motionBlur: Float
    let zoomBlur: Float
    let noiseReduction: Float
    let sharpenLuminance: Float
    let unsharpMask: Float
    let additionCompositing: Float
    let multiplyCompositing: Float
    let convolution3X3: Float
    let convolution5X5: Float
    
    var name: String {
        return "Preset \(id.uuidString.prefix(4))"
    }
}
