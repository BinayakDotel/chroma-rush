---
name: address
description: >-
  Address PR review comments on the in-review ticket; gt modify + gt submit.
  Use when the user runs /address after review feedback.
disable-model-invocation: true
argument-hint: "[PR number]"
---

# /address [PR]

1. Take the first `in review` ticket, or the one matching the named PR. Read `gh pr view <n> --comments`.
2. `gh pr view <n> --json headRefName` → `gt checkout` that branch.
3. Fix each comment. Behavior change → prefer a failing check first only if quiet `just test-q` exists; else note the human Verify bullet to re-run. Do not run headless Godot.
4. Ambiguous comment or missing context → stop and ask; never guess game feel.
5. `gt modify -a` then `gt submit`.
6. Report one line per comment: what changed, or why not.

Token discipline and model table: `.cursor/rules/engineering.mdc`.
Reply ends with: `Next: /done on Auto, effort Low.` (after human merges).
