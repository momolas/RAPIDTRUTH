import SwiftUI
import SwiftData

struct SessionsListView: View {
    // Fixed to Scenic 2 — no multi-vehicle management.
    private let owner = "rapidtruth"
    private let vehicleSlug = "renault_scenic2_m9r722"
    @Environment(LoggingSession.self) private var session
    @State private var sessions: [SessionRecord] = []
    @State private var page: Int = 0

    private let pageSize = 10

    private var pageCount: Int {
        max(1, (sessions.count + pageSize - 1) / pageSize)
    }

    private var pageSlice: [SessionRecord] {
        let start = page * pageSize
        let end = min(start + pageSize, sessions.count)
        guard start < end else { return [] }
        return Array(sessions[start..<end])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sessions").font(.cardTitle)
                Spacer()
                Text("\(sessions.count)")
                    .font(.monoSmall)
                    .foregroundStyle(.tertiary)
            }
            if sessions.isEmpty {
                Text("No sessions yet for the active vehicle.")
                    .font(.bodyText)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                if #available(iOS 26, *) {
                    GlassEffectContainer(spacing: 8) {
                        ForEach(pageSlice) { record in
                            SessionRowView(record: record, fileURL: sessionFileURL(for: record))
                        }
                    }
                } else {
                    ForEach(pageSlice) { record in
                        SessionRowView(record: record, fileURL: sessionFileURL(for: record))
                    }
                }
                if pageCount > 1 {
                    SessionPaginationBar(page: $page, pageCount: pageCount)
                }
            }
        }
        .appCard()
        .task { reload() }
        .onChange(of: session.state) { _, _ in reload() }
    }

    /// Resolve a session record's relative `file` path (e.g.
    /// `sessions/2026-05-04T...csv`) to the on-disk URL inside the app's
    /// Documents directory.
    private func sessionFileURL(for record: SessionRecord) -> URL {
        let relative = "data/\(owner)/\(vehicleSlug)/\(record.file)"
        return AppStorage.shared.url(for: relative)
    }

    private func reload() {
        let slug = vehicleSlug
        let ownerName = owner
        var descriptor = FetchDescriptor<Vehicle>(
            predicate: #Predicate<Vehicle> { $0.slug == slug && $0.owner == ownerName }
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.sessions]
        guard let vehicle = try? VehicleStore.shared.context.fetch(descriptor).first else {
            sessions = []
            page = 0
            return
        }
        sessions = vehicle.sessions.sorted { $0.startUTC > $1.startUTC }
        // Clamp page if a deletion shrank the list past our current page.
        if page >= pageCount { page = max(0, pageCount - 1) }
    }
}
