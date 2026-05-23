import SwiftUI

struct SessionPaginationBar: View {
    @Binding var page: Int
    let pageCount: Int

    var body: some View {
        HStack {
            Button {
                page = max(0, page - 1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .paginationButtonStyle()
            .controlSize(.small)
            .disabled(page == 0)

            Spacer()

            Text("Page \(page + 1) of \(pageCount)")
                .font(.monoSmall)
                .foregroundStyle(.tertiary)

            Spacer()

            Button {
                page = min(pageCount - 1, page + 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .paginationButtonStyle()
            .controlSize(.small)
            .disabled(page >= pageCount - 1)
        }
        .padding(.top, 4)
    }
}
