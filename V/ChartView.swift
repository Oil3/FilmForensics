import SwiftUI

struct ChartView: View {
    var data: [FPSChartData]
    
    var body: some View {
        GeometryReader { geometry in
            let maxY = data.map { max($0.fps, $0.prediction) }.max() ?? 1
            let minY = data.map { min($0.fps, $0.prediction) }.min() ?? 0
            let timeRange = data.last?.time ?? 0 - (data.first?.time ?? 0)
            
            let yScale = geometry.size.height / CGFloat(maxY - minY)
            let xScale = geometry.size.width / CGFloat(timeRange)
            
            Path { path in
                for (index, dataPoint) in data.enumerated() {
                    let xPosition = CGFloat(dataPoint.time - (data.first?.time ?? 0)) * xScale
                    let yPosition = geometry.size.height - (CGFloat(dataPoint.fps - minY) * yScale)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: xPosition, y: yPosition))
                    } else {
                        path.addLine(to: CGPoint(x: xPosition, y: yPosition))
                    }
                }
            }
            .stroke(Color.blue, lineWidth: 2)
            
            Path { path in
                for (index, dataPoint) in data.enumerated() {
                    let xPosition = CGFloat(dataPoint.time - (data.first?.time ?? 0)) * xScale
                    let yPosition = geometry.size.height - (CGFloat(dataPoint.prediction - minY) * yScale)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: xPosition, y: yPosition))
                    } else {
                        path.addLine(to: CGPoint(x: xPosition, y: yPosition))
                    }
                }
            }
            .stroke(Color.green, lineWidth: 2)
        }
    }
}

struct FPSChartData: Identifiable {
    let id = UUID()
    let time: Double
    let fps: Double
    let prediction: Double
}
