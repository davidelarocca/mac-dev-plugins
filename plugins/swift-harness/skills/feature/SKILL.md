---
name: feature
description: Discover-plan-implement-verify-record workflow for implementing a feature or a step of an implementation plan in a Swift/SwiftUI macOS app without architectural drift. Use when starting work on a new feature, a roadmap step, or a change that touches more than one module.
---

# Feature workflow

Step-by-step plans keep each session focused. This workflow adds the checks between steps that keep the steps consistent with each other.

## 0. Branch and checkpoint

- Work on a branch named after the feature or step. If on the main branch, create one first.
- Start from a clean tree. If there are uncommitted changes that are not yours to commit, stop and ask.
- With parallel agents or worktrees: several agents may analyze or review in parallel, but one agent integrates. Never let two agents edit the same files.

## 1. Discover

Read only what the change needs:

1. `CLAUDE.md` is already loaded. Follow its links only where relevant.
2. The feature spec or step document the user points to.
3. `docs/COMPONENT_REGISTRY.md` if the change has any UI.
4. The ADRs that touch the modules involved.
5. The actual code of the modules involved, and the callers of anything you plan to change.

Then state in a few lines: what exists already, what the docs say that the code contradicts (if anything), and what you will reuse.

## 2. Plan

- Files to create and modify, grouped by module.
- New dependencies between modules, if any, and why.
- UI decisions per the `ui-change` skill (reuse, extend, create).
- Risks, including anything in protected paths.
- Tests to add or update, and how the result will be verified.

For changes that cross modules or touch protected paths, present the plan and wait for approval. For small single-module changes, state the plan and proceed.

## 3. Implement

- Smallest change that satisfies the step. No drive-by refactors; list them as follow-ups instead.
- UI through the design system only.
- Logic in models or services, with tests next to it. Pure logic (ordering rules, queues, parsing) gets unit tests with Swift Testing first.
- Do not edit `project.pbxproj` by hand.

## 4. Verify

- Run `scripts/verify.sh fast` (the Stop hook runs it too, but run it yourself before claiming done).
- For UI changes: previews in every state, snapshots for shared components, and a look at the running app or a screenshot when the change is visual.
- Report exactly what ran and what did not. "Not verified" is an acceptable answer; a false "passes" is not.

## 5. Record

In the same change:

- `docs/COMPONENT_REGISTRY.md` for any UI component added, extended or retired.
- The feature or step document: mark what is done, note deviations from the plan and why.
- `docs/ARCHITECTURE.md` if a module, dependency or data flow changed.
- An ADR (via the `adr` skill) if you made a decision a future session could otherwise reopen.

Finish with a short summary: what changed, what was verified, follow-ups.
