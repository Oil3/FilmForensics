import SwiftUI

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
                ChartView(data: detectionStats.fpsData)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}
