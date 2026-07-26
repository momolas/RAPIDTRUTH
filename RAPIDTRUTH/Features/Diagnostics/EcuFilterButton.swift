import SwiftUI

struct EcuFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.captionText)
                .bold()
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.appAccent : Color.white.opacity(0.1))
                .foregroundStyle(isSelected ? .black : .white)
                .clipShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}
