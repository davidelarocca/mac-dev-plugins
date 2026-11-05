import Observation
import SwiftUI

// MARK: - Model

public struct Pill: Identifiable, Equatable, Sendable {
    public enum Kind: Sendable {
        case info, success, warning, error
    }

    public let id = UUID()
    public var kind: Kind
    public var message: String
    public var systemImage: String?
    public var duration: Duration

    public init(_ kind: Kind, _ message: String, systemImage: String? = nil, duration: Duration = .seconds(2.5)) {
        self.kind = kind
        self.message = message
        self.systemImage = systemImage
        self.duration = duration
    }

    public static func info(_ message: String) -> Pill { Pill(.info, message, systemImage: "info.circle") }
    public static func success(_ message: String) -> Pill { Pill(.success, message, systemImage: "checkmark.circle") }
    public static func warning(_ message: String) -> Pill { Pill(.warning, message, systemImage: "exclamationmark.triangle") }
    public static func error(_ message: String) -> Pill { Pill(.error, message, systemImage: "xmark.octagon", duration: .seconds(4)) }
}

// MARK: - Presenter (behavior)

@MainActor
@Observable
public final class PillCenter {
    public private(set) var current: Pill?
    @ObservationIgnored private var queue: [Pill] = []
    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    public init() {}

    /// The only API features use: `pills.show(.success("Added to library"))`.
    public func show(_ pill: Pill) {
        if current == nil {
            present(pill)
        } else if pill.message != current?.message, !queue.contains(where: { $0.message == pill.message }) {
            queue.append(pill)
        }
    }

    public func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        current = nil
        if !queue.isEmpty {
            present(queue.removeFirst())
        }
    }

    private func present(_ pill: Pill) {
        current = pill
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: pill.duration)
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }
}

// MARK: - View (presentation)

struct PillView: View {
    let pill: Pill

    var body: some View {
        Label {
            Text(pill.message)
                .font(Typography.pillLabel)
        } icon: {
            if let systemImage = pill.systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(.regularMaterial, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }

    private var tint: Color {
        switch pill.kind {
        case .info: .secondary
        case .success: Color.DS.success
        case .warning: Color.DS.warning
        case .error: Color.DS.danger
        }
    }
}

// MARK: - Host (one per window, at the root)

struct PillHost: ViewModifier {
    @Environment(PillCenter.self) private var center
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let pill = center.current {
                    PillView(pill: pill)
                        .padding(.top, Spacing.m)
                        .onTapGesture { center.dismiss() }
                        .transition(
                            reduceMotion
                                ? AnyTransition.opacity
                                : AnyTransition.move(edge: .top).combined(with: .opacity)
                        )
                        .id(pill.id)
                }
            }
            .animation(Motion.standard, value: center.current?.id)
    }
}

public extension View {
    /// Apply once to the root content of each window, inside `.environment(pillCenter)`:
    /// `RootView().pillHost().environment(pillCenter)`
    func pillHost() -> some View {
        modifier(PillHost())
    }
}
