---
name: doctor
description: Read-only diagnosis of the swift-harness setup in this project - tools, configuration, verify script, platforms and approval, security settings baseline, formatter, project structure and the last verification - with one fix per problem. Changes no file.
disable-model-invocation: true
---

# Diagnose the swift-harness setup

Run from the project root:

```bash
CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA}" "${CLAUDE_PLUGIN_ROOT}/scripts/doctor.sh"
```

Show the table to the user exactly as printed. The script exits 1 when a check fails; that is the expected result for a broken setup, not an error to retry.

Then, in at most five lines, list the fixes in this order: FAIL rows first, then WARN rows. Quote each fix as the table gives it. If there are none, say the setup is complete.

This skill is read-only:

- Do not edit any file, install any tool or change any setting, even if the fix is obvious. Offer to do it, and wait for the user.
- Never run `/swift-harness:approve-verify` or its script. Only the user approves the verify command.
- Do not run `scripts/verify.sh` or the verify command to "check" it. The table reports its configuration without running it.
