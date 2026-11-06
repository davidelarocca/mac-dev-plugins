---
paths:
  - "**/*.swift"
---

# Architecture rules for all Swift code

- Respect module boundaries documented in `docs/ARCHITECTURE.md`. A new dependency between modules needs a reason in the change description; a new direction of dependency needs an ADR.
- If `docs/architecture-contracts.json` exists, it lists the dependencies each SwiftPM target may have, and the end-of-turn check enforces it. To make code compile, change the code, not `Package.swift` or the contract; a new dependency needs the user's agreement first.
- One state management pattern: {{STATE_PATTERN}}. Do not introduce a competing one.
- UI updates on the main actor. Heavy work (decoding, metadata, artwork, file scanning) runs off the main actor.
- Prefer dependency injection through initializers or the environment over singletons.
- Before editing a type, find its callers. Keep the change as small as the task allows.
- Optimizations need a measurement first (Instruments or a benchmark test). Fewer lines is not an optimization.
