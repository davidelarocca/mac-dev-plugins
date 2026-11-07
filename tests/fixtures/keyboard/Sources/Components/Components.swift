import SwiftUI

/// Save and Cancel at the bottom of a sheet: Return saves, Escape cancels.
public struct SaveBar: View {
    let onSave: () -> Void
    let onCancel: () -> Void

    public init(onSave: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        HStack {
            Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
            Button("Save", action: onSave).keyboardShortcut(.defaultAction)
        }
    }
}

/// A list of tracks: arrows move the selection, Return plays it, Command-F finds.
public struct TrackList: View {
    let tracks: [String]
    @Binding var selection: Int
    let onPlay: (String) -> Void
    let onFind: () -> Void

    public init(tracks: [String], selection: Binding<Int>, onPlay: @escaping (String) -> Void, onFind: @escaping () -> Void) {
        self.tracks = tracks
        _selection = selection
        self.onPlay = onPlay
        self.onFind = onFind
    }

    public var body: some View {
        VStack(alignment: .leading) {
            ForEach(tracks.indices, id: \.self) { index in
                Text(tracks[index]).fontWeight(index == selection ? .bold : .regular)
            }
            Button("Find", action: onFind).keyboardShortcut("f", modifiers: .command)
        }
        .focusable()
        .onKeyPress(.downArrow) { selection = min(selection + 1, tracks.count - 1); return .handled }
        .onKeyPress(.upArrow) { selection = max(selection - 1, 0); return .handled }
        .onKeyPress(.return) { onPlay(tracks[selection]); return .handled }
    }
}

/// An inspector panel: Escape closes it.
public struct Inspector: View {
    let onClose: () -> Void

    public init(onClose: @escaping () -> Void) { self.onClose = onClose }

    public var body: some View {
        Text("Details").focusable().onExitCommand(perform: onClose)
    }
}

/// A card whose action needs a pointer: a click opens it, no key does. The negative control.
public struct PointerOnlyCard: View {
    let onOpen: () -> Void

    public init(onOpen: @escaping () -> Void) { self.onOpen = onOpen }

    public var body: some View {
        RoundedRectangle(cornerRadius: 8).frame(width: 120, height: 80).onTapGesture(perform: onOpen)
    }
}
