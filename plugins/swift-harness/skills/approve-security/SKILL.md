---
name: approve-security
description: Review the changes to the app's security settings (entitlements, App Transport Security, sandbox and hardened runtime build settings) since the last approval, and approve them as the new baseline. Only the user runs this; Claude must not approve its own changes.
disable-model-invocation: true
---

# Approve security settings

swift-harness records the app's security settings: every `*.entitlements` file, the `NSAppTransportSecurity` dictionary of `Info.plist` files, and the signing and capability build settings in `project.pbxproj` and `.xcconfig` files (hardened runtime and its exceptions, App Sandbox and its file and network access, entitlements file, extra signing flags). The first session records them as they are. From then on, any change fails the end-of-turn check until the user approves it here.

The user asked for this by typing the command. Do not run these scripts at any other time, and never on your own initiative.

## 1. Show the changes

Run from the project root:

```bash
CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA}" "${CLAUDE_PLUGIN_ROOT}/scripts/security.sh" --status
```

If the baseline was recorded automatically and not reviewed, the output lists every setting in it and the ones that weaken protection: explain those as in step 2, since they were accepted without anyone looking. If there is no change and nothing to review, say so and stop.

## 2. Explain each one

For each `+` or `-` line, in one line: what the setting does, and whether it relaxes or tightens security. Be explicit about the ones that weaken protection: removing `com.apple.security.app-sandbox`, hardened runtime exceptions (`com.apple.security.cs.disable-library-validation`, `allow-unsigned-executable-memory`, `allow-jit`, `allow-dyld-environment-variables`, `disable-executable-page-protection`), temporary exceptions (`com.apple.security.temporary-exception.*`), `NSAllowsArbitraryLoads` and other ATS exceptions, `ENABLE_HARDENED_RUNTIME = NO`, `ENABLE_APP_SANDBOX = NO`, `--deep` or `--force` signing flags. Say which change in this session most likely made it, and whether a narrower alternative exists (a specific entitlement instead of a temporary exception, an ATS exception for one domain instead of arbitrary loads).

## 3. Approve

Ask the user whether to approve all the changes shown. Approval is all or nothing: to keep only some, revert the others first and list again. Then pass the `Digest:` value from step 1:

```bash
CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA}" "${CLAUDE_PLUGIN_ROOT}/scripts/security.sh" --approve <digest>
```

If it reports that the settings changed since step 1, list them again and start from step 2.

End with one line: the approved settings are the new baseline, to commit together with the change that needed them.
