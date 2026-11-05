---
name: adr
description: Record an architecture decision as a short ADR in docs/adr and index it in docs/ARCHITECTURE.md. Use when a significant technical choice is made (state management, module boundaries, persistence, audio pipeline, a new shared pattern) or when the user asks to record or document a decision.
---

# Record an architecture decision

1. Find the next number: list `docs/adr/`, take the highest `NNNN` and add one. Create the folder if missing.
2. Copy the structure of `docs/adr/0000-template.md`, or `${CLAUDE_PLUGIN_ROOT}/skills/setup/templates/docs/adr/0000-template.md` if the project has none.
3. Name the file `docs/adr/NNNN-short-kebab-title.md`. Title in imperative form ("Use a local package for the design system").
4. Fill it from facts in the conversation and the code. Keep it under one page. Alternatives must be real options that were considered, not filler.
5. Status is `Proposed` unless the user confirmed the decision, then `Accepted`.
6. If it replaces an earlier ADR, set the old one to `Superseded by ADR-NNNN`. Never delete old ADRs.
7. Add a row to the decision index in `docs/ARCHITECTURE.md`.
8. If the decision creates a rule Claude must follow every time, propose the one-line rule for `CLAUDE.md` or the matching `.claude/rules/` file. Do not add it without confirmation.
