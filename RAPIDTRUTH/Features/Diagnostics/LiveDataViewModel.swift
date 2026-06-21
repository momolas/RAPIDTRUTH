import Foundation
import Observation

@MainActor
@Observable
final class LiveDataViewModel {
    private(set) var isSampling = false
    private(set) var liveValues: [String: Sampler.LiveValue] = [:]
    private(set) var disabledPIDs: Set<String> = []
    private(set) var tickCount = 0
    
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
                for val in values {
                    self.liveValues[val.pidID] = val
                }
            }
        }
        
        newSampler.onTick = { [weak self] tickRow in
            guard let self else { return }
            Task { @MainActor in
                self.tickCount += 1
                self.disabledPIDs = newSampler.disabledPIDs
            }
        }
        
        self.sampler = newSampler
        newSampler.start()
        NSLog("[LiveData] Started sampling with \(selectedPids.count) PIDs")
    }
    
    func stopSampling() {
        sampler?.stop()
        sampler = nil
        isSampling = false
        NSLog("[LiveData] Stopped sampling")
    }
}
