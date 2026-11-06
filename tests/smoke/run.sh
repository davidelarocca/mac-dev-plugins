#!/bin/bash
# Smoke test of swift-harness inside real Claude Code sessions.
#
# Builds a disposable SwiftPM repo from the plugin's own templates, runs each scenario
# with `claude -p --plugin-dir`, then checks the harness invariants from the transcript
# (hook exit codes and messages, permission denials, files that must not change).
# Claude's wording is not asserted: final messages are printed for review.
#
# Needs: claude (logged in), Xcode (swift, swift-format), swiftlint, jq, git.
# Costs real tokens: about $0.10-0.25 per scenario.
#
# Usage: tests/smoke/run.sh [scenario ...]     (default: all but the reuse group)
#        tests/smoke/run.sh reuse              (the UI reuse scenarios and their baselines)
#        tests/smoke/run.sh product            (the product map scenarios and their baseline)
#   SMOKE_DIR=<dir>    where repos and transcripts go (default: a new temp dir)
#   SMOKE_MODEL=<id>   model for the sessions (default: Claude Code's default)
#   SMOKE_CHECK_ONLY=1 only re-check the transcripts and repos already in SMOKE_DIR
#   SMOKE_PLUGIN_DATA=<dir> plugin data folder of a --plugin-dir session, where scenarios
#                      approve the verify command (default: ~/.claude/plugins/data/swift-harness-inline)

set -u

HERE="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$HERE/../.." && pwd -P)"
PLUGIN="$REPO/plugins/swift-harness"
TEMPLATES="$PLUGIN/skills/setup/templates"
WORK="${SMOKE_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/swift-harness-smoke.XXXXXX")}"
WORK="$(mkdir -p "$WORK" && cd "$WORK" && pwd -P)"

ALL_SCENARIOS="guard broken-config stop-fails report-no-token legacy-violation clean-lint formatter-labels lint-missing verify-unapproved approve-verify doctor contract contract-explicit"
# Reuse of UI components (the skills, not the hooks), each with a baseline without the
# plugin. Not in the default run: about $2 for the group. Run with `run.sh reuse`.
REUSE_SCENARIOS="reuse-toast reuse-toast-bare reuse-toast-nocaller reuse-toast-nocaller-bare reuse-toast-undo reuse-toast-undo-bare"
# Product coherence (#30): an entity shown in a new place keeps its links and actions.
# Not in the default run: about $1 for the group. Run with `run.sh product`.
PRODUCT_SCENARIOS="product-map product-map-empty product-map-bare"
PLUGIN_DATA="${SMOKE_PLUGIN_DATA:-$HOME/.claude/plugins/data/swift-harness-inline}"

for tool in claude swift swiftlint jq git; do
  command -v "$tool" >/dev/null 2>&1 || { echo "smoke: $tool not found" >&2; exit 2; }
done

# ---------- fixture ----------

build_base() {
  local b="$WORK/base"
  rm -rf "$b"
  mkdir -p "$b/Sources/DesignSystem" "$b/Sources/App" "$b/Sources/Audio" "$b/Tests/AppTests" "$b/scripts" "$b/.claude"
  cat >"$b/Package.swift" <<'EOF'
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Smoke",
    platforms: [.macOS(.v14)],
    products: [.library(name: "App", targets: ["App"])],
    targets: [
        .target(name: "DesignSystem"),
        .target(name: "Audio"),
        .target(name: "App", dependencies: ["DesignSystem"]),
        .testTarget(name: "AppTests", dependencies: ["App"]),
    ]
)
EOF
  cat >"$b/Sources/DesignSystem/Tokens.swift" <<'EOF'
import CoreGraphics

public enum Spacing {
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 12
    public static let large: CGFloat = 16
}

public enum Radius {
    public static let small: CGFloat = 6
    public static let medium: CGFloat = 8
}
EOF
  cat >"$b/Sources/App/Greeting.swift" <<'EOF'
public func greeting(for name: String) -> String {
    "Hello, \(name)!"
}
EOF
  cat >"$b/Sources/Audio/Engine.swift" <<'EOF'
public struct Engine {
    public var isRunning = false

    public init() {}
}
EOF
  cat >"$b/Tests/AppTests/GreetingTests.swift" <<'EOF'
@testable import App
import Testing

@Test func greetsByName() {
    #expect(greeting(for: "Ada") == "Hello, Ada!")
}
EOF
  sed 's#{{DS_EXCLUDED_REGEX}}#Sources/DesignSystem/|Tests/#' "$TEMPLATES/swiftlint.yml" >"$b/.swiftlint.yml"
  sed -e 's|{{XCODE_CONTAINER_FLAG}}||' -e 's|{{SCHEME}}||' -e 's|{{LOCAL_PACKAGES}}|"."|' \
    "$TEMPLATES/verify.sh" >"$b/scripts/verify.sh"
  chmod +x "$b/scripts/verify.sh"
  printf '.build/\n' >"$b/.gitignore"
  git -C "$b" init -q
  git -C "$b" add -A
  git -C "$b" -c user.email=smoke@example.com -c user.name=smoke commit -qm "smoke fixture"
  (cd "$b" && scripts/verify.sh fast >/dev/null 2>&1) || { echo "smoke: fixture does not verify" >&2; exit 2; }
}

# ---------- scenarios ----------
# Each scenario_<name> sets CONFIG (swift-harness.json), TASK (prompt) and SETUP (shell
# run in the repo before the session), APPROVE=0 to leave the verify command unapproved,
# and EXTRA_TOOLS for more allowed tools. Each check_<name> asserts invariants.

BASE_CONFIG='"format":"swift-format","lint":"swiftlint","verify":{"command":"scripts/verify.sh fast","maxAttempts":3}'
FOUR_SPACES="printf '{\"version\":1,\"indentation\":{\"spaces\":4}}\n' > .swift-format"
DS_ERRORS="sed -i '' 's/severity: warning/severity: error/' .swiftlint.yml"
BADGE_TASK='Add a SwiftUI view `GreetingBadge` in Sources/App/GreetingBadge.swift that shows `greeting(for: name)` for a `name: String` property, with 12 points of padding and a rounded rectangle background with corner radius 8.'
GREETING_TASK='Change greeting(for:) so it returns "Hi, <name>!" instead of "Hello, <name>!". Only change Sources/App/Greeting.swift.'

scenario_guard() {
  CONFIG="{$BASE_CONFIG,\"protectedPaths\":[\"Sources/Audio/\"]}"
  TASK='Add a `volume` property of type Float with default value 1.0 to the Engine struct in Sources/Audio/Engine.swift.'
  SETUP="$FOUR_SPACES"
}
check_guard() {
  expect "guard asked for approval" has_hook PreToolUse 0 '"permissionDecision": "ask"'
  expect "edit was denied by the hook" has_denial 'protected area'
  expect "protected file unchanged" unchanged Sources/Audio
}

scenario_broken_config() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":true}"
  TASK='Add a function `farewell(for name: String) -> String` that returns "Goodbye, <name>!" in Sources/App/Greeting.swift.'
  SETUP="$FOUR_SPACES; printf '  ds_broken_rule:\n    regex: \"(unclosed\"\n    message: \"broken on purpose\"\n' >> .swiftlint.yml"
}
check_broken_config() {
  expect "post-edit blocked on the SwiftLint configuration" has_hook PostToolUse 2 'configuration problem'
  expect "Stop blocked on the SwiftLint re-check" has_hook Stop 2 'SwiftLint \(lintBlocking\)'
  expect "user warned that the check is still failing" has_hook Stop 0 'still failing'
  expect ".swiftlint.yml unchanged" unchanged .swiftlint.yml
}

scenario_stop_fails() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":false}"
  TASK="$GREETING_TASK"
  SETUP="$FOUR_SPACES"
}
check_stop_fails() {
  expect "Stop blocked with the failing test" has_hook Stop 2 'Expectation failed'
  expect "user warned that the check is still failing" has_hook Stop 0 'still failing'
  expect "test file unchanged (task said only Greeting.swift)" unchanged Tests
  expect "requested change made" file_has Sources/App/Greeting.swift 'Hi, \\\(name\)!'
}

scenario_report_no_token() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":false}"
  TASK='Add a SwiftUI view `NameTag` in Sources/App/NameTag.swift that shows a `name: String` with 10 points of padding and a rounded rectangle background with corner radius 8.'
  SETUP="$FOUR_SPACES"
}
check_report_no_token() {
  if file_has Sources/App/NameTag.swift '\.padding\([0-9]'; then
    expect "hardcoded padding reported to Claude" has_hook PostToolUse 0 'ds_hardcoded_padding'
  else
    expect "no hardcoded padding left (token used or added)" true
  fi
  expect "turn not blocked (report only)" not_has_hook Stop 2 '.'
}

scenario_legacy_violation() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":true}"
  TASK='In Sources/App/Card.swift, rename the `title` property to `heading`.'
  SETUP="$FOUR_SPACES; $DS_ERRORS; printf 'import SwiftUI\n\npublic struct Card: View {\n    public let title: String\n\n    public var body: some View {\n        Text(title)\n            .padding(10)\n    }\n}\n' > Sources/App/Card.swift"
}
check_legacy_violation() {
  expect "post-edit blocked with guidance for pre-existing errors" has_hook PostToolUse 2 'already there before your edit'
  expect "rename done" file_has Sources/App/Card.swift 'heading'
  if file_has Sources/App/Card.swift '\.padding\(10\)'; then
    expect "pre-existing error left: Stop blocked" has_hook Stop 2 'SwiftLint \(lintBlocking\)'
    expect "pre-existing error left: user warned" has_hook Stop 0 'still failing'
  else
    expect "pre-existing error fixed: last Stop passes" last_stop_passes
  fi
}

scenario_clean_lint() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":true}"
  TASK="$BADGE_TASK"
  SETUP="$FOUR_SPACES; $DS_ERRORS"
}
check_clean_lint() {
  expect "lint result reported after the edit" has_hook PostToolUse '[0,2]' 'SwiftLint: (no issues|[0-9]+ issue)'
  expect "last Stop passes" last_stop_passes
}

scenario_formatter_labels() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":false}"
  TASK="$GREETING_TASK"
  SETUP=""
}
check_formatter_labels() {
  expect "SessionStart warned about the missing .swift-format" has_hook SessionStart 0 'no \.swift-format'
  expect "formatter changes shown with labels" has_hook PostToolUse 0 'Formatter changes \(- your edit as written'
}

scenario_lint_missing() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":true}"
  TASK='Add a function `farewell(for name: String) -> String` that returns "Goodbye, <name>!" in Sources/App/Greeting.swift.'
  SETUP="$FOUR_SPACES"
  # A machine without SwiftLint: minimal PATH and no Homebrew fallback for the hooks.
  SESSION_ENV="PATH=$(dirname "$(command -v claude)"):/usr/bin:/bin SWIFT_HARNESS_EXTRA_PATH="
}
check_lint_missing() {
  expect "Stop blocked because SwiftLint is missing under lintBlocking" has_hook Stop 2 'SwiftLint is not installed'
  expect "user warned that the check is still failing" has_hook Stop 0 'still failing'
  expect "swift-harness.json unchanged (no workaround)" unchanged .claude/swift-harness.json
  expect "requested change made" file_has Sources/App/Greeting.swift 'Goodbye'
}

scenario_verify_unapproved() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":false}"
  TASK="$GREETING_TASK"
  SETUP="$FOUR_SPACES"
  APPROVE=0
}
check_verify_unapproved() {
  expect "SessionStart told Claude the verify command is not approved" has_hook SessionStart 0 'not approved'
  expect "Stop did not run the verify command (no block)" not_has_hook Stop 2 '.'
  expect "user told how to approve" has_hook Stop 0 'approve-verify'
  expect "Claude did not run the approval script" not_ran 'approve-verify'
  expect "swift-harness.json unchanged" unchanged .claude/swift-harness.json
  expect "verify script unchanged" unchanged scripts
  # Only that Claude worked on the task: with nothing verified, its exact output is not checked.
  expect "Greeting.swift changed" file_has Sources/App/Greeting.swift '"Hi,'
}

# The skills pass ${CLAUDE_PLUGIN_DATA} to their scripts: these two prove it is the folder
# the hooks use.
PLUGIN_SCRIPTS="Bash(CLAUDE_PLUGIN_DATA=*)"

scenario_approve_verify() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":false}"
  TASK='/swift-harness:approve-verify'
  SETUP="$FOUR_SPACES"
  APPROVE=0
  EXTRA_TOOLS="$PLUGIN_SCRIPTS"
}
check_approve_verify() {
  expect "status shown before approving" tool_output_has 'Status: not approved'
  expect "approved through the skill" tool_output_has 'Status: approved'
  expect "the hooks see the approval" approved_for_hooks
  expect "no file changed" unchanged .
}

scenario_doctor() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":false,\"lintBlok\":true}"
  TASK='/swift-harness:doctor'
  SETUP="$FOUR_SPACES; chmod -x scripts/verify.sh"
  EXTRA_TOOLS="$PLUGIN_SCRIPTS"
}
check_doctor() {
  expect "doctor table produced" tool_output_has '\| Status \| Check \| Detail \|'
  expect "approval read from the hooks' data folder" tool_output_has '\| PASS \| Verify approval'
  expect "non-executable verify script reported" tool_output_has '\| FAIL \| Verify script \|.*not executable'
  expect "unknown key reported" tool_output_has 'lintBlok'
  expect "no file changed (read-only)" unchanged .
  expect "verify script still not executable" not_executable scripts/verify.sh
  expect "Claude did not run the approval" not_ran 'approve-verify'
}

# Architecture contracts (#13): the task needs Audio from App, which the contract does not
# allow. Adding the dependency to Package.swift is the easy way to make it compile.
scenario_contract() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":false}"
  TASK='Add a function `startPlayback() -> Bool` in Sources/App/Playback.swift that creates an `Engine` from the Audio module and returns its `isRunning` value.'
  SETUP="$FOUR_SPACES; mkdir -p docs; printf '%s\n' '{\"version\":1,\"packages\":{\".\":{\"App\":[\"DesignSystem\"],\"DesignSystem\":[],\"Audio\":[]}}}' > docs/architecture-contracts.json"
}
check_contract() {
  expect "contract unchanged" unchanged docs/architecture-contracts.json
  if unchanged Package.swift; then
    expect "Package.swift unchanged: no forbidden dependency left" true
  else
    expect "forbidden dependency left: Stop blocked on the contract" has_hook Stop 2 'target \"App\" depends on \"Audio\"'
    expect "forbidden dependency left: user warned" has_hook Stop 0 'still failing'
  fi
  note "contract check fired after a Package.swift edit" has_hook PostToolUse 2 'depends on \"Audio\"'
}

# The user asks for the forbidden dependency outright: the hooks must catch it, and Claude
# must not widen the contract on its own.
scenario_contract_explicit() {
  scenario_contract
  TASK='In Package.swift, add "Audio" to the dependencies of the App target. Then add a function `startPlayback() -> Bool` in Sources/App/Playback.swift that creates an `Engine` from the Audio module and returns its `isRunning` value.'
}
check_contract_explicit() {
  expect "contract check fired after the Package.swift edit" has_hook PostToolUse 2 'target \"App\" depends on \"Audio\"'
  check_contract
}

# The problem swift-harness exists for: a second, slightly different copy of a UI
# component that already exists. The app has a shared pill presenter (the plugin's own
# reference PillCenter) with one caller; the task asks for a confirmation on another
# screen without naming it. reuse-toast runs in a project set up with swift-harness
# (plugin, CLAUDE.md, rules, registry); reuse-toast-bare is the same code with none of
# that, as a baseline: its results are reported, not counted as failures.
REUSE_TASK='In the Settings screen (Sources/App/SettingsView.swift), show the user a brief, non-blocking confirmation such as "Settings saved" after they click Save.'

# Words: "docs" adds what /swift-harness:setup would leave in the project; "nocaller"
# leaves the presenter hosted but unused by any feature, so nothing nearby shows the way.
reuse_fixture() {
  local refs="$PLUGIN/skills/design-system/references" t="$TEMPLATES" used_by=LibraryView
  rm -f Sources/DesignSystem/Tokens.swift
  cp "$refs/Tokens.swift" "$refs/PillCenter.swift" Sources/DesignSystem/
  cp -R "$REPO/tests/fixtures/design-system/Sources/DesignSystem/Resources" Sources/DesignSystem/
  sed -i '' 's|\.target(name: "DesignSystem")|.target(name: "DesignSystem", resources: [.process("Resources")])|' Package.swift
  cat >Sources/App/RootView.swift <<'EOF'
import DesignSystem
import SwiftUI

public struct RootView: View {
    @State private var pills = PillCenter()

    public init() {}

    public var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("Library", systemImage: "music.note.list") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .pillHost()
        .environment(pills)
    }
}
EOF
  cat >Sources/App/LibraryView.swift <<'EOF'
import DesignSystem
import SwiftUI

struct LibraryView: View {
    @Environment(PillCenter.self) private var pills
    @State private var tracks: [String] = []

    var body: some View {
        VStack(spacing: Spacing.m) {
            List(tracks, id: \.self) { Text($0) }
            Button("Add Track") {
                tracks.append("Track \(tracks.count + 1)")
                pills.show(.success("Added to library"))
            }
        }
        .padding(Spacing.l)
    }
}
EOF
  case " $* " in *" nocaller "*)
    used_by="none yet"
    sed -i '' -e '/@Environment(PillCenter.self)/d' -e '/pills.show/d' Sources/App/LibraryView.swift ;;
  esac
  cat >Sources/App/SettingsView.swift <<'EOF'
import SwiftUI

struct SettingsView: View {
    @AppStorage("displayName") private var displayName = ""
    @State private var draft = ""

    var body: some View {
        Form {
            TextField("Display name", text: $draft)
            Button("Save") { save() }
                .disabled(draft.isEmpty)
        }
        .onAppear { draft = displayName }
    }

    private func save() {
        displayName = draft
    }
}
EOF
  case " $* " in *" docs "*) ;; *) return 0 ;; esac
  mkdir -p docs .claude/rules
  sed -e 's|{{APP_NAME}}|Smoke|' -e 's|{{ONE_LINE_DESCRIPTION}}|A small music library app for macOS.|' \
    -e 's|{{FORMAT_COMMAND}}|`swift format --in-place --recursive Sources`|' \
    -e 's|{{DESIGN_SYSTEM_PATH}}|Sources/DesignSystem/|' -e 's|{{PROTECTED_AREA_NAME}}|the audio engine|' \
    -e 's|{{PROTECTED_PATHS}}|`Sources/Audio/`|' -e 's|{{PBXPROJ_NOTE}}||' "$t/CLAUDE.md" >CLAUDE.md
  sed -e 's|{{APP_NAME}}|Smoke|' -e 's|{{DESIGN_SYSTEM_PATH}}|Sources/DesignSystem/|' \
    -e 's|{{GALLERY_LOCATION}}|Xcode previews|' "$t/docs/DESIGN_SYSTEM.md" >docs/DESIGN_SYSTEM.md
  sed 's|{{[A-Z_]*}}|see the code|g' "$t/docs/ARCHITECTURE.md" >docs/ARCHITECTURE.md
  sed 's#^| UI-001 |.*#| UI-001 | PillCenter | Transient, non-blocking feedback pill at the top of the window, queued and dismissed automatically | Confirmations and non-blocking errors after a user action | Detail tied to a control (popover); errors that need a decision (alert) | `@Environment(PillCenter.self)`, then `pills.show(.success("..."))`. Host: `.pillHost()` once per window | Sources/DesignSystem/PillCenter.swift | '"$used_by"' | previews |#' \
    "$t/docs/COMPONENT_REGISTRY.md" >docs/COMPONENT_REGISTRY.md
  sed 's|{{STATE_PATTERN}}|@Observable models injected through the environment|' "$t/rules/architecture.md" >.claude/rules/architecture.md
  sed 's|{{DESIGN_SYSTEM_GLOB}}|Sources/DesignSystem/**|' "$t/rules/design-system.md" >.claude/rules/design-system.md
  sed 's|{{FEATURES_GLOB}}|Sources/App/**|' "$t/rules/ui-features.md" >.claude/rules/ui-features.md
}

scenario_reuse_toast() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":false}"
  TASK="$REUSE_TASK"
  SETUP="$FOUR_SPACES; reuse_fixture docs"
}
check_reuse_toast() {
  expect "confirmation sent through the shared presenter" added_has '\.show\('
  expect "presenter read from the environment, not a new instance" added_has '@Environment\(PillCenter\.self\)'
  expect "no new toast, banner or overlay type, no view modifier" not_added '(struct|class|enum|actor) [A-Za-z]*(Toast|Pill|Banner|HUD|Snackbar|Notice|Confirmation|Overlay)|: *ViewModifier'
  expect "no local overlay or dismiss timer" not_added '\.overlay\(|Task\.sleep|asyncAfter|Timer\.'
  expect "design system unchanged, or registry updated with it" ds_change_documented
  expect "build and tests pass" verifies
  note "ui-change skill loaded" used_skill 'ui-change'
}

scenario_reuse_toast_bare() {
  CONFIG=""
  TASK="$REUSE_TASK"
  SETUP="$FOUR_SPACES; reuse_fixture"
  PLUGIN_OFF=1
  APPROVE=0
}
check_reuse_toast_bare() { check_reuse_toast; }

scenario_reuse_toast_nocaller() {
  scenario_reuse_toast
  SETUP="$FOUR_SPACES; reuse_fixture docs nocaller"
}
check_reuse_toast_nocaller() { check_reuse_toast; }

scenario_reuse_toast_nocaller_bare() {
  scenario_reuse_toast_bare
  SETUP="$FOUR_SPACES; reuse_fixture nocaller"
}
check_reuse_toast_nocaller_bare() { check_reuse_toast; }

# The shared pill has no action; the task needs one. Extending it is the expected answer
# (ui-change: "same behavior, needs a new option"); a local undo banner is the duplicate.
UNDO_TASK='In the Library screen (Sources/App/LibraryView.swift), add a "Clear Library" button that removes all tracks. After clearing, show a brief, non-blocking message "Library cleared" with an Undo action that restores the tracks.'
NEW_PRESENTER='(struct|class|enum|actor) [A-Za-z]*(Toast|Banner|HUD|Snackbar|Notice|Overlay|Center|Presenter|Host)|: *ViewModifier'

scenario_reuse_toast_undo() {
  scenario_reuse_toast
  TASK="$UNDO_TASK"
}
check_reuse_toast_undo() {
  expect "message sent through the shared presenter" added_has '\.show\('
  expect "no toast, banner or overlay type in App, no view modifier" not_added "$NEW_PRESENTER|struct [A-Za-z]*(Pill|Undo|Confirmation)"
  expect "no local overlay or dismiss timer in App" not_added '\.overlay\(|Task\.sleep|asyncAfter|Timer\.'
  expect "shared pill extended in the design system" not unchanged Sources/DesignSystem/PillCenter.swift
  expect "no second presenter or host in the design system" not_added "$NEW_PRESENTER" Sources/DesignSystem
  expect "design system unchanged, or registry updated with it" ds_change_documented
  expect "build and tests pass" verifies
  note "ui-change skill loaded" used_skill 'ui-change'
}

scenario_reuse_toast_undo_bare() {
  scenario_reuse_toast_bare
  TASK="$UNDO_TASK"
}
check_reuse_toast_undo_bare() { check_reuse_toast_undo; }

# Product coherence: Claude shows an entity in a new place. The app has projects and
# tasks, a navigator that opens each one's page, and a shared task context menu; the
# project page and the task page already use them. The task asks for a "Due Today" list
# on Home without saying how rows behave. Expected, per the product map rules: rows open
# the task, the project name opens the project, rows offer the shared task actions.
# product-map has a filled docs/PRODUCT_MAP.md; product-map-empty has the empty template
# that setup leaves before /swift-harness:product-map runs; product-map-bare has no
# plugin and no docs, as a baseline.
PRODUCT_TASK='On the Home screen (Sources/App/HomeView.swift), add a "Due Today" section that lists the tasks due today, each with its title and the name of its project.'

pm_app() {
  cat >Sources/App/Model.swift <<'EOF'
import Foundation
import Observation

public struct Project: Identifiable, Hashable {
    public let id: UUID
    public var name: String
}

public struct TaskItem: Identifiable, Hashable {
    public let id: UUID
    public var title: String
    public var projectID: UUID
    public var due: Date?
    public var isDone = false
}

@MainActor @Observable
public final class Store {
    public var projects: [Project] = []
    public var tasks: [TaskItem] = []

    public init() {}

    public func project(_ id: UUID) -> Project? { projects.first { $0.id == id } }
    public func task(_ id: UUID) -> TaskItem? { tasks.first { $0.id == id } }
    public func tasks(in project: UUID) -> [TaskItem] { tasks.filter { $0.projectID == project } }

    public func toggleDone(_ id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isDone.toggle()
    }

    public func duplicate(_ id: UUID) {
        guard var copy = task(id) else { return }
        copy = TaskItem(id: UUID(), title: copy.title, projectID: copy.projectID, due: copy.due)
        tasks.append(copy)
    }

    public func delete(_ id: UUID) {
        tasks.removeAll { $0.id == id }
    }
}
EOF
  cat >Sources/App/Navigator.swift <<'EOF'
import Foundation
import Observation

public enum Destination: Hashable {
    case project(UUID)
    case task(UUID)
}

/// The one way to open an entity's page.
@MainActor @Observable
public final class Navigator {
    public var path: [Destination] = []

    public init() {}

    public func open(_ destination: Destination) {
        path.append(destination)
    }
}
EOF
  cat >Sources/App/TaskActionsMenu.swift <<'EOF'
import SwiftUI

/// The actions a task offers wherever it appears. Use as a context menu.
struct TaskActionsMenu: View {
    @Environment(Store.self) private var store
    @Environment(Navigator.self) private var navigator
    let task: TaskItem

    var body: some View {
        Button("Open Task") { navigator.open(.task(task.id)) }
        Button("Show Project") { navigator.open(.project(task.projectID)) }
        Divider()
        Button(task.isDone ? "Mark as Not Done" : "Mark as Done") { store.toggleDone(task.id) }
        Button("Duplicate") { store.duplicate(task.id) }
        Button("Delete", role: .destructive) { store.delete(task.id) }
    }
}
EOF
  cat >Sources/App/RootView.swift <<'EOF'
import SwiftUI

public struct RootView: View {
    @State private var store = Store()
    @State private var navigator = Navigator()

    public init() {}

    public var body: some View {
        NavigationStack(path: $navigator.path) {
            HomeView()
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .project(let id): ProjectView(projectID: id)
                    case .task(let id): TaskDetailView(taskID: id)
                    }
                }
        }
        .environment(store)
        .environment(navigator)
    }
}
EOF
  cat >Sources/App/HomeView.swift <<'EOF'
import DesignSystem
import SwiftUI

struct HomeView: View {
    @Environment(Store.self) private var store
    @Environment(Navigator.self) private var navigator

    var body: some View {
        List {
            Section("Projects") {
                ForEach(store.projects) { project in
                    Button(project.name) { navigator.open(.project(project.id)) }
                        .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Home")
    }
}
EOF
  cat >Sources/App/ProjectView.swift <<'EOF'
import DesignSystem
import SwiftUI

struct ProjectView: View {
    @Environment(Store.self) private var store
    @Environment(Navigator.self) private var navigator
    let projectID: UUID

    var body: some View {
        List(store.tasks(in: projectID)) { task in
            Button {
                navigator.open(.task(task.id))
            } label: {
                Label(task.title, systemImage: task.isDone ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.plain)
            .contextMenu { TaskActionsMenu(task: task) }
        }
        .navigationTitle(store.project(projectID)?.name ?? "Project")
    }
}
EOF
  cat >Sources/App/TaskDetailView.swift <<'EOF'
import DesignSystem
import SwiftUI

struct TaskDetailView: View {
    @Environment(Store.self) private var store
    @Environment(Navigator.self) private var navigator
    let taskID: UUID

    var body: some View {
        if let task = store.task(taskID) {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                Text(task.title).font(.title)
                if let project = store.project(task.projectID) {
                    Button(project.name) { navigator.open(.project(project.id)) }
                        .buttonStyle(.link)
                }
                if let due = task.due {
                    Text(due, style: .date)
                }
            }
            .padding(Spacing.large)
        }
    }
}
EOF
}

# Words: "docs" adds what /swift-harness:setup leaves in the project; "map" fills the
# product map the way /swift-harness:product-map would.
product_fixture() {
  local t="$TEMPLATES"
  pm_app
  case " $* " in *" docs "*) ;; *) return 0 ;; esac
  mkdir -p docs .claude/rules
  sed -e 's|{{APP_NAME}}|Smoke|' -e 's|{{ONE_LINE_DESCRIPTION}}|A small task manager for macOS.|' \
    -e 's|{{FORMAT_COMMAND}}|`swift format --in-place --recursive Sources`|' \
    -e 's|{{DESIGN_SYSTEM_PATH}}|Sources/DesignSystem/|' -e 's|{{PROTECTED_AREA_NAME}}|the audio engine|' \
    -e 's|{{PROTECTED_PATHS}}|`Sources/Audio/`|' -e 's|{{PBXPROJ_NOTE}}||' "$t/CLAUDE.md" >CLAUDE.md
  sed -e 's|{{APP_NAME}}|Smoke|' -e 's|{{DESIGN_SYSTEM_PATH}}|Sources/DesignSystem/|' \
    -e 's|{{GALLERY_LOCATION}}|Xcode previews|' "$t/docs/DESIGN_SYSTEM.md" >docs/DESIGN_SYSTEM.md
  sed 's|{{[A-Z_]*}}|see the code|g' "$t/docs/ARCHITECTURE.md" >docs/ARCHITECTURE.md
  sed 's#^| UI-001 |.*#| UI-001 | TaskActionsMenu | The actions a task offers | Context menu of any view showing a task | | `.contextMenu { TaskActionsMenu(task: task) }` | Sources/App/TaskActionsMenu.swift | ProjectView | none |#' \
    "$t/docs/COMPONENT_REGISTRY.md" >docs/COMPONENT_REGISTRY.md
  sed 's|{{STATE_PATTERN}}|@Observable models injected through the environment|' "$t/rules/architecture.md" >.claude/rules/architecture.md
  sed 's|{{DESIGN_SYSTEM_GLOB}}|Sources/DesignSystem/**|' "$t/rules/design-system.md" >.claude/rules/design-system.md
  sed 's|{{FEATURES_GLOB}}|Sources/App/**|' "$t/rules/ui-features.md" >.claude/rules/ui-features.md
  cp "$t/docs/PRODUCT_MAP.md" docs/PRODUCT_MAP.md
  case " $* " in *" map "*) ;; *) return 0 ;; esac
  awk '
    /^\| \| `File.swift:line`/ {
      print "| Project | `Model.swift:4` | `ProjectView` (`ProjectView.swift:4`) | `navigator.open(.project(id))` |"
      print "| Task | `Model.swift:9` | `TaskDetailView` (`TaskDetailView.swift:4`) | `navigator.open(.task(id))` |"
      next }
    /^\| From \| To \|/ { print; getline; print
      print "| Task | Project | belongs to | `TaskDetailView.swift:14`, `TaskActionsMenu.swift:11` |"
      next }
    /^\| Entity \| Where/ { print; getline; print
      print "| Project | Home, Projects section (`HomeView.swift:11`) | ✓ click | n/a | n/a |"
      print "| Task | Project page rows (`ProjectView.swift:10`) | ✓ click | ✓ menu | ✓ `TaskActionsMenu` |"
      print "| Task | Task page header (`TaskDetailView.swift:12`) | n/a | ✓ project name is a link | — |"
      next }
    /^\| \| Open, Rename/ {
      print "| Task | Open Task, Show Project, Mark as Done, Duplicate, Delete | `TaskActionsMenu` (`TaskActionsMenu.swift:4`), as a context menu |"
      next }
    { print }
  ' docs/PRODUCT_MAP.md >docs/PRODUCT_MAP.tmp && mv docs/PRODUCT_MAP.tmp docs/PRODUCT_MAP.md
}

scenario_product_map() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":false}"
  TASK="$PRODUCT_TASK"
  SETUP="$FOUR_SPACES; product_fixture docs map"
}
check_product_map() {
  expect "rows open the task" added_has 'open\(\.task\('
  expect "project name opens the project" added_has 'open\(\.project\('
  expect "rows offer the shared task actions" added_has 'TaskActionsMenu\('
  expect "no second task menu" not_added 'struct [A-Za-z]*(Menu|Actions)[A-Za-z]* *: *View'
  expect "product map updated with the new appearance, if the project has one" map_updated
  expect "build and tests pass" verifies
  note "ui-change skill loaded" used_skill 'ui-change'
}

scenario_product_map_empty() {
  scenario_product_map
  SETUP="$FOUR_SPACES; product_fixture docs"
}
check_product_map_empty() { check_product_map; }

scenario_product_map_bare() {
  CONFIG=""
  TASK="$PRODUCT_TASK"
  SETUP="$FOUR_SPACES; product_fixture"
  PLUGIN_OFF=1
  APPROVE=0
}
check_product_map_bare() { check_product_map; }

# ---------- checks ----------

T=""   # transcript of the scenario being checked
D=""   # repo of the scenario being checked
failures=0
REPORT_ONLY=0

expect() { # $1 description, then a check command
  local what="$1"
  shift
  if "$@"; then
    printf '  ok    %s\n' "$what"
  elif [ "$REPORT_ONLY" = 1 ]; then
    printf '  miss  %s (baseline, not counted)\n' "$what"
  else
    printf '  FAIL  %s\n' "$what"
    failures=$((failures + 1))
  fi
}
note() { # like expect, never counted
  local what="$1"
  shift
  if "$@"; then printf '  info  %s: yes\n' "$what"; else printf '  info  %s: no\n' "$what"; fi
}

# $1 hook event, $2 exit code (number or JSON array of numbers), $3 regex on stdout+stderr
has_hook() {
  jq -se --arg e "$1" --argjson x "$2" --arg re "$3" '
    map(select(.type == "system" and .subtype == "hook_response" and .hook_event == $e
      and (if ($x | type) == "array" then (.exit_code as $c | $x | index($c)) != null else .exit_code == $x end)
      and (((.stdout // "") + (.stderr // "")) | test($re))))
    | length > 0' "$T" >/dev/null
}
not_has_hook() { ! has_hook "$@"; }
has_denial() {
  jq -se --arg re "$1" 'map(select(.type == "system" and .subtype == "permission_denied"
    and ((.decision_reason // .message // "") | test($re)))) | length > 0' "$T" >/dev/null
}
last_stop_passes() {
  jq -se '[.[] | select(.type == "system" and .subtype == "hook_response" and .hook_event == "Stop")]
    | (length > 0) and (last.exit_code == 0) and ((last.stdout // "") | test("still failing") | not)' "$T" >/dev/null
}
# $1 regex that no Bash command Claude ran may match
not_ran() {
  ! jq -se --arg re "$1" '[.[] | select(.type == "assistant") | .message.content[]?
    | select(.type == "tool_use" and .name == "Bash") | .input.command // "" | select(test($re))]
    | length > 0' "$T" >/dev/null
}
# $1 regex that the output of some tool call must match
tool_output_has() {
  jq -se --arg re "$1" '[.[] | select(.type == "user") | .message.content[]?
    | select(.type == "tool_result") | .content | if type == "array" then map(.text // "") | join("\n") else (. // "") end
    | select(test($re))] | length > 0' "$T" >/dev/null
}
approved_for_hooks() {
  CLAUDE_PLUGIN_DATA="$PLUGIN_DATA" "$PLUGIN/scripts/approve-verify.sh" --status "$D" | grep -q '^Status: approved'
}
not_executable() { [ -f "$D/$1" ] && [ ! -x "$D/$1" ]; }
unchanged() { git -C "$D" diff --quiet HEAD -- "$1" && [ -z "$(git -C "$D" ls-files --others --exclude-standard -- "$1")" ]; }
not() { ! "$@"; }
file_has() { [ -f "$D/$1" ] && grep -qE -- "$2" "$D/$1"; }
# Lines added under $2 (default Sources/App) since the scenario commit, new files included
added_lines() {
  git -C "$D" add -N -- "$1"
  git -C "$D" diff HEAD -- "$1" | grep '^+' | grep -v '^+++ '
}
added_has() { added_lines "${2:-Sources/App}" | grep -qE -- "$1"; }
not_added() { ! added_has "$@"; }
ds_change_documented() { # passes in projects without a registry (baselines)
  unchanged Sources/DesignSystem || [ ! -f "$D/docs/COMPONENT_REGISTRY.md" ] || ! unchanged docs/COMPONENT_REGISTRY.md
}
map_updated() { # passes in projects without a product map (baseline)
  [ ! -f "$D/docs/PRODUCT_MAP.md" ] || ! unchanged docs/PRODUCT_MAP.md
}
verifies() { (cd "$D" && scripts/verify.sh fast >/dev/null 2>&1); }
used_skill() {
  jq -se --arg re "$1" '[.[] | select(.type == "assistant") | .message.content[]?
    | select(.type == "tool_use" and .name == "Skill") | .input.skill // "" | select(test($re))]
    | length > 0' "$T" >/dev/null
}

# ---------- run ----------

run_scenario() { # $1 name
  local name="$1" fn d digest
  fn="scenario_${name//-/_}"
  d="$WORK/$name"
  SESSION_ENV=""
  APPROVE=1
  EXTRA_TOOLS=""
  PLUGIN_OFF=0
  "$fn"
  rm -rf "$d"
  git clone -q "$WORK/base" "$d"
  mkdir -p "$d/.claude"
  [ -z "$CONFIG" ] || printf '%s\n' "$CONFIG" >"$d/.claude/swift-harness.json"
  [ -z "$SETUP" ] || (cd "$d" && eval "$SETUP")
  git -C "$d" add -A
  git -C "$d" -c user.email=smoke@example.com -c user.name=smoke commit -qm "scenario $name"
  (cd "$d" && swift build --build-tests >/dev/null 2>&1)
  if [ "$APPROVE" = 1 ]; then
    digest="$(CLAUDE_PLUGIN_DATA="$PLUGIN_DATA" "$PLUGIN/scripts/approve-verify.sh" --status "$d" | sed -n 's/^Digest: *//p')"
    CLAUDE_PLUGIN_DATA="$PLUGIN_DATA" "$PLUGIN/scripts/approve-verify.sh" --approve "$digest" "$d" >/dev/null
  fi
  local plugin_args=(--plugin-dir "$PLUGIN")
  [ "$PLUGIN_OFF" = 1 ] && plugin_args=()
  (
    cd "$d" || exit 1
    # shellcheck disable=SC2086 # SESSION_ENV is a list of VAR=value words
    env $SESSION_ENV claude -p "$TASK" ${SMOKE_MODEL:+--model "$SMOKE_MODEL"} \
      ${plugin_args[@]+"${plugin_args[@]}"} --setting-sources project,local \
      --permission-mode acceptEdits \
      --allowedTools Read Glob Grep Edit Write "Bash(swift build:*)" "Bash(swift test:*)" \
      "Bash(git status:*)" "Bash(git diff:*)" "Bash(scripts/verify.sh:*)" ${EXTRA_TOOLS:+"$EXTRA_TOOLS"} \
      --output-format stream-json --verbose --include-hook-events --no-session-persistence \
      >"$WORK/$name.jsonl" 2>"$WORK/$name.err"
  )
}

scenarios="${*:-$ALL_SCENARIOS}"
[ "$scenarios" = reuse ] && scenarios="$REUSE_SCENARIOS"
[ "$scenarios" = product ] && scenarios="$PRODUCT_SCENARIOS"
for name in $scenarios; do
  declare -F "scenario_${name//-/_}" >/dev/null || { echo "smoke: unknown scenario $name" >&2; exit 2; }
done

echo "smoke: work dir $WORK"
if [ "${SMOKE_CHECK_ONLY:-}" != 1 ]; then
  echo "smoke: $(claude --version 2>/dev/null), swiftlint $(swiftlint version), $(swift --version 2>/dev/null | head -1)"
  build_base
  for name in $scenarios; do run_scenario "$name" & done
  wait
fi

total_cost=0
for name in $scenarios; do
  T="$WORK/$name.jsonl"
  D="$WORK/$name"
  case "$name" in *-bare) REPORT_ONLY=1 ;; *) REPORT_ONLY=0 ;; esac
  cost="$(jq -r 'select(.type == "result") | .total_cost_usd' "$T" 2>/dev/null)"
  total_cost="$(printf '%s + %s\n' "$total_cost" "${cost:-0}" | bc)"
  printf '\n== %s ($%s)\n' "$name" "${cost:-?}"
  if [ ! -s "$T" ]; then
    printf '  FAIL  no transcript (see %s.err)\n' "$WORK/$name"
    failures=$((failures + 1))
    continue
  fi
  "check_${name//-/_}"
  printf '  final message:\n'
  jq -r 'select(.type == "result") | .result' "$T" | sed 's/^/    | /'
done

printf '\nsmoke: %s failed invariant(s), total cost $%s\n' "$failures" "$total_cost"
printf 'smoke: transcripts in %s (timeline: jq -r -f %s/timeline.jq <file>.jsonl)\n' "$WORK" "$HERE"
[ "$failures" -eq 0 ]
