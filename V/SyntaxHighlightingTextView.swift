//
//  SyntaxHighlightingTextView.swift
//  Machine Security System
//
// Copyright Almahdi Morris - 31/5/24.
//
import SwiftUI
import AppKit

struct SyntaxHighlightingTextView: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.backgroundColor = NSColor.black
        textView.textColor = NSColor.white
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.autoresizingMask = [.width, .height]  // Ensures it resizes with the container
        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        let attributedString = NSAttributedString(string: text, attributes: [.foregroundColor: NSColor.white])
        nsView.textStorage?.setAttributedString(applySyntaxHighlighting(to: attributedString))
    }

    private func applySyntaxHighlighting(to attributedString: NSAttributedString) -> NSAttributedString {
        let highlightedString = NSMutableAttributedString(attributedString: attributedString)
        
        let keywords = ["Object detected:", "Face detected:", "at"]
        let keywordAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.systemYellow]
        
        for keyword in keywords {
            let range = (highlightedString.string as NSString).range(of: keyword)
            highlightedString.addAttributes(keywordAttributes, range: range)
        }
        
        return highlightedString
    }
}
