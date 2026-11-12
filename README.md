# Kitten Office

A tiny web page for an iPad that shows your Claude Code agents as pixel-art kittens in an office.

- **At a desk:** the agent is working.
- **On the yellow mat, waving:** the agent needs you (a permission prompt or a question).
- **Napping on a cushion:** the agent has finished.
- Kittens walk in through the door when a session starts and walk out when it ends.

## Try it
Open `index.html` in a browser. For now it runs **pretend agents** (demo mode).
On iPad: open the page in Safari, then Share → Add to Home Screen.

## Plan
1. [x] Demo page with pretend kittens.
2. [ ] Real agents on the Mac: a Claude Code hook sends status to Supabase, and the page listens to Supabase.
   - [x] Code written: `supabase/schema.sql`, `hooks/kitten-office.sh`, `install.sh`, live mode in `index.html`.
   - [ ] Supabase project created and schema run.
   - [ ] Hook installed on the Mac and tested.
3. [ ] Real agents in the cloud: the same hook in cloud sessions.
4. [ ] Host the page (e.g. GitHub Pages) so the iPad can open it from anywhere.

## How it works
1. A Claude Code **hook** (`hooks/kitten-office.sh`) runs when a session starts, you send a message,
   a tool runs, Claude needs your permission, Claude finishes, or the session ends.
2. It sends one small update to Supabase through `kitten_report()`, which needs the **writer key**.
3. The page asks Supabase every 2 seconds through `kitten_get_agents()`, which needs the **viewer key**.
   The viewer key goes after the `#` in the page link, so it is never stored in this repo.

Everything lives in its own `kitten_office` schema, so it can share a Supabase project with other apps. Nobody can read or change its tables directly. Only bcrypt hashes of the two keys are stored.

## Setting up on your Mac
1. Download this repo to your Mac.
2. In Terminal, inside the folder, run `./install.sh`. It asks for the Supabase URL, the anon key and the writer key.
   It saves them in `~/.claude/kitten-office.env` (only your user can read that file), and adds the hook to
   `~/.claude/settings.json` after backing that file up. It needs `jq`, which macOS 15 and later already include.
3. Test it without starting Claude:
   `echo '{"hook_event_name":"Notification","session_id":"test-kitten","cwd":"/tmp/test","message":"Test kitten needs you"}' | ~/.claude/hooks/kitten-office.sh`
   A kitten should appear on the yellow mat within a few seconds.
   Send it home with: `echo '{"hook_event_name":"SessionEnd","session_id":"test-kitten","cwd":"/tmp/test"}' | ~/.claude/hooks/kitten-office.sh`

## How updates reach the page (internals)
The page exposes one function, `kittenOffice.update(event)`, where
`event = { id, name, project, where: "mac" | "cloud", state: "working" | "waiting" | "done" | "ended", task }`.
Step 2 connects that function to live Supabase updates.

## Rules
- Never commit secrets. Keys go in `.env.local`, which is git-ignored.
