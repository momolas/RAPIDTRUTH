import SwiftUI

struct ImportBannerView: View {
    let banner: ImportBanner

    var body: some View {
        let (text, color): (String, Color) = switch banner {
        case .success(let msg): (msg, .green)
        case .failure(let msg): (msg, .red)
        }
        
        return Text(text)
            .font(.bodyText)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular.tint(color), in: .rect(cornerRadius: 10))
            .frame(maxWidth: .infinity)
    }
}
