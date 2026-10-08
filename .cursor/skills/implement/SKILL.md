---
name: implement
description: >-
  Implement the first in-progress ticket from its Decisions + Files, code-review,
  then gt create + gt submit. Use when the user runs /implement after /refine.
disable-model-invocation: true
---

# /implement

1. Take the first `in progress` ticket. Read **only** the ticket and paths in `## Files`.
2. **Hard stops** (do not invent behavior):
   - No `## Decisions` → stop: run `/refine` first.
   - `## Files` empty or clearly incomplete for the Goal → stop; list what’s missing.
   - Need a path not listed → search once; if found, append to `## Files` and ask “OK to continue?” before editing. If not found, stop.
   - Goal vs Decisions ambiguous → one clarifying question; stop.
3. If it needs more than ~5 logical files, stop and say to split via `/refine` — do not split mid-build.
4. Build only what Decisions require. Call `tdd` only if Decisions name a seam **and** a quiet `just test-q` exists; otherwise skip TDD and rely on `## Verify`.
5. Do **not** run headless Godot. Refresh `## Verify` if the change shifted what a human must check.
6. Run `code-review` with fixed point = ticket `base` and spec = this ticket file. Fix real findings.
7. Write `## Outcome` (what changed, why, one risk). Set status `in review`. Update the index.
8. `gt create -am "<type(scope): subject>"`, then `gt submit --no-edit` (if rejected, `--no-interactive`). Put PR URL into ticket `pr` and the index; `gt modify -a` + `gt submit --no-edit` if needed. Set PR body with `gh pr edit <n> --body-file <tempfile>`: Outcome + Verify.
9. Report PR link and Outcome. No pasted diffs.

Token discipline and model table: `.cursor/rules/engineering.mdc`.
Reply ends with: `Next: /address on Auto, effort Low.` (or `/done` after human merges).
