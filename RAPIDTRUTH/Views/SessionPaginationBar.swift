import SwiftUI

struct SessionPaginationBar: View {
    @Binding var page: Int
    let pageCount: Int

    var body: some View {
        HStack {
            Button("Previous Page", systemImage: "chevron.left") {
                page = max(0, page - 1)
            }
            .paginationButtonStyle()
            .labelStyle(.iconOnly)
            .controlSize(.small)
            .disabled(page == 0)

            Spacer()

            Text("Page \(page + 1) of \(pageCount)")
                .font(.monoSmall)
                .foregroundStyle(.tertiary)

            Spacer()

            Button("Next Page", systemImage: "chevron.right") {
                page = min(pageCount - 1, page + 1)
            }
            .paginationButtonStyle()
            .labelStyle(.iconOnly)
            .controlSize(.small)
            .disabled(page >= pageCount - 1)
        }
        .padding(.top, 4)
    }
}
