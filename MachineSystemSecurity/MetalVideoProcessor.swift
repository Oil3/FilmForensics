//
//  MetalVideoProcessor.swift
//  Machine Security System
//
// Copyright Almahdi Morris - 31/5/24.
// 


import Metal
import MetalKit
import CoreVideo

class MetalVideoProcessor {
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var textureCache: CVMetalTextureCache!

    init() {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
    }

    func process(pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        var cvMetalTexture: CVMetalTexture?
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvMetalTexture)
        
        guard result == kCVReturnSuccess, let metalTexture = cvMetalTexture else {
            return nil
        }
        
        return CVMetalTextureGetTexture(metalTexture)
    }
}
