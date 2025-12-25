import SwiftUI

// MARK: - App Theme Colors
extension Color {
    static let darkBackgroundStart = Color(hex: "0F172A") // Slate 900
    static let darkBackgroundEnd = Color(hex: "020617")   // Slate 950

    static let accentPrimary = Color(hex: "38BDF8")       // Sky 400
    static let accentSecondary = Color(hex: "818CF8")     // Indigo 400

    static let statusSuccess = Color(hex: "4ADE80")       // Green 400
    static let statusWarning = Color(hex: "FACC15")       // Yellow 400
    static let statusError = Color(hex: "F87171")         // Red 400

    static let textPrimary = Color.white
    static let textSecondary = Color.gray.opacity(0.8)

    // Helper for Hex
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - App Gradients
extension LinearGradient {
    static let mainBackground = LinearGradient(
        gradient: Gradient(colors: [.darkBackgroundStart, .darkBackgroundEnd]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        gradient: Gradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Glassmorphism Modifier
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(LinearGradient.cardGradient)
            .clipShape(.rect(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
    }
}

extension View {
    func glassCardStyle(cornerRadius: CGFloat = 16) -> some View {
        self.modifier(GlassCard(cornerRadius: cornerRadius))
    }
}
