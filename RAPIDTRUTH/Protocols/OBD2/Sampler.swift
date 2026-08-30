import Foundation
import SwiftVehicleProtocols
import Observation

/// Cadence d'échantillonnage par PID pour le Multi-Rate Sampler
public enum SamplingRate: String, Sendable, CaseIterable, Identifiable, Codable {
    case fast = "Rapide (10 Hz)"
    case normal = "Normal (2 Hz)"
    case slow = "Lent (0.5 Hz)"
    
    public var id: String { rawValue }
    
    public var shortName: String {
        switch self {
        case .fast: return "10 Hz"
        case .normal: return "2 Hz"
        case .slow: return "0.5 Hz"
        }
    }
    
    /// Diviseur de cycle basé sur une boucle de base à 10 Hz
    public var tickDivider: Int {
        switch self {
        case .fast: return 1   // Chaque tick (10 Hz)
        case .normal: return 5 // Tous les 5 ticks (~2 Hz)
        case .slow: return 20  // Tous les 20 ticks (~0.5 Hz)
        }
    }
    
    public var iconName: String {
        switch self {
        case .fast: return "bolt.fill"
        case .normal: return "gauge.with.needle"
        case .slow: return "leaf.fill"
        }
    }
}

/// Tick-driven multi-rate sampler. Ordonnance les requêtes PID selon leur cadence
/// (rapide, normal, lent) pour maximiser le débit sans saturer le bus OBD.
@MainActor
final class Sampler {

    struct LiveValue: Sendable, Identifiable {
        var id: String { pidID }
        let pidID: String
        let raw: String   // hex string of response bytes (after the response code prefix)
        let value: Double?
        let unit: String
        let displayName: String
        let category: PidCategory
        let samplingRate: SamplingRate
        let timestamp: Date
    }

    struct TickRow: Sendable {
        let timestampISO: String
        let elapsedMs: Int
        /// Formatted strings keyed by `PidDef.id`. Empty/missing PIDs map to nil.
        let values: [String: String]
    }

    private let driver: VehicleInterface
    private let pids: [PidDef]
    private let ecus: [String: EcuDef]
    private let evaluator: FormulaEvaluator
    private let baseLoopRateHz: Double
    private let sessionStartMs: Int
    private let customRates: [String: SamplingRate]

    private var task: Task<Void, Never>?
    private var stopped = false
    private(set) var tickCount: Int = 0

    /// Per-PID strike counter. After 3 NO_DATA responses, the PID is demoted
    /// (skipped on subsequent ticks) to keep tick rate high.
    private var strikes: [String: Int] = [:]
    private(set) var disabledPIDs: Set<String> = []

    /// Periodically un-demote silent PIDs so we can re-detect them coming
    /// back online. Critical for hybrids: in EV mode the ICE PIDs go
    /// silent and would otherwise stay demoted for the whole session.
    private let rehabEveryNTicks = 60

    /// Inter-query gap (20 ms) pour éviter l'overrun sur clones ELM327.
    private let interQueryGapNs: UInt64 = 20_000_000

    var onValues: (([LiveValue]) -> Void)?
    var onTick: ((TickRow) -> Void)?

    init(
        driver: VehicleInterface,
        pids: [PidDef],
        ecus: [String: EcuDef],
        baseLoopRateHz: Double = 10.0,
        customRates: [String: SamplingRate] = [:],
        sessionStartMs: Int,
        evaluator: FormulaEvaluator? = nil
    ) {
        self.driver = driver
        self.pids = pids
        self.ecus = ecus
        self.baseLoopRateHz = baseLoopRateHz
        self.customRates = customRates
        self.sessionStartMs = sessionStartMs
        self.evaluator = evaluator ?? FormulaEvaluator()
    }

    /// Détermine la cadence par défaut optimale selon la nature du signal
    public static func defaultSamplingRate(for pid: PidDef) -> SamplingRate {
        let idLower = pid.id.lowercased()
        let nameLower = pid.displayName.lowercased()
        
        // PIDs haute dynamique -> Fast (10 Hz)
        if idLower.contains("rpm") || idLower.contains("regime") ||
           idLower.contains("speed") || idLower.contains("vitesse") ||
           idLower.contains("pedal") || idLower.contains("throttle") || idLower.contains("papillon") ||
           idLower.contains("turbo") || idLower.contains("boost") || idLower.contains("torque") ||
           idLower.contains("couple") || idLower.contains("pressure_intake") {
            return .fast
        }
        
        // PIDs thermiques / statiques -> Slow (0.5 Hz)
        if idLower.contains("temp") || nameLower.contains("température") ||
           idLower.contains("fuel_level") || idLower.contains("carburant") ||
           idLower.contains("battery_voltage") || idLower.contains("ambient") ||
           idLower.contains("oil_level") || idLower.contains("vin") || idLower.contains("distance") {
            return .slow
        }
        
        return .normal
    }

    func start() {
        task = Task { [weak self] in
            guard let self else { return }
            let intervalNs = UInt64(1_000_000_000.0 / self.baseLoopRateHz)
            while !Task.isCancelled && !self.stopped {
                do {
                    try Task.checkCancellation()
                } catch {
                    break
                }
                let tickStart = Date.now
                let row = await self.runOneTick()
                self.onTick?(row)
                let elapsed = Date.now.timeIntervalSince(tickStart)
                let remaining = max(0, (Double(intervalNs) / 1_000_000_000.0) - elapsed)
                if remaining > 0 {
                    do {
                        try await Task.sleep(for: .seconds(remaining))
                    } catch {
                        break
                    }
                }
            }
        }
    }

    func stop() {
        stopped = true
        task?.cancel()
        task = nil
    }

    private func runOneTick() async -> TickRow {
        tickCount += 1
        
        // Réhabilitation périodique des PIDs silencieux
        if tickCount % rehabEveryNTicks == 0, !disabledPIDs.isEmpty {
            NSLog("[Sampler] rehab tick \(tickCount): un-demoting \(disabledPIDs.count) PIDs")
            disabledPIDs.removeAll()
            strikes.removeAll()
        }

        let startMs = Int(Date.now.timeIntervalSince1970 * 1000)
        let elapsedMs = startMs - sessionStartMs
        let timestampISO = Date.now.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: TimeZone(secondsFromGMT: 0)!))

        var values: [String: String] = [:]
        var liveValuesCollected: [LiveValue] = []
        
        // Filtrage Multi-Rate : ne retenir que les PIDs arrivés à échéance lors de ce tick
        let eligiblePids = pids.filter { pid in
            guard !disabledPIDs.contains(pid.id) else { return false }
            let rate = customRates[pid.id] ?? Self.defaultSamplingRate(for: pid)
            return (tickCount % rate.tickDivider) == 0
        }
        
        // Si aucun PID n'est dû à ce tick précis, retourner la ligne vide
        if eligiblePids.isEmpty {
            return TickRow(timestampISO: timestampISO, elapsedMs: elapsedMs, values: values)
        }
        
        // Groupement par calculateur pour minimiser les changements de cibles ATSH
        let groups = groupByEcu(eligiblePids)
        for (ecuName, groupPIDs) in groups {
            if Task.isCancelled || self.stopped { break }
            if let ecu = ecus[ecuName] {
                _ = try? await driver.setTarget(txID: ecu.requestHeader, rxID: ecu.responseHeader)
            }
            for (mode, pid, defs) in dedupeByQuery(groupPIDs) {
                if Task.isCancelled || self.stopped { break }
                let request = mode + pid
                let response: String
                do {
                    response = try await driver.sendDiagnosticRequest(request, timeout: 1.0)
                } catch is CancellationError {
                    break
                } catch {
                    for def in defs { bumpStrike(def.id) }
                    try? await Task.sleep(for: .nanoseconds(Int(interQueryGapNs)))
                    continue
                }
                
                // Inter-query settle gap
                try? await Task.sleep(for: .nanoseconds(Int(interQueryGapNs)))
                let normalized = response.uppercased()
                    .replacing(" ", with: "")
                    .replacing("\n", with: "")
                    .replacing("\r", with: "")
                if normalized.contains("NODATA") {
                    for def in defs { bumpStrike(def.id) }
                    continue
                }
                if normalized.contains("STOPPED") {
                    for def in defs { bumpStrike(def.id) }
                    continue
                }
                guard let payload = extractPayload(response: response, mode: mode, pid: pid) else {
                    for def in defs { bumpStrike(def.id) }
                    continue
                }
                if !payload.isEmpty, payload.allSatisfy({ $0 == 0xFF }) {
                    for def in defs { bumpStrike(def.id) }
                    continue
                }
                for def in defs {
                    strikes[def.id] = 0
                    let evaluated = evaluator.evaluate(formula: def.formula, bytes: payload)
                    let formatted: String = {
                        if let v = evaluated {
                            return Sampler.format(value: v)
                        } else {
                            return HexParsing.hex(payload)
                        }
                    }()
                    values[def.id] = formatted
                    let rate = customRates[def.id] ?? Self.defaultSamplingRate(for: def)
                    let live = LiveValue(
                        pidID: def.id,
                        raw: HexParsing.hex(payload),
                        value: evaluated,
                        unit: def.unit,
                        displayName: def.displayName,
                        category: def.category,
                        samplingRate: rate,
                        timestamp: Date.now
                    )
                    liveValuesCollected.append(live)
                }
            }
        }
        
        if !liveValuesCollected.isEmpty {
            onValues?(liveValuesCollected)
        }
        
        return TickRow(timestampISO: timestampISO, elapsedMs: elapsedMs, values: values)
    }

    /// Group PIDs that share a (mode, pid) query
    private func dedupeByQuery(_ pids: [PidDef]) -> [(mode: String, pid: String, defs: [PidDef])] {
        var keyOrder: [String] = []
        var byKey: [String: (String, String, [PidDef])] = [:]
        for pid in pids {
            let key = "\(pid.mode)\(pid.pid)".uppercased()
            if var existing = byKey[key] {
                existing.2.append(pid)
                byKey[key] = existing
            } else {
                byKey[key] = (pid.mode, pid.pid, [pid])
                keyOrder.append(key)
            }
        }
        return keyOrder.compactMap { byKey[$0] }
    }

    private func groupByEcu(_ pids: [PidDef]) -> [(String, [PidDef])] {
        var grouped: [String: [PidDef]] = [:]
        for pid in pids {
            grouped[pid.ecu, default: []].append(pid)
        }
        return grouped.keys.sorted().map { ($0, grouped[$0]!) }
    }

    private func bumpStrike(_ id: String) {
        let current = (strikes[id] ?? 0) + 1
        strikes[id] = current
        if current >= 3 { disabledPIDs.insert(id) }
    }

    private static func format(value v: Double) -> String {
        if v.rounded() == v && abs(v) < 1e9 {
            return String(Int(v))
        }
        let rounded = (v * 1000).rounded() / 1000
        return String(rounded)
    }

    private func extractPayload(response: String, mode: String, pid: String) -> [UInt8]? {
        guard let modeByte = UInt8(mode, radix: 16) else { return nil }
        let prefix = String(format: "%02X%@", modeByte + 0x40, pid.uppercased())
        let lines = response.uppercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespaces).replacing(" ", with: "") }
            .filter { !$0.isEmpty }
            .map { line -> String in
                if let colonIdx = line.firstIndex(of: ":"),
                   line.distance(from: line.startIndex, to: colonIdx) <= 2,
                   line[..<colonIdx].allSatisfy({ $0.isHexDigit }) {
                    return String(line[line.index(after: colonIdx)...])
                }
                return line
            }
        
        let concatenated = lines.joined()
        if let prefixRange = concatenated.range(of: prefix) {
            let after = String(concatenated[prefixRange.upperBound...])
            return HexParsing.bytes(after)
        }
        return nil
    }
}
