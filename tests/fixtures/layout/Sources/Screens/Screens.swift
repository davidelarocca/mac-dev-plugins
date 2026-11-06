import SwiftUI

/// The filter bar of a library: ten filters with labels that never shrink, about 770 pt wide.
struct FilterBar: View {
    var body: some View {
        HStack {
            ForEach(Self.filters, id: \.self) { Text($0).fixedSize() }
        }
    }

    static let filters = ["All items", "Recently added", "Favorites", "Shared with me", "Downloaded",
                          "Archived", "Tagged", "Untagged", "Starred by others", "Large files"]
}

/// Breaks at its 640 pt minimum: the filter bar needs more.
public struct LibraryView: View {
    public init() {}
    public var body: some View {
        VStack(alignment: .leading) {
            FilterBar()
            List(0..<20, id: \.self) { Text("Item \($0)") }
        }
    }
}

/// The library window: its minimum is the contract's Min.
public struct LibraryWindow: View {
    public init() {}
    public var body: some View {
        LibraryView().frame(minWidth: 640, minHeight: 400)
    }
}

/// Holds: below the full bar's width the filters collapse into a menu.
public struct CompactLibraryView: View {
    public init() {}
    public var body: some View {
        VStack(alignment: .leading) {
            ViewThatFits(in: .horizontal) {
                FilterBar()
                Menu("Filter") { ForEach(FilterBar.filters, id: \.self) { Button($0) {} } }.fixedSize()
            }
            List(0..<20, id: \.self) { Text("Item \($0)") }
        }
    }
}

/// Breaks: shows its content with no minimum, so the window shrinks to nothing.
public struct UnboundedWindow: View {
    public init() {}
    public var body: some View {
        List(0..<20, id: \.self) { Text("Item \($0)") }
    }
}

/// Breaks: two fixed-height sections taller than the minimum height.
public struct InspectorPane: View {
    public init() {}
    public var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 200)
            Color.clear.frame(height: 200)
        }
    }
}

/// Holds: declares both its minimum and its maximum size.
public struct BoundedWindow: View {
    public init() {}
    public var body: some View {
        List(0..<20, id: \.self) { Text("Item \($0)") }
            .frame(minWidth: 480, maxWidth: 1200, minHeight: 300, maxHeight: 900)
    }
}
