import AppKit
@testable import DesignSystem
import Testing

/// Tokens.swift loads its semantic colors by name. `Color("name", bundle:)` never fails when
/// created, so check that every name resolves in the package's asset catalog.
/// The fixture colors are placeholders, not a palette.
@Test(arguments: ["surface", "surfaceRaised", "accentSoft", "success", "warning", "danger"])
func semanticColorResolves(_ name: String) {
    #expect(NSColor(named: name, bundle: .module) != nil, "Colors.xcassets has no color named \(name)")
}
