import SwiftUI

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup { Text("Library") }
            .commands { CommandMenu("Playback") { Button("Play") {} } }
        Settings { Text("Preferences") }
        MenuBarExtra("Demo", systemImage: "music.note") { Text("Now playing") }
    }
}
