# Kitten Office

A tiny web page for the owner's iPad that shows their Claude Code chats as pixel-art kittens in an office.
Read `README.md` for what it does and the step plan.

## Working rules
- The owner is new to coding: explain in plain English, keep steps small, say how to test each one.
- Keep it simple: no build step, no frameworks, no npm. The page is one file (`index.html`).
- Never commit secrets. The writer key and viewer key are never in this repo.
  The Supabase URL and publishable key in `index.html` are public by design and fine to commit.
- When a step is done, tick it off in `README.md`.

## Where things are (as of step 2 done)
- **Page:** `index.html`, served by GitHub Pages at https://digitaldanuk.github.io/kitten-office/ (repo is public).
  Without `#<viewer key>` on the link it shows pretend kittens (demo mode). With it, it polls
  `public.kitten_get_agents(p_key)` every 2 s and moves kittens to match.
- **Database:** lives inside the owner's **StoryOS test** Supabase project (`ilzvhbebeagtottevhij`), walled off in
  its own `kitten_office` schema. Setup SQL: `supabase/schema.sql` (safe to re-run). Only bcrypt hashes of the
  keys are stored, in `kitten_office.app_keys`. The owner runs SQL themselves in the Supabase SQL Editor:
  the Supabase connector in Claude sessions only reaches the Nestrel project, not StoryOS.
  Do not touch Nestrel or StoryOS's own tables.
- **Mac hook:** `hooks/kitten-office.sh`, installed by `install.sh` into `~/.claude/hooks/` and
  `~/.claude/settings.json`. Settings live in `~/.claude/kitten-office.env` (URL, publishable key, writer key,
  `KITTEN_MACHINE=mac`). Installed and tested on the owner's Mac.
- The owner holds the writer and viewer keys in a private file. Ask them for the writer key only via a
  secure route (e.g. `request_credential`), never in chat.

## Event mapping (hook → kitten)
SessionStart → done (naps) · UserPromptSubmit → working (task = prompt) · PreToolUse → working
(skipped if state unchanged) · Notification → waiting (idle reminders ignored) · Stop → done · SessionEnd → ended (walks out).

## Next: step 3, cloud chats
Goal: Claude Code cloud sessions (claude.ai/code) show up as kittens with `machine = 'cloud'`.
Suggested approach, to be checked before building:
1. The writer key must not go in plain environment variables. Instead let the network proxy inject it as a
   header: change `kitten_report` to also accept the key from a request header (e.g. `x-kitten-key`, read with
   `current_setting('request.headers', true)::json ->> 'x-kitten-key'`), and save the key with
   `request_credential` for host `ilzvhbebeagtottevhij.supabase.co`, header `x-kitten-key`. That also allows the host.
2. Get the hook into cloud sessions without changing other repos: an environment setup script that downloads
   `hooks/kitten-office.sh` from this public repo and registers it in the container's `~/.claude/settings.json`,
   with a non-secret env file (`KITTEN_URL`, publishable key, `KITTEN_MACHINE=cloud`).
   First confirm that cloud sessions actually run user-level hooks from `~/.claude/settings.json`.
3. Test with a real cloud chat and watch the iPad.

## Gotchas learned
- Bcrypt hashes contain `$`. Never put them through shell `source`/unquoted expansion: that mangled the
  first install's stored hashes. Build SQL containing hashes with Python or quoted heredocs.
- Cloud sessions here could not reach `*.supabase.co` or `github.io` directly (proxy blocked), so live tests
  were done by the owner on the iPad/Mac.
- The claude.ai artifact version of the page cannot fetch Supabase (CSP), which is why it is hosted on GitHub Pages.
