import Foundation
public struct Song: Codable, Sendable { public var id: Int; public var title: String; public var artist: String; public var seconds: Double }
public enum Library {
    public static func data(count: Int) -> Data {
        let songs = (0..<count).map { Song(id: $0, title: "Song \(($0 * 7919) % count)", artist: "Artist \($0 % 97)", seconds: Double($0 % 300)) }
        return try! JSONEncoder().encode(songs)
    }
    /// The measured operation: decode and sort.
    public static func load(_ data: Data, slow: Bool = false) -> [Song] {
        var songs = try! JSONDecoder().decode([Song].self, from: data)
        if slow { for _ in 0..<1 { songs = try! JSONDecoder().decode([Song].self, from: data) } }
        return songs.sorted { ($0.artist, $0.title) < ($1.artist, $1.title) }
    }
}
