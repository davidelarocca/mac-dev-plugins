import SwiftUI

/// A screen with a button that has no description, fixed with the `-labeled` launch argument.
/// With `-focus`, a screen for the focus order and keyboard checks (#52); `-skipShuffle` takes
/// its toggle out of the Tab loop, the negative control.
@main
struct A11yFixtureApp: App {
    var body: some Scene {
        WindowGroup {
            if CommandLine.arguments.contains("-resize") {
                ResizeScreen()
            } else if CommandLine.arguments.contains("-layout") {
                LayoutScreen()
            } else if CommandLine.arguments.contains("-focus") {
                FocusScreen(skipShuffle: CommandLine.arguments.contains("-skipShuffle"))
            } else {
                ContentView(labeled: CommandLine.arguments.contains("-labeled"))
            }
        }
    }
}

struct FocusScreen: View {
    let skipShuffle: Bool
    @State private var search = ""
    @State private var shuffle = true
    @State private var details = false

    var body: some View {
        VStack(spacing: 12) {
            Button("Play") {}.accessibilityIdentifier("play")
            TextField("Search", text: $search).accessibilityIdentifier("search")
            // Not `.focusable(!skipShuffle)`: on a control that already takes focus,
            // .focusable(true) adds a second Tab stop with no accessibility element.
            if skipShuffle {
                Toggle("Shuffle", isOn: $shuffle).focusable(false).accessibilityIdentifier("shuffle")
            } else {
                Toggle("Shuffle", isOn: $shuffle).accessibilityIdentifier("shuffle")
            }
            Text("Queue").focusable().accessibilityIdentifier("queue")
            Button("Details") { details = true }.keyboardShortcut("i", modifiers: .command).accessibilityIdentifier("details")
        }
        .padding(40)
        .frame(minWidth: 320, minHeight: 240)
        .sheet(isPresented: $details) {
            VStack(spacing: 12) {
                Text("Details")
                Button("Done") { details = false }.keyboardShortcut(.cancelAction)
            }
            .padding(40)
            .accessibilityIdentifier("detailsSheet")
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
