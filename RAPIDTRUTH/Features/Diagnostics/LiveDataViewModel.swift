import Foundation
import Observation

@MainActor
@Observable
final class LiveDataViewModel {
    private(set) var isSampling = false
    private(set) var liveValues: [String: Sampler.LiveValue] = [:]
    private(set) var disabledPIDs: Set<String> = []
    private(set) var tickCount = 0
    private(set) var chartHistory: [String: [ChartDataPoint]] = [:]
    
    private var sampler: Sampler?
    private var sessionStartMs: Int = 0
    
    func startSampling(interface: VehicleInterface, profile: Profile, selectedPids: [PidDef]) {
        guard !selectedPids.isEmpty else { return }
        
        // Ensure Panda safety model is set to allOutput for active queries
        Task {
            if let panda = interface as? PandaDriver {
                try? await panda.setSafetyModel(.allOutput)
            }
        }
        
        isSampling = true
        liveValues.removeAll()
        disabledPIDs.removeAll()
        chartHistory.removeAll()
        tickCount = 0
        sessionStartMs = Int(Date.now.timeIntervalSince1970 * 1000)
        
        let newSampler = Sampler(
            driver: interface,
            pids: selectedPids,
            ecus: profile.ecus,
            sampleRateHz: 2.0, // 2Hz
            sessionStartMs: sessionStartMs
        )
        
        newSampler.onValues = { [weak self] values in
            guard let self else { return }
            Task { @MainActor in
                self.handleIncomingValues(values)
            }
        }
        
        newSampler.onTick = { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.tickCount += 1
                if let sampler = self.sampler {
                    self.disabledPIDs = sampler.disabledPIDs
                }
            }
        }
        
        self.sampler = newSampler
        newSampler.start()
        NSLog("[LiveData] Started sampling with \(selectedPids.count) PIDs")
    }
    
    private func handleIncomingValues(_ values: [Sampler.LiveValue]) {
        for val in values {
            self.liveValues[val.pidID] = val
            if let doubleVal = val.value {
                let point = ChartDataPoint(timestamp: Date(), value: doubleVal)
                var points = self.chartHistory[val.pidID] ?? []
                points.append(point)
                if points.count > 30 {
                    points.removeFirst()
                }
                self.chartHistory[val.pidID] = points
            }
        }
    }
    
    func stopSampling() {
        sampler?.stop()
        sampler = nil
        isSampling = false
        NSLog("[LiveData] Stopped sampling")
    }
}
