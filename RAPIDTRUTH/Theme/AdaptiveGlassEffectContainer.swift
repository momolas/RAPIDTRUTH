import SwiftUI

struct AdaptiveGlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content
    
    var body: some View {
        GlassEffectContainer(spacing: spacing) {
            content
        }
    }
}
