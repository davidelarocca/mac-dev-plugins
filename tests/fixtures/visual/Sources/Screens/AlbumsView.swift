import SwiftUI

struct Album: Identifiable {
    let id = UUID()
    let title: String
    let artist: String
}

public struct AlbumsView: View {
    private let albums = [
        Album(title: "Pastel Blues", artist: "Nina Simone"),
        Album(title: "Kind of Blue", artist: "Miles Davis"),
        Album(title: "async", artist: "Ryuichi Sakamoto"),
        Album(title: "Zombie", artist: "Fela Kuti"),
        Album(title: "Homogenic", artist: "Björk"),
        Album(title: "Dummy", artist: "Portishead"),
    ]

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Albums")
                .font(DS.Font.title)
                .padding(DS.Space.m)
            List(albums) { album in
                HStack(spacing: DS.Space.s) {
                    Image(systemName: "square.stack")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        Text(album.title).font(DS.Font.rowTitle)
                        Text(album.artist).font(DS.Font.rowDetail).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, DS.Space.xs)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .padding(.horizontal, DS.Space.m)
        }
    }
}
