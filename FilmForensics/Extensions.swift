//
//  Extensions.swift
//  FilmForensics
//
// Copyright Almahdi Morris - 05/22/24.
//

import CoreImage
import AppKit

extension CIImage {
    func toNSImage() -> NSImage {
        let rep = NSCIImageRep(ciImage: self)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}

extension Notification.Name {
    static let sliderValueChanged = Notification.Name("sliderValueChanged")
}
