import SwiftUI
#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage
#else
import UIKit
public typealias PlatformImage = UIImage
#endif

public struct HoverRow: View {
    @State private var hovering = false
    public var body: some View {
        Text("Row").onHover { hovering = $0 }
    }
}
