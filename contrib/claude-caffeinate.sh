#!/bin/bash
# Keep the Mac awake while a Claude Code session is working.
# A Claude Code hook; see "Keeping the Mac awake" in the wt README.
#   claude-caffeinate.sh start  -> UserPromptSubmit / SubagentStart / PreToolUse
#   claude-caffeinate.sh stop   -> Stop / SessionEnd
# One caffeinate per session, tied to the claude process with -w so it can
# never outlive Claude Code even if a stop hook is missed.

set -u
action="${1:-}"
input="$(cat)"
sid="$(printf '%s' "$input" | /usr/bin/sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -n "$sid" ] || sid="unknown"

dir="${TMPDIR:-/tmp}/claude-caffeinate"
mkdir -p "$dir"
pidfile="$dir/$sid.pid"

alive() { [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; }

claude_pid() {
  local p=$PPID comm
  while [ "${p:-1}" -gt 1 ]; do
    comm="$(ps -o comm= -p "$p" 2>/dev/null)"
    case "${comm##*/}" in claude|node) echo "$p"; return ;; esac
    p="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
  done
}

case "$action" in
  start)
    alive && exit 0
    cp="$(claude_pid)"
    if [ -n "$cp" ]; then
      nohup /usr/bin/caffeinate -i -m -w "$cp" >/dev/null 2>&1 &
    else
      # Couldn't find claude: cap at 4h rather than risk running forever.
      nohup /usr/bin/caffeinate -i -m -t 14400 >/dev/null 2>&1 &
    fi
    echo $! > "$pidfile"
    ;;
  stop)
    alive && kill "$(cat "$pidfile")" 2>/dev/null
    rm -f "$pidfile"
    ;;
esac
exit 0
