//
//  LogView.swift
//  Machine Security System
//
//  Created by Almahdi Morris on 31/5/24.
//

import SwiftUI

struct LogView: View {
    @State private var logs: String = ""
    
    var body: some View {
        SyntaxHighlightingTextView(text: $logs)
            .navigationTitle("Logs")
            .onAppear(perform: loadLogs)
    }
    
    private func loadLogs() {
        // Replace with actual log loading logic
        logs = """
        12May1425 Object detected: person at (x: 0.1234, y: 0.5678, width: 0.2345, height: 0.3456)
        12May1426 Face detected at (x: 0.1234, y: 0.5678, width: 0.2345, height: 0.3456)
        """
    }
}
