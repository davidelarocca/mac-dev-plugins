import SwiftUI

// Values are examples. Tune them to the app, keep the names intent-based.

public enum Spacing {
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24
    /// Space between major sections of a screen.
    public static let section: CGFloat = 32
}

public enum Radius {
    public static let control: CGFloat = 6
    public static let card: CGFloat = 10
    public static let window: CGFloat = 14
}

public enum Typography {
    public static let body = Font.body
    public static let caption = Font.caption
    public static let sectionTitle = Font.title3.weight(.semibold)
    public static let pillLabel = Font.callout.weight(.medium)
    /// Monospaced digits for durations, bit depth and sample rate.
    public static let technical = Font.caption.monospacedDigit()
}

public enum Motion {
    public static let quick = Animation.snappy(duration: 0.15)
    public static let standard = Animation.snappy(duration: 0.25)
    public static let emphasized = Animation.spring(duration: 0.4, bounce: 0.2)

    /// An animation that moves content (position, size, scale): none under Reduce Motion.
    /// `.animation(Motion.moving(Motion.standard, reduced: reduceMotion), value: isOpen)`
    public static func moving(_ animation: Animation, reduced: Bool) -> Animation? {
        reduced ? nil : animation
    }

    /// A transition that moves content: a fade under Reduce Motion.
    /// `.transition(Motion.moving(.move(edge: .top), reduced: reduceMotion))`
    public static func moving(_ transition: AnyTransition, reduced: Bool) -> AnyTransition {
        reduced ? .opacity : transition
    }
}

/// Reduce Motion as the design system reads it: `@ReduceMotion private var reduceMotion` in a
/// component. It is the system setting, unless a test or a preview sets
/// `.environment(\.reduceMotionOverride, true)`: SwiftUI's `accessibilityReduceMotion` is
/// read-only, so a test cannot turn it on.
@propertyWrapper
public struct ReduceMotion: DynamicProperty {
    @Environment(\.accessibilityReduceMotion) private var system
    @Environment(\.reduceMotionOverride) private var override

    public init() {}

    public var wrappedValue: Bool { override ?? system }
}

public extension EnvironmentValues {
    /// Set by tests and previews to check a component with Reduce Motion on or off.
    @Entry var reduceMotionOverride: Bool? = nil
}

// Semantic colors live in Resources/Colors.xcassets with light and dark variants.
// Usage: Color.DS.surface
public extension Color {
    enum DS {
        public static let surface = Color("surface", bundle: .module)
        public static let surfaceRaised = Color("surfaceRaised", bundle: .module)
        public static let accentSoft = Color("accentSoft", bundle: .module)
        public static let success = Color("success", bundle: .module)
        public static let warning = Color("warning", bundle: .module)
        public static let danger = Color("danger", bundle: .module)
    }
}
