import SwiftUI


/// Centralized typography scale for the iOS app. Use these tokens instead
/// of inline `.font(.caption.monospaced())` etc. so the visual hierarchy
/// is one file's responsibility, not scattered across every view.
///
/// Hierarchy, largest to smallest:
///
///   appBrand     — `obd2/logger` header bar (title2 mono bold)
///   stepTitle    — onboarding step heading (title2 semibold)
///   cardTitle    — section labels: "Vehicles", "Connection", "Sessions"…
///   valueLabel   — primary content: vehicle display name, vehicle row title
///   valueNumber  — live readout numbers (callout mono semibold)
///   bodyText     — descriptions, hints (callout)
///   statusText   — error / status messages (footnote)
///   captionText  — small inline labels / counts (caption)
///   captionTiny  — even smaller inline labels (caption2)
///   monoSmall    — slugs, profile IDs, ACTIVE badge, timestamps
///   monoTiny     — micro metadata: cached-PID counts, log direction labels
///
/// When an existing call doesn't fit cleanly into one of these, prefer
/// adding a new token here over reintroducing inline font expressions.

struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}


extension View {
    func appCard() -> some View {
        self.modifier(AppCardModifier())
    }
    
    @ViewBuilder
    func glassActionButton(prominent: Bool = false) -> some View {
        if prominent {
            self.buttonStyle(.glassProminent)
                .buttonBorderShape(.roundedRectangle)
        } else {
            self.buttonStyle(.glass)
                .buttonBorderShape(.roundedRectangle)
        }
    }
}

// MARK: - iOS 26+ Liquid Glass Stubs for older SDK Compile-time Compatibility

#if !compiler(>=7.0) // Provide stubs for older Swift compilers / SDKs

public struct Glass: Sendable {
    public static let regular = Glass()
    
    public func tint(_ color: Color) -> Glass { self }
    public func interactive(_ enabled: Bool = true) -> Glass { self }
}

public struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content
    
    public init(spacing: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    public var body: some View {
        content
    }
}

extension View {
    public func glassEffect(_ variant: Glass = .regular, in shape: GlassShape = .capsule) -> some View {
        self.background(.ultraThinMaterial, in: shape.fallbackShape)
    }
    
    public func glassEffect() -> some View {
        self.background(.ultraThinMaterial, in: Capsule())
    }
}

public enum GlassShape {
    case capsule
    case circle
    case rect(cornerRadius: CGFloat)
    
    var fallbackShape: some Shape {
        switch self {
        case .capsule:
            return AnyShape(Capsule())
        case .circle:
            return AnyShape(Circle())
        case .rect(let radius):
            return AnyShape(RoundedRectangle(cornerRadius: radius))
        }
    }
}

#endif
