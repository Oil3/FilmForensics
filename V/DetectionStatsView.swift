import SwiftUI
import Charts

struct DetectionStatsView: View {
    @EnvironmentObject var detectionStats: DetectionStats

    var body: some View {
        VStack {
            List {
                ForEach(detectionStats.items) { stat in
                    HStack {
                        Text(stat.key)
                        Spacer()
                        Text(stat.value)
                    }
                }
            }
            .listStyle(PlainListStyle())

            if !detectionStats.fpsData.isEmpty {
                FPSChartView(data: detectionStats.fpsData)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

struct FPSChartView: View {
    var data: [FPSChartData]

    var body: some View {
        Chart(data, id: \.id) { item in
            LineMark(
                x: .value("Time", item.time),
                y: .value("Value", item.value)
            )
        }
        .chartYScale(domain: 0...60)
        .padding()
    }
}
