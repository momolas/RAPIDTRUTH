import Foundation
import Observation

/// Niveau de priorité des opérations accédant à l'interface véhicule / Panda.
enum BusPriority: Int, Comparable, Sendable {
    case background = 0
    case interactive = 1
    case criticalExclusive = 2

    static func < (lhs: BusPriority, rhs: BusPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Coordinateur d'accès au bus pour arbitrer et synchroniser les requêtes entre les différents modules
/// (Diagnostic, Sampler temps réel, Fuzzer, Actuateurs, Flashing).
@MainActor
@Observable
final class BusCoordinator {
    static let shared = BusCoordinator()

    private(set) var activeSessionName: String? = nil
    private(set) var activePriority: BusPriority = .background
    private(set) var isBusy: Bool = false

    private var lockHolderCount = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    private init() {}

    /// Tente ou attend l'acquisition du bus pour une opération critique.
    func acquire(priority: BusPriority = .interactive, name: String) async {
        while isBusy && priority <= activePriority {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }

        isBusy = true
        activePriority = priority
        activeSessionName = name
        lockHolderCount += 1
    }

    /// Libère l'accès au bus et réveille les tâches en attente.
    func release() {
        guard lockHolderCount > 0 else { return }
        lockHolderCount -= 1

        if lockHolderCount == 0 {
            isBusy = false
            activeSessionName = nil
            activePriority = .background

            if !waiters.isEmpty {
                let next = waiters.removeFirst()
                next.resume()
            }
        }
    }

    /// Exécute un bloc asynchrone avec réservation exclusive du bus.
    func withExclusiveAccess<T: Sendable>(
        priority: BusPriority = .interactive,
        name: String,
        operation: @MainActor () async throws -> T
    ) async throws -> T {
        await acquire(priority: priority, name: name)
        defer {
            release()
        }
        return try await operation()
    }
}
