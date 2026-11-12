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
3. [ ] Real agents in the cloud: the same hook in cloud sessions.
4. [ ] Host the page (e.g. GitHub Pages) so the iPad can open it from anywhere.

## How updates reach the page
The page exposes one function, `kittenOffice.update(event)`, where
`event = { id, name, project, where: "mac" | "cloud", state: "working" | "waiting" | "done" | "ended", task }`.
Step 2 connects that function to live Supabase updates.

## Rules
- Never commit secrets. Keys go in `.env.local`, which is git-ignored.
