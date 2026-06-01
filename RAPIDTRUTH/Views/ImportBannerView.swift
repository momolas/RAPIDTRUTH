import SwiftUI

enum ImportBanner: Equatable {
    case success(String)
    case failure(String)
}

struct ImportBannerView: View {
    let banner: ImportBanner

    var body: some View {
        let (text, color): (String, Color) = switch banner {
        case .success(let msg): (msg, .green)
        case .failure(let msg): (msg, .red)
        }
        
        Text(text)
            .font(.body)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(color.opacity(0.9))
            .clipShape(.rect(cornerRadius: 10))
            .frame(maxWidth: .infinity)
    }
}
