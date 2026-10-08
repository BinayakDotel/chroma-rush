---
name: refine
description: >-
  Pick the next (or named) todo ticket, grill decisions, write Decisions + Files +
  Verify. No code. Use when the user runs /refine or starts planning a docs/tasks ticket.
disable-model-invocation: true
argument-hint: "[ticket-ID]"
---

# /refine [ID]

1. `gt sync -f`. For each `in review` ticket with a `pr`, run `gh pr view <n> --json state`. If MERGED, set status `done`. Update `docs/tasks/README.md`.
2. Pick the named ticket, else the first `todo` whose `depends` are all `done`. `gt checkout <base>`. Set status `in progress`. Update the index.
3. Commit bookkeeping only: stage `docs/tasks/**`, `git commit -m "chore(tasks): refine <ID>"`, `git push origin main`.
4. Read the ticket (Goal + existing sections). Use codebase search for gaps; open files one at a time. Append candidates to `## Files`.
5. Run the `grill-me` skill (→ `grilling`), capped at **8 questions total**, each with a recommendation. Prefer one batch. Consult `codebase-design` only if seam/interface shape is the question.
6. If the work needs more than ~5 **logical** files (`.gd`+`.tscn` = 1): propose stacked tickets (IDs, Goals, `depends`, `base`), write their files, update the index, stop. Do not build.
7. Write `## Decisions`, finalize `## Files`, write `## Verify` (≤5 manual bullets for the human). No headless Godot.
8. Stop. Do not build.

Token discipline and model table: `.cursor/rules/engineering.mdc`.
Reply ends with: `Next: /implement on Auto, effort Low.`
