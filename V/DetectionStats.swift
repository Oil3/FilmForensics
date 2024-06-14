import Foundation
import AVFoundation
import Combine

struct Stats: Identifiable {
    var id: UUID = UUID()
    var key: String
    var value: String
}

class DetectionStats: ObservableObject {
    static let shared = DetectionStats()
    
    @Published var show: Bool = false
    @Published var items: [Stats] = []
    @Published var fpsData: [FPSChartData] = []
    
    private var playedForCurrentSession = false
    private var cancellables = Set<AnyCancellable>()
    private var playingSounds: [String: Date] = [:]
    private let maxConcurrentSounds = 3
    private let soundDuration: TimeInterval = 3.0
    private var trackedObjects: [UUID: TrackedObject] = [:]
    
    init() {
        $items
            .map { items in
                items.contains { $0.key == "Det. Objects" && (Int($0.value) ?? 0) > 0 }
            }
            .removeDuplicates()
            .sink { [weak self] hasDetections in
                if hasDetections {
                    if !self!.playedForCurrentSession && (self?.playingSounds.count ?? 0) < self!.maxConcurrentSounds {
                        self?.playSound(named: "detFX")
                        self!.playedForCurrentSession = true
                    }
                } else {
                    self!.playedForCurrentSession = false
                }
            }
            .store(in: &cancellables)
    }
    
    func addMultiple(_ stats: [Stats], removeAllFirst: Bool = true) {
        if removeAllFirst {
            items.removeAll()
        }
        items.append(contentsOf: stats)
        updateTrackedObjects(with: stats)
    }
    
    func updateTrackedObjects(with stats: [Stats]) {
        let now = Date()
        
        for stat in stats {
            if let existingObject = trackedObjects.values.first(where: { $0.stats.key == stat.key && $0.stats.value == stat.value }) {
                trackedObjects[existingObject.id]?.lastDetected = now
            } else {
                let newObject = TrackedObject(id: UUID(), stats: stat, lastDetected: now)
                trackedObjects[newObject.id] = newObject
            }
        }
        
        let timeout: TimeInterval = 5.0
        trackedObjects = trackedObjects.filter { now.timeIntervalSince($0.value.lastDetected) < timeout }
    }
    
    func playSound(named soundName: String) {
        guard let url = Bundle.main.url(forResource: soundName, withExtension: "m4a") else { return }
        
        if playingSounds.count >= maxConcurrentSounds {
            return
        }
        
        let soundID = UUID().uuidString
        playingSounds[soundID] = Date()
        
        var sound: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &sound)
        AudioServicesPlaySystemSound(sound)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + soundDuration) { [weak self] in
            self?.playingSounds.removeValue(forKey: soundID)
        }
    }
    
    func addFPSData(_ data: FPSChartData) {
        fpsData.append(data)
    }
}

struct FPSChartData: Identifiable {
    let name: String
    let time: String
    let value: Double
    let id = UUID()
}

struct TrackedObject {
    let id: UUID
    let stats: Stats
    var lastDetected: Date
}
