//
//  HistogramView.swift
//  FilmForensics
//
// Copyright Almahdi Morris - 05/22/24.
//
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct HistogramView: View {
    var image: CIImage?

    var body: some View {
        if let image = image {
            GeometryReader { geometry in
                let histogram = createHistogram(from: image, size: CGSize(width: geometry.size.width, height: 150))
                Image(nsImage: histogram)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        } else {
            Text("No image available")
                .foregroundColor(.white)
        }
    }

    private func createHistogram(from image: CIImage, size: CGSize) -> NSImage {
        let filter = CIFilter.histogramDisplay()
        filter.inputImage = image
        filter.height = Float(size.height)
        
        let context = CIContext()
        let outputImage = filter.outputImage!
        let extent = outputImage.extent
        let cgImage = context.createCGImage(outputImage, from: extent)!
        
        let nsImage = NSImage(cgImage: cgImage, size: size)
        return nsImage
    }
}
