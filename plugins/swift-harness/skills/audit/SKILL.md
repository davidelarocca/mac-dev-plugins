---
name: audit
description: Read-only architecture, UI consistency and code health audit of a Swift/SwiftUI macOS project, producing a prioritized report and an incremental migration plan. Use when the user asks for an audit, a codebase review, or a starting point before refactoring.
disable-model-invocation: true
---

# Read-only project audit

Goal: an evidence-based picture of the current state, so the design system and quality gates are introduced in small safe steps. Best run in plan mode.

## Ground rules

- Modify nothing. The only file you write is the final report, after the user approves the plan.
- Every finding cites file paths and line ranges. No evidence, no finding.
- The code is the source of truth. Docs are checked against it, not the other way around.
- Do not invent problems. Do not claim performance issues without a concrete reason in the code (and say "needs measurement" when that is the honest status).
- Areas listed as protected in CLAUDE.md or `.claude/swift-harness.json` are analyzed but get no invasive proposals.

## Method

Keep the main context clean: run Explore subagents in parallel, one per area, each returning findings with file references, not file dumps. Suggested split:

1. UI inventory
2. State, data flow and module boundaries
3. Performance risks and tests
4. Docs versus code, tooling

Then merge, deduplicate and prioritize in the main thread.

## What to investigate

1. **UI inventory.** Every recurring element: pills, toasts, banners, popovers, sheets, buttons and button styles, menus, list rows, headers, badges, ratings, indicators, empty states, toolbars. For each: locations, number of separate implementations, how they differ. Separate "looks similar" from "same behavior and responsibility".
2. **Raw visual values.** Colors, font sizes, paddings, stack spacings, corner radii, animation timings outside a shared definition. Count and locate. If `.swiftlint.yml` from swift-harness exists, run `swiftlint lint --quiet` and use the `ds_*` rule counts.
3. **State and data flow.** Patterns in use (`@Observable`, `ObservableObject`, `@State`, singletons, environment, bindings), inconsistencies, views holding business logic, two sources of truth for the same data.
4. **Module boundaries.** What depends on what. UI touching I/O, persistence or protected areas directly. Circular or surprising dependencies.
5. **Performance risks, with evidence.** Large view bodies, non-lazy containers over big collections, work on the main actor that looks heavy (decoding, metadata, artwork, scanning), frequent state changes that invalidate large view trees.
6. **Tests.** What exists, what critical logic has no tests, whether any UI or snapshot tests exist.
7. **Docs versus code.** Which documents are outdated, contradictory, or describe things that no longer exist. Which decisions are only implicit and deserve an ADR.
8. **Tooling and project structure.** Lint and format configs, Swift version, minimum macOS, targets, local packages, synchronized folders in `project.pbxproj`, build time hot spots if visible.

## Report

Write `docs/audit/YYYY-MM-DD-audit.md` with:

1. Summary: the five findings that matter most, one line each.
2. Current architecture map (modules, dependencies, data flow), as a table or Mermaid diagram.
3. UI component inventory table: element, locations, implementations, recommendation (keep, merge, extract), proposed shared name.
4. Raw visual values summary by category, with the top files.
5. Prioritized risk list: finding, evidence, severity, effort, benefit.
6. Proposed design system structure: tokens, first five or six components, where the package lives.
7. Incremental migration plan: smallest safe steps first, each step with its verification.
8. Docs to update or retire, and proposed ADRs.
9. Open questions for the user.

## After the report

- Seed `docs/COMPONENT_REGISTRY.md` "To consolidate" table from the inventory, if the file exists and the user agrees.
- Do not start the migration in the same session. Suggest a branch per migration step.
