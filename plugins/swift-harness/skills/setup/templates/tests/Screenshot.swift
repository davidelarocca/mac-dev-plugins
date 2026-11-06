// Screenshot.swift, from the swift-harness setup templates (#35).
// Copy it into the test target that has LayoutContract.swift: it reads sizes through it.
// Keep this header so updates can be compared.
//
// Renders a screen in a real window and saves PNG images for the ui-reviewer agent, which
// looks at them for what code and measurements cannot show: alignment, spacing rhythm,
// hierarchy, truncation, consistency between screens. Returns the problems found while
// capturing (empty when every image was saved):
//
//     XCTest:        XCTAssertEqual(Screenshot.capture("LibraryView") { LibraryView() }, [])
//     Swift Testing: #expect(Screenshot.capture("LibraryView") { LibraryView() } == [])
//
// Call it from a @MainActor test. With only a name, it takes Min and Default from the row of
// docs/LAYOUT_CONTRACT.md whose View is that name. For a component or a screen without a row,
// pass the sizes: `Screenshot.capture("PillView", sizes: ["320x60"]) { ... }`. A width alone
// ("320") takes the height the view needs. `state:` names a variant ("empty", "long-text").
// Each size is captured in light and dark appearance.
//
// These are evidence for a review, not a regression test: nothing is compared with a
// baseline, and the images change with the macOS version and the display scale.
//
// Images go to .build/swift-harness/screenshots/ under the project root (the folder with
// .claude/swift-harness.json, docs/LAYOUT_CONTRACT.md or .git), or `screenshots.path` in
// .claude/swift-harness.json, or `output:`. Each PNG has a .json beside it: screen, state,
// platform, size, appearance, scale, OS, source file, time. A sandboxed test host cannot
// write there: capture in a test target without a host app, or pass `output:`.
//
// How: an offscreen borderless window, captured from the window server. ImageRenderer and
// NSView.cacheDisplay are not used: they draw placeholders for List and other AppKit-backed
// controls, or drop SwiftUI text. The capture needs a logged-in session (it works in Xcode,
// `swift test` and GitHub's macOS runners); without one, or without permission to read the
// window, the image is blank and capture() reports it.

#if os(macOS)
import AppKit
import Foundation
import SwiftUI

enum Screenshot {
    /// The platform written in file names and metadata.
    static let platform = "macos"
    /// Time given to the window server to draw the window before it is captured.
    static let settle: TimeInterval = 0.3

    @MainActor
    static func capture<Content: View>(
        _ screen: String,
        sizes: [String]? = nil,
        state: String? = nil,
        contract: URL? = nil,
        output: URL? = nil,
        file: StaticString = #filePath,
        @ViewBuilder _ make: () -> Content
    ) -> [String] {
        let testFolder = URL(fileURLWithPath: "\(file)").deletingLastPathComponent()
        var source = ""
        var cells: [String]
        if let sizes {
            cells = sizes
        } else {
            guard let url = contract ?? LayoutContract.locate(from: testFolder) else {
                return ["No layout contract found above \(file) to read \(screen)'s sizes: pass sizes:, or add docs/LAYOUT_CONTRACT.md."]
            }
            guard let text = try? String(contentsOf: url, encoding: .utf8),
                  let rows = LayoutContract.rows(in: text) else {
                return ["Cannot read the Screens table of \(url.path)."]
            }
            guard let row = rows.first(where: { $0.view == screen }) else {
                return ["\(url.lastPathComponent) has no row with \(screen) as View: add one, or pass sizes:."]
            }
            source = cell(text, line: row.line, column: "file")
            cells = [row.min, row.defaultSize]
        }

        var sizes: [LayoutContract.Size] = []
        for text in cells {
            guard let parsed = LayoutContract.size(text) else { return ["\(screen): '\(text)' is not a size."] }
            if let size = parsed, !sizes.contains(size) { sizes.append(size) }
        }
        guard !sizes.isEmpty else { return ["\(screen): no size to capture."] }

        guard let folder = output ?? folder(from: testFolder) else {
            return ["No project root found above \(file): pass output:."]
        }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return ["Cannot create \(folder.path): \(error.localizedDescription). A sandboxed test host cannot write to the project: capture in a test target without a host app, or pass output:."]
        }

        _ = NSApplication.shared
        let content = make()
        var problems: [String] = []
        for size in sizes {
            for dark in [false, true] {
                let appearance = dark ? "dark" : "light"
                let base = [screen, state, platform, size.text, appearance].compactMap { $0 }.joined(separator: "-")
                let png = folder.appendingPathComponent("\(base).png")
                switch render(content, size: size, dark: dark) {
                case .failure(let reason):
                    problems.append("\(screen) at \(size.text), \(appearance): \(reason)")
                case .success(let (image, points)):
                    let rep = NSBitmapImageRep(cgImage: image)
                    guard let data = rep.representation(using: .png, properties: [:]) else {
                        problems.append("\(screen) at \(size.text), \(appearance): cannot encode the PNG.")
                        continue
                    }
                    let info: [String: Any] = [
                        "screen": screen,
                        "state": state ?? "",
                        "platform": platform,
                        "size": "\(LayoutContract.Size.number(points.width))x\(LayoutContract.Size.number(points.height))",
                        "contractSize": size.text,
                        "appearance": appearance,
                        "scale": points.width > 0 ? Double(image.width) / Double(points.width) : 1,
                        "os": ProcessInfo.processInfo.operatingSystemVersionString,
                        "source": source,
                        "test": "\(file)",
                        "captured": ISO8601DateFormatter().string(from: Date()),
                        "method": "offscreen window captured from the window server",
                    ]
                    do {
                        try data.write(to: png)
                        let json = try JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys])
                        try json.write(to: png.deletingPathExtension().appendingPathExtension("json"))
                    } catch {
                        problems.append("Cannot write \(png.path): \(error.localizedDescription)")
                    }
                }
            }
        }
        return problems
    }

    @MainActor
    static func render<Content: View>(_ content: Content, size: LayoutContract.Size, dark: Bool) -> Result<(CGImage, CGSize), Failure> {
        let host = NSHostingController(rootView: content)
        host.sizingOptions = []
        let height = size.height ?? min(host.sizeThatFits(in: CGSize(width: size.width, height: LayoutContract.unbounded)).height, 4000)
        let points = CGSize(width: size.width, height: max(height, 1))
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: points), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.backgroundColor = .windowBackgroundColor
        window.contentViewController = host
        window.setContentSize(points)
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
        defer { window.close() }
        let end = Date().addingTimeInterval(settle)
        while Date() < end { RunLoop.main.run(until: min(end, Date().addingTimeInterval(0.05))) }

        guard let capture = windowImage else {
            return .failure(Failure("CGWindowListCreateImage is not available on this macOS."))
        }
        guard let image = capture(.null, .optionIncludingWindow, CGWindowID(window.windowNumber), [.boundsIgnoreFraming, .bestResolution])?.takeRetainedValue(),
              image.width > 0, image.height > 0 else {
            return .failure(Failure("the window server returned no image (no logged-in session?)."))
        }
        if isBlank(image) {
            return .failure(Failure("the image is blank: the window server did not draw the window, or this process may not read it (Screen Recording permission)."))
        }
        return .success((image, points))
    }

    struct Failure: Error, CustomStringConvertible {
        var description: String
        init(_ description: String) { self.description = description }
    }

    // Looked up at run time: the function is deprecated since macOS 14 in favor of
    // ScreenCaptureKit, which cannot capture from a test process (SCStreamError -3811), and a
    // direct call would warn in projects that treat warnings as errors.
    private typealias WindowImage = @convention(c) (CGRect, CGWindowListOption, CGWindowID, CGWindowImageOption) -> Unmanaged<CGImage>?
    private static let windowImage: WindowImage? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage") else { return nil }
        return unsafeBitCast(symbol, to: WindowImage.self)
    }()

    /// True when every pixel has the same color.
    static func isBlank(_ image: CGImage) -> Bool {
        let width = image.width, height = image.height
        var pixels = [UInt32](repeating: 0, count: width * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn, let first = pixels.first else { return true }
        return pixels.allSatisfy { $0 == first }
    }

    /// `screenshots.path` from the first .claude/swift-harness.json above `start`, else
    /// .build/swift-harness/screenshots in the first folder above it with docs/LAYOUT_CONTRACT.md
    /// or .git.
    static func folder(from start: URL) -> URL? {
        let files = FileManager.default
        let fallback = ".build/swift-harness/screenshots"
        var dir = start.standardizedFileURL
        while true {
            let config = dir.appendingPathComponent(".claude/swift-harness.json")
            if let data = try? Data(contentsOf: config),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let shots = json["screenshots"] as? [String: Any]
                return dir.appendingPathComponent((shots?["path"] as? String) ?? fallback)
            }
            if files.fileExists(atPath: dir.appendingPathComponent("docs/LAYOUT_CONTRACT.md").path)
                || files.fileExists(atPath: dir.appendingPathComponent(".git").path) {
                return dir.appendingPathComponent(fallback)
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { return nil }
            dir = parent
        }
    }

    /// One cell of a table line, by header name, for columns LayoutContract.Row does not keep.
    static func cell(_ text: String, line: Int, column: String) -> String {
        let lines = text.components(separatedBy: "\n")
        guard line >= 1, line <= lines.count else { return "" }
        var header = line - 1
        while header > 0, lines[header - 1].trimmingCharacters(in: .whitespaces).hasPrefix("|") { header -= 1 }
        let names = LayoutContract.cellsOf(lines[header].trimmingCharacters(in: .whitespaces)).map { $0.lowercased() }
        let cells = LayoutContract.cellsOf(lines[line - 1].trimmingCharacters(in: .whitespaces))
        guard let index = names.firstIndex(of: column), index < cells.count else { return "" }
        return cells[index]
    }
}
#endif
