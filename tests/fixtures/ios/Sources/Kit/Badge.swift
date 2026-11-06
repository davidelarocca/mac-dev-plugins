import SwiftUI

/// The platform the code was compiled for, so a test can tell where it ran.
public enum Platform {
    #if os(iOS)
    public static let name = "iOS"
    #else
    public static let name = "macOS"
    #endif
}

/// A small shared component, with the touch target iOS needs.
public struct Badge: View {
    let text: String

    public init(_ text: String) { self.text = text }

    public var body: some View {
        Text(text)
            .font(.caption)
            #if os(iOS)
            .frame(minWidth: 44, minHeight: 44)
            #endif
    }
}
