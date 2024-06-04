//
//  SyntaxHighlightingTextView.swift
//  Machine Security System
//
//  Created by Almahdi Morris on 31/5/24.
//

import SwiftUI
import UIKit

struct SyntaxHighlightingTextView: UIViewRepresentable {
    @Binding var text: String
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = true
        textView.backgroundColor = .black
        textView.textColor = .white
        textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        let attributedString = NSAttributedString(string: text, attributes: [.foregroundColor: UIColor.white])
        uiView.attributedText = applySyntaxHighlighting(to: attributedString)
    }
    
    private func applySyntaxHighlighting(to attributedString: NSAttributedString) -> NSAttributedString {
        let highlightedString = NSMutableAttributedString(attributedString: attributedString)
        
        let keywords = ["Object detected:", "Face detected:", "at"]
        let keywordAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.systemYellow]
        
        for keyword in keywords {
            let range = (highlightedString.string as NSString).range(of: keyword)
            highlightedString.addAttributes(keywordAttributes, range: range)
        }
        
        return highlightedString
    }
}
