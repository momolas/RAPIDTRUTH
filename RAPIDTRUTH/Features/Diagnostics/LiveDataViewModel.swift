import Foundation
import Observation
import SwiftVehicleProtocols

/// Profil global de cadencement d'échantillonnage
public enum SamplingProfilePreset: String, Sendable, CaseIterable, Identifiable {
    case performance = "Circuit / Performance"
    case balanced = "Équilibré (Recommandé)"
    case lowBandwidth = "Économie de Bus"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .performance: return "bolt.shield.fill"
        case .balanced: return "scale.3d"
        case .lowBandwidth: return "antenna.radiowaves.left.and.right"
        }
    }
}

@MainActor
@Observable
final class LiveDataViewModel {
    private(set) var isSampling = false
    private(set) var liveValues: [String: Sampler.LiveValue] = [:]
    private(set) var disabledPIDs: Set<String> = []
    private(set) var tickCount = 0
    private(set) var chartHistory: [String: [ChartDataPoint]] = [:]
    
    /// Cadences personnalisées par PID
    var customRates: [String: SamplingRate] = [:]
    
    /// Preset d'échantillonnage actif
    var activePreset: SamplingProfilePreset = .balanced {
        didSet {
            applyPreset(activePreset)
        }
    }
    
    /// Calcul du taux de rafraîchissement effectif par PID (Hz)
    private var lastUpdateTimes: [String: [Date]] = [:]
    private(set) var measuredFrequencies: [String: Double] = [:]
    
    private var sampler: Sampler?
    private var sessionStartMs: Int = 0
    
    func setRate(_ rate: SamplingRate, for pidId: String) {
        customRates[pidId] = rate
    }
    
    func rate(for pid: PidDef) -> SamplingRate {
        customRates[pid.id] ?? Sampler.defaultSamplingRate(for: pid)
    }
    
    private func applyPreset(_ preset: SamplingProfilePreset) {
        // Le preset adapte les règles lors du démarrage
    }
    
    func startSampling(interface: VehicleInterface, profile: Profile, selectedPids: [PidDef]) {
        guard !selectedPids.isEmpty else { return }
        
        Task {
            if let panda = interface as? PandaDriver {
                try? await panda.setSafetyModel(.allOutput)
            }
        }
        
        isSampling = true
        liveValues.removeAll()
        disabledPIDs.removeAll()
        chartHistory.removeAll()
        lastUpdateTimes.removeAll()
        measuredFrequencies.removeAll()
        tickCount = 0
        sessionStartMs = Int(Date.now.timeIntervalSince1970 * 1000)
        
        // Configuration de la cadence selon le preset
        var effectiveRates: [String: SamplingRate] = [:]
        for pid in selectedPids {
            if let userRate = customRates[pid.id] {
                effectiveRates[pid.id] = userRate
            } else {
                switch activePreset {
                case .performance:
                    let defRate = Sampler.defaultSamplingRate(for: pid)
                    effectiveRates[pid.id] = (defRate == .slow) ? .normal : .fast
                case .balanced:
                    effectiveRates[pid.id] = Sampler.defaultSamplingRate(for: pid)
                case .lowBandwidth:
                    let defRate = Sampler.defaultSamplingRate(for: pid)
                    effectiveRates[pid.id] = (defRate == .fast) ? .normal : .slow
                }
            }
        }
        
        let newSampler = Sampler(
            driver: interface,
            pids: selectedPids,
            ecus: profile.ecus,
            baseLoopRateHz: 10.0, // Boucle de base à 10 Hz pour alimenter le multi-rate
            customRates: effectiveRates,
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
        NSLog("[LiveData] Multi-Rate Sampler started (\(selectedPids.count) PIDs, preset: \(activePreset.rawValue))")
    }
    
    private func handleIncomingValues(_ values: [Sampler.LiveValue]) {
        let now = Date.now
        for val in values {
            self.liveValues[val.pidID] = val
            
            // Calcul fréquence effective
            var times = lastUpdateTimes[val.pidID] ?? []
            times.append(now)
            if times.count > 10 { times.removeFirst() }
            lastUpdateTimes[val.pidID] = times
            if times.count >= 2, let first = times.first {
                let duration = now.timeIntervalSince(first)
                if duration > 0.05 {
                    measuredFrequencies[val.pidID] = Double(times.count - 1) / duration
                }
            }
            
            if let doubleVal = val.value {
                let point = ChartDataPoint(timestamp: now, value: doubleVal)
                var points = self.chartHistory[val.pidID] ?? []
                points.append(point)
                if points.count > 40 {
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
        NSLog("[LiveData] Multi-Rate Sampler stopped")
    }
}
