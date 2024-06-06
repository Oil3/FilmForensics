//
//  OverlayWindow.swift
//  FilmForensics
//
// Copyright Almahdi Morris - 05/22/24.
//

import SwiftUI
import AppKit

class OverlayWindow: NSWindow {
    init<Content: View>(view: Content) {
        let hostingController = NSHostingController(rootView: view)
        super.init(contentRect: NSRect(x: 0, y: 0, width: 300, height: 500), 
                   styleMask: [.titled, .closable, .resizable, .fullSizeContentView], 
                   backing: .buffered, defer: false)
        self.contentView = hostingController.view
        self.title = "Adjust Color"
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .floating
        self.makeKeyAndOrderFront(nil)
    }
}

func openFilterControlsOverlay(videoPlayerViewModel: VideoPlayerViewModel) {
    let overlayView = FilterControlsOverlay(videoPlayerViewModel: videoPlayerViewModel)
    let overlayWindow = OverlayWindow(view: overlayView)
    overlayWindow.center()
}
