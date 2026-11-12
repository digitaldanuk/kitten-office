#!/bin/bash
# Kitten Office hook: tells the office what this Claude Code session is doing.
# It never slows Claude down or blocks it: it always exits 0 and sends in the background.
CONF="$HOME/.claude/kitten-office.env"
[ -f "$CONF" ] || exit 0
. "$CONF"   # KITTEN_URL, KITTEN_ANON_KEY, KITTEN_WRITER_KEY, KITTEN_MACHINE
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
field() { jq -r "$1 // \"\"" <<<"$input"; }
event=$(field .hook_event_name)
id=$(field .session_id)
[ -n "$id" ] || exit 0
project=$(basename "$(field .cwd)")
task=""

case "$event" in
  SessionStart)     state=done;    task="New session. Waiting for your first message." ;;
  UserPromptSubmit) state=working; task=$(field .prompt | tr '\n' ' ' | cut -c1-160) ;;
  PreToolUse)       state=working ;;
  Notification)
    msg=$(field .message)
    case "$(field .notification_type) $msg" in
      *idle*|*"waiting for your input"*) exit 0 ;;  # just idle, not a real question
    esac
    state=waiting; task="$msg" ;;
  Stop)             state=done;    task="Finished. Your turn." ;;
  SessionEnd)       state=ended ;;
  *) exit 0 ;;
esac

# PreToolUse fires on every tool call: skip it if nothing changed since last time.
mark="${TMPDIR:-/tmp}/kitten-office-${id//[^A-Za-z0-9-]/}"
if [ -z "$task" ] && [ "$(cat "$mark" 2>/dev/null)" = "$state" ]; then exit 0; fi
echo "$state" > "$mark"
[ "$state" = ended ] && rm -f "$mark"

body=$(jq -n --arg k "$KITTEN_WRITER_KEY" --arg id "$id" --arg s "$state" --arg p "$project" \
  --arg m "${KITTEN_MACHINE:-mac}" --arg t "$task" \
  '{p_key:$k, p_id:$id, p_state:$s, p_project:$p, p_machine:$m, p_task:$t}')
( curl -sS -m 5 -o /dev/null -X POST "$KITTEN_URL/rest/v1/rpc/kitten_report" \
    -H "apikey: $KITTEN_ANON_KEY" -H "Content-Type: application/json" -d "$body" >/dev/null 2>&1 & )
exit 0
