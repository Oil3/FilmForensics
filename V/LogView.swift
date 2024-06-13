//
//  LogView.swift
//  V
//
// Copyright Almahdi Morris - 5/6/24.
//

import SwiftUI

struct LogView: View {
    @State private var logs: String = ""
    @State private var selectedLog: URL?
    @State private var showImportPicker = false
    @State private var showExportPicker = false

    var body: some View {
        VStack {
            HStack {
                Button("Import Log") {
                    showImportPicker = true
                }
                .padding()

                Button("Export Log") {
                    if let selectedLog = selectedLog {
                        exportLog(url: selectedLog)
                    }
                }
                .padding()
            }

            SyntaxHighlightingTextView(text: $logs)
                .navigationTitle("Logs")
                .onAppear(perform: loadLogs)
                .padding()
        }
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.text]) { result in
            switch result {
            case .success(let url):
                selectedLog = url
                loadLog(from: url)
            case .failure(let error):
                print("Failed to import log: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadLogs() {
        // Replace with actual log loading logic if needed
        logs = """
        Example log:
        12May1425 Object detected: person at (x: 0.1234, y: 0.5678, width: 0.2345, height: 0.3456)
        12May1426 Face detected at (x: 0.1234, y: 0.5678, width: 0.2345, height: 0.3456)
        """
    }
    
    private func loadLog(from url: URL) {
        do {
            let logContent = try String(contentsOf: url)
            logs = logContent
        } catch {
            print("Error loading log: \(error.localizedDescription)")
        }
    }

    private func exportLog(url: URL) {
        do {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("exported_log.txt")
            try logs.write(to: tempURL, atomically: true, encoding: .utf8)
        let documentPicker = NSOpenPanel()
        } catch {
            print("Error exporting log: \(error.localizedDescription)")
        }
    }
}
