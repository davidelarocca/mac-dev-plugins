#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import DesignSystem

// The Reduce Motion helpers of references/Tokens.swift (#52): a test turns Reduce Motion on with
// the override, which SwiftUI's own accessibilityReduceMotion does not allow, and a component
// that animates through Motion.moving then changes without an animation.

@MainActor
private final class Recorder: ObservableObject {
    @Published var open = false
    var animated: [Bool] = []
}

private struct Drawer: View {
    @ObservedObject var recorder: Recorder
    @ReduceMotion private var reduceMotion

    var body: some View {
        Rectangle()
            .frame(width: recorder.open ? 200 : 40, height: 20)
            .transaction { recorder.animated.append($0.animation != nil) }
            .animation(Motion.moving(Motion.standard, reduced: reduceMotion), value: recorder.open)
    }
}

@MainActor
private func animatesWhenOpened(reduceMotion: Bool?) -> Bool {
    _ = NSApplication.shared
    let recorder = Recorder()
    let window = NSWindow(contentRect: CGRect(x: -6000, y: -6000, width: 300, height: 100),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView: Drawer(recorder: recorder).environment(\.reduceMotionOverride, reduceMotion))
    window.orderFrontRegardless()
    RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    recorder.animated = []
    recorder.open = true
    RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    window.close()
    return recorder.animated.contains(true)
}

@MainActor
@Test func movingAnimationRunsWithoutReduceMotion() {
    #expect(animatesWhenOpened(reduceMotion: false))
}

@MainActor
@Test func reduceMotionOverrideRemovesTheMovingAnimation() {
    #expect(!animatesWhenOpened(reduceMotion: true))
}

@Test func movingHelpersFallBack() {
    #expect(Motion.moving(Motion.standard, reduced: true) == nil)
    #expect(Motion.moving(Motion.standard, reduced: false) != nil)
}
#endif
