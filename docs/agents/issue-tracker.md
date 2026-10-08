# Issue tracker: Local task files

Work for this repo is tracked as markdown tickets under `docs/tasks/`, not GitHub Issues.

## Conventions

- One ticket per file: `docs/tasks/<ID>-<slug>.md` (zero-padded IDs: `001`, `002`, …)
- Index: `docs/tasks/README.md` (ID, status, title, depends, pr)
- Status line near the top of each ticket: `todo` | `in progress` | `in review` | `done`
- Spec for a ticket = its `## Goal` + `## Decisions` (after `/refine`)
- New IDs: `max(existing ID) + 1`

## When a skill says "publish to the issue tracker"

Create or update a file under `docs/tasks/` and refresh `docs/tasks/README.md`.

## When a skill says "fetch the relevant ticket"

Read `docs/tasks/<ID>-<slug>.md`. Prefer the path or ID the user (or lifecycle skill) already named.

## PRs as a request surface

Off. Review feedback is handled via `/address` on the ticket’s `pr`, not by triaging external PRs into the queue.
