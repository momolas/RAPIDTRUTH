import SwiftUI
import SwiftData

struct SessionRowView: View {
    let record: SessionRecord
    let fileURL: URL

    var body: some View {
        ShareLink(item: fileURL) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.startUTC.replacing(".000Z", with: "Z"))
                        .font(.monoSmall)
                        .foregroundStyle(.primary)
                    Text("\(record.rowCount) rows · \(formatDuration(ms: record.durationMs))")
                        .font(.monoSmall)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text(record.endedReason)
                    .font(.monoSmall)
                    .foregroundStyle(.tertiary)
                Image(systemName: "square.and.arrow.up")
                    .font(.captionText)
                    .foregroundStyle(.tertiary)
            }
            .padding(8)
            .background {
                if #available(iOS 26, *) {
                    Color.clear.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 6))
                } else {
                    Color.appCardBackground
                        .clipShape(.rect(cornerRadius: 6))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(ms: Int) -> String {
        let duration = Duration.seconds(Double(ms) / 1000.0)
        return duration.formatted(.units(allowed: [.minutes, .seconds], width: .narrow))
    }
}
