import SwiftUI

struct Artist: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let symbol: String
}

public struct ArtistsView: View {
    private let artists = [
        Artist(name: "Nina Simone", detail: "12 albums", symbol: "music.mic"),
        Artist(name: "Miles Davis", detail: "48 albums", symbol: "music.quarternote.3"),
        Artist(name: "Ryuichi Sakamoto", detail: "31 albums", symbol: "pianokeys"),
        Artist(name: "Fela Kuti", detail: "27 albums", symbol: "person.2.wave.2"),
        Artist(name: "Björk", detail: "10 albums", symbol: "waveform"),
        Artist(name: "Portishead", detail: "3 albums", symbol: "hifispeaker.2"),
    ]

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Artists")
                .font(DS.Font.title)
                .padding(DS.Space.m)
            List(artists) { artist in
                HStack(spacing: DS.Space.s) {
                    Image(systemName: artist.symbol)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        Text(artist.name).font(DS.Font.rowTitle)
                        Text(artist.detail).font(DS.Font.rowDetail).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, DS.Space.xs)
            }
            .listStyle(.plain)
        }
    }
}
