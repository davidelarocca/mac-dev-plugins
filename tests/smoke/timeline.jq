# Readable timeline of a Claude Code stream-json transcript: hooks, tool calls, denials,
# messages. Usage: jq -r -f tests/smoke/timeline.jq <transcript>.jsonl
def short: if type=="string" then (.[0:700] | gsub("\n"; "\n      ")) else tostring[0:700] end;
if .type=="system" and .subtype=="hook_response" then
  "HOOK  \(.hook_name) exit=\(.exit_code) \(.outcome)" +
  (if (.stdout // "") != "" then "\n      stdout: \(.stdout|short)" else "" end) +
  (if (.stderr // "") != "" then "\n      stderr: \(.stderr|short)" else "" end)
elif .type=="system" and .subtype=="permission_denied" then "DENY  \(del(.uuid,.session_id)|tostring|.[0:400])"
elif .type=="assistant" then
  (.message.content[] |
    if .type=="text" then "SAY   \(.text|short)"
    elif .type=="tool_use" then "TOOL  \(.name) \(.input | (.file_path // .command // .pattern // tostring) | tostring | .[0:200])"
    else empty end)
elif .type=="user" then
  (.message.content[]? | select(type=="object" and .type=="tool_result") |
    "RES   \(if .is_error then "ERROR " else "" end)\((.content|if type=="array" then map(.text? // "")|join(" ") else . end)|short|.[0:300])")
elif .type=="result" then "END   turns=\(.num_turns) cost=$\(.total_cost_usd) duration=\(.duration_ms/1000|floor)s\n      \(.result|short)"
else empty end
