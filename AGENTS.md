# Agent guide

## Agent skills

### Lifecycle (one skill per new chat)

| Skill | Role |
| --- | --- |
| `/refine` | Pick ticket, grill, write Decisions + Files + Verify. No code. |
| `/implement` | Build from ticket, code-review, Graphite PR. |
| `/address` | Fix PR review comments. |
| `/done` | After merge: mark done, name next todo. |

Rules: `.cursor/rules/engineering.mdc`. Tickets: `docs/tasks/`.

### Issue tracker

Local markdown under `docs/tasks/`. See `docs/agents/issue-tracker.md`.

### Reusable skills (`.agents/skills/`)

Call these from lifecycle skills or dedicated chats — do not duplicate them:

- `grill-me` / `grilling` — decisions in `/refine`
- `code-review` — Standards + Spec before PR
- `tdd` — only when a quiet test seam exists
- `codebase-design` — seam/interface vocabulary
- `domain-modeling` — glossary / ADRs when terms change
- `diagnosing-bugs` — hard bugs in a fresh chat
- `handoff` — optional; routine tickets use the ticket file only
