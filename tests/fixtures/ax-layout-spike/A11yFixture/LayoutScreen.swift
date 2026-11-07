import SwiftUI

/// Spike #69: what XCUIElement frames show for overflow, scroll, overlap and truncation.
struct LayoutScreen: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title").font(.title).accessibilityIdentifier("title")
            // A row wider than the window: cut by the window edge on both sides.
            HStack(spacing: 0) {
                ForEach(0..<5) { i in
                    Button("Item \(i)") {}.frame(width: 100).accessibilityIdentifier("row\(i)")
                }
            }
            .frame(width: 300)
            // Overlapping labels.
            ZStack(alignment: .leading) {
                Text("First label").accessibilityIdentifier("overA")
                Text("Second label").offset(x: 30, y: 4).accessibilityIdentifier("overB")
            }
            // Truncated by its own frame.
            Text("A very long sentence that cannot fit in its frame at all").lineLimit(1).frame(width: 80)
                .accessibilityIdentifier("truncated")
            // A scroll view with content taller than itself: cut on purpose.
            ScrollView {
                VStack {
                    ForEach(0..<20) { i in Text("Line \(i)").accessibilityIdentifier("line\(i)") }
                }
            }
            .frame(height: 60)
            .accessibilityIdentifier("scroll")
            // A list, also scrolling.
            List(0..<20, id: \.self) { i in Text("Cell \(i)").accessibilityIdentifier("cell\(i)") }
                .frame(height: 60)
                .accessibilityIdentifier("list")
            // A text pushed below the window bottom.
            Text("Below").offset(y: 200).accessibilityIdentifier("below")
            Text("Hidden").opacity(0).accessibilityIdentifier("hidden")
        }
        .padding(8)
        .frame(minWidth: 300, maxWidth: .infinity, minHeight: 320, maxHeight: .infinity)
    }
}
