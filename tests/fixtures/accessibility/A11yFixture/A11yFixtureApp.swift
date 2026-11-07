import SwiftUI

/// A screen with a button that has no description, fixed with the `-labeled` launch argument.
@main
struct A11yFixtureApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(labeled: CommandLine.arguments.contains("-labeled"))
        }
    }
}

struct ContentView: View {
    let labeled: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Library").font(.title)
            Button("Play") {}
            if labeled {
                Button {} label: { Circle().fill(Color.accentColor).frame(width: 44, height: 44) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Favorite")
                    .accessibilityIdentifier("favorite")
            } else {
                Button {} label: { Circle().fill(Color.accentColor).frame(width: 44, height: 44) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("favorite")
            }
        }
        .padding(40)
        .frame(minWidth: 320, maxWidth: .infinity, minHeight: 240, maxHeight: .infinity)
        // The screen's container is named, as the audit asks on macOS for the window's root group.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Library")
    }
}
