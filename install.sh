#!/bin/bash
# Installs the Kitten Office hook into Claude Code on this Mac.
# Run from the kitten-office folder:  ./install.sh
set -e
command -v jq >/dev/null 2>&1 || { echo "jq is missing. Install it with:  brew install jq"; exit 1; }

mkdir -p "$HOME/.claude/hooks"
cp hooks/kitten-office.sh "$HOME/.claude/hooks/kitten-office.sh"
chmod +x "$HOME/.claude/hooks/kitten-office.sh"

ENV="$HOME/.claude/kitten-office.env"
if [ ! -f "$ENV" ]; then
  read -r -p "Supabase project URL (https://....supabase.co): " url
  read -r -p "Supabase anon / publishable key: " anon
  read -r -s -p "Kitten writer key: " wk; echo
  printf 'KITTEN_URL=%q\nKITTEN_ANON_KEY=%q\nKITTEN_WRITER_KEY=%q\nKITTEN_MACHINE=mac\n' "${url%/}" "$anon" "$wk" > "$ENV"
  chmod 600 "$ENV"
fi

S="$HOME/.claude/settings.json"
[ -f "$S" ] || echo '{}' > "$S"
cp "$S" "$S.backup-$(date +%Y%m%d-%H%M%S)"
jq --arg cmd "$HOME/.claude/hooks/kitten-office.sh" '
  .hooks = (.hooks // {}) |
  reduce ("SessionStart","UserPromptSubmit","PreToolUse","Notification","Stop","SessionEnd") as $e (.;
    .hooks[$e] = (((.hooks[$e] // []) | map(select(any(.hooks[]?; .command == $cmd) | not)))
                  + [{"hooks": [{"type": "command", "command": $cmd}]}]))' "$S" > "$S.tmp" && mv "$S.tmp" "$S"

echo "Installed. New Claude Code sessions will now show up in Kitten Office."
echo "(Your old settings were backed up next to $S.)"
