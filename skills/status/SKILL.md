---
name: status
description: Show a digest of current Hats project state — message channels, threads, unread counts, role scratchpad sizes, current role.
---

# Hats Status

A read-only digest of the project's collaboration state. Use anytime — does not change `.hats/role`.

## Steps

### 1. Detect project

If `.hats/status.json` does not exist, say:
```
Status: This directory is not a Hats project (no .hats/status.json found). Run /hats:init to set one up.
```
Then stop.

### 2. Read state

Read in parallel:
- `.hats/status.json` — channel + thread counts
- `.hats/role` (if it exists) — current active role
- `.hats/shared/manager2team.md`
- `.hats/shared/cto2team.md`
- `.hats/shared/designer2team.md`
- `.hats/shared/qa2dev.md`
- `.hats/shared/dev2qa.md`
- `.hats/shared/qa2designer.md`
- `.hats/shared/dev2designer.md`
- `.hats/shared/qa-report.md` (if exists)

For each shared/*.md file, take the last `## ` heading block (most recent message) so you can quote one line in the digest.

For each role's `.hats/<role>/notes.md` (manager, designer, cto, qa, developer), read the file and count lines. Skip silently if missing.

Glob `.hats/shared/threads/*.md` and `.hats/shared/threads/**/*.md`. For each thread file, get its name (relative to `threads/`) and check `status.json.threads.<name>` for unread counts per role.

### 3. Print the digest

Use this format:

```
## Hats Status — <project-dir>

**Active role:** <role from .hats/role, or "none (solo mode)" if missing>
**Hats version:** <read from MIGRATIONS.md latest entry or plugin.json if accessible — else "unknown">
**Model:** <read from .hats/model if exists, else say "auto (detected per-call from transcript)">

### Message channels

| Channel | Sent | Latest | Unread by |
|---|---|---|---|
| manager2team | 8 | "Re: auth feature scope" | qa, developer |
| cto2team     | 9 | "Re: stack chosen — Rails 7" | manager |
| qa2dev       | 24 | "Re: 3 tests failing on /signup" | manager |
| ...

### Threads

| Thread | Sent | Latest | Unread by |
|---|---|---|---|
| auth-redesign | 5 | "Re: token expiry" | designer |
| ...

(Skip this section if there are no threads.)

### Role scratchpads (notes.md line counts)

- manager:    12 lines
- designer:    8 lines
- cto:         5 lines
- qa:         34 lines
- developer:  47 lines  ⚠ near 50-line cap

### Test status

- Latest qa-report.md: <X passed, Y failed> (or "no qa-report.md yet")
- run-tests.sh: <exists | missing>

### Suggested next action

<one sentence — pick the most useful next step. Examples:>
- "Developer has 3 unread messages from QA — run /hats:developer to address them."
- "All channels caught up. Nothing waiting."
- "qa-report.md shows 5 failing tests — run /hats:developer to continue."
```

For "Unread by" — for each channel/thread, compute roles where `read_by[role]` < `count`. List only those roles. If everyone is caught up, write "—".

For "Suggested next action" — prioritise:
1. A scratchpad over the 50-line cap → suggest the owning role compact it
2. Failing tests in `qa-report.md` → suggest `/hats:developer`
3. A `## BLOCKER:` entry in any shared/*.md → flag it explicitly
4. Most-unread channel or thread → suggest the role that should read it
5. Otherwise: "All channels caught up."

## Rules

- Do NOT write any files. This is a read-only digest.
- Do NOT change `.hats/role`.
- Do NOT update `read_by` counts in status.json — viewing the digest is not the same as reading the messages.
- Skip channels/threads with `count: 0` from the table to keep the digest tight.
