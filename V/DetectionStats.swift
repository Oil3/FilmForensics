import Foundation
import SwiftUI

class DetectionStats: ObservableObject {
    static let shared = DetectionStats()
    @Published var items: [Stats] = []
    @Published var fpsData: [FPSChartData] = []

    private var frameCounter = 0
    private var predictionCounter = 0
    private var lastUpdate = Date()

    func addMultiple(_ stats: [Stats], removeAllFirst: Bool = true) {
        if removeAllFirst {
            items.removeAll()
        }
        items.append(contentsOf: stats)
    }

    func recordFrame() {
        frameCounter += 1
        updateStats()
    }

    func recordPrediction() {
        predictionCounter += 1
        updateStats()
    }

    private func updateStats() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastUpdate)

        if elapsed >= 1.0 {
            let fps = Double(frameCounter) / elapsed
            let pps = Double(predictionCounter) / elapsed

            fpsData.append(FPSChartData(time: now.timeIntervalSince1970, fps: fps, prediction: pps))

            // Keep only the last 10 seconds of data
            fpsData = fpsData.filter { $0.time > now.timeIntervalSince1970 - 10 }

            frameCounter = 0
            predictionCounter = 0
            lastUpdate = now
        }
    }
}

struct Stats: Identifiable {
    let id = UUID()
    let key: String
    let value: String
}
