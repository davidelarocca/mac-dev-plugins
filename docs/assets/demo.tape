# Records docs/assets/demo.gif: the Stop hook catches a failing test, Claude says so,
# then fixes it when asked. Real Claude Code session; costs a few cents.
#
# Setup, from the repository root:
#   1. Build the smoke fixture once: SMOKE_DIR=/tmp/smoke tests/smoke/run.sh guard
#   2. git clone /tmp/smoke/base /tmp/demo-app, then add .claude/swift-harness.json
#      {"format":"swift-format","lint":"swiftlint","verify":{"command":"scripts/verify.sh fast"}}
#      and a .swift-format with 4-space indentation; commit.
#   3. Open claude in /tmp/demo-app once and trust the folder.
#   4. export DEMO_APP=/tmp/demo-app DEMO_SETTINGS=<json file with
#      {"enabledPlugins":{"swift-lsp@claude-plugins-official":true}}> (avoids the LSP prompt)
#   5. vhs docs/assets/demo.tape  (from a plain terminal, not from inside Claude Code)
Output docs/assets/demo.gif
Require claude

Set Shell zsh
Set FontSize 15
Set Width 1280
Set Height 760
Set Padding 24
Set Theme "Catppuccin Mocha"
Set TypingSpeed 35ms
Set Framerate 12
Set PlaybackSpeed 1.0

Hide
Type "cd $DEMO_APP && export PS1='$ ' && clear"
Enter
Type "claude --plugin-dir $PWD/plugins/swift-harness --setting-sources project,local --permission-mode acceptEdits --allowedTools Read Glob Grep Edit Write --disallowedTools Bash --settings $DEMO_SETTINGS"
Enter
# The demo folder must already be trusted (run claude in it once and accept).
Wait+Screen@60s /accept edits on/
Sleep 2s
Show

Type 'Change greeting(for:) so it returns "Hi, <name>!" instead of "Hello, <name>!". Only change Sources/App/Greeting.swift.'
Sleep 500ms
Enter
Wait+Screen@240s /still failing/
Sleep 4s

Type "Yes, update the test too."
Sleep 1s
Enter
Wait+Screen@240s /Update\(Tests/
Sleep 30s

Type "/exit"
Sleep 500ms
Enter
Sleep 3s
Hide
Type "clear"
Enter
Sleep 500ms
Show
Type "scripts/verify.sh fast | tail -3"
Sleep 500ms
Enter
Wait+Screen@120s /verify fast: PASS/
Sleep 5s
