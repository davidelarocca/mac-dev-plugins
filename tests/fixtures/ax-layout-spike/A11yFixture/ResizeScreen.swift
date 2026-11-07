import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ResizeScreen: View {
    @State private var info = ""
    var body: some View {
        GeometryReader { g in
            VStack {
                Text("size \(Int(g.size.width))x\(Int(g.size.height))").accessibilityIdentifier("size")
                Text(info).accessibilityIdentifier("info")
                Button("Refresh") { refresh() }.accessibilityIdentifier("refresh")
            }
        }
        .frame(minWidth: 320, minHeight: 240)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { refresh() } }
    }
    func refresh() {
        #if os(macOS)
        info = NSApp.windows.map { "\($0.frame) resizable=\($0.styleMask.contains(.resizable)) min=\($0.minSize) cmin=\($0.contentMinSize) autosave=\($0.frameAutosaveName.prefix(20))" }.joined(separator: " | ")
        #endif
    }
}
