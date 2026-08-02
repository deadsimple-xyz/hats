# Migrations

The doctor reads this file to upgrade old Hats projects.

## 4.4.0 → 5.0.0

### Channels are directories, not one growing file

`.hats/shared/<channel>.md` becomes `.hats/shared/<channel>/` — one file per
entry, plus a generated `INDEX.md` (newest first), plus `ARCHIVE.md` holding
the original untouched.

**Why this is not cosmetic.** A channel is appended at the bottom, `Read`
returns the first 2000 lines, and the role prompts say «NEVER use
cat/head/tail». Measured on design-gpt: `qa2dev.md` held 15 entries spanning
`[40]..[51]`; a role following its instructions saw 6 and stopped at `[42]`.
Nine entries out of fifteen were read by nobody, ever. The failure starts at
about 130 KB, which is most projects by their second month.

Per channel:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/channel.sh" split .hats/shared/qa2dev.md
```

The split verifies itself: entries are concatenated back and compared with the
original byte for byte, and nothing is written if they differ. Run over six
live projects — 35 channels of 35 migrated with no loss.

Un-migrated projects keep working: the guard still accepts the flat file, and
the prompts tell a role what to do if it finds one.

### Tasks

New: `.hats/tasks/`, one folder per task, in git. Nothing to migrate — the
directory appears when the first task is created, and projects without tasks
are unaffected.

Three status gates land with it, in `guard.sh` and in `scripts/task.sh` alike:
`open -> done` refused; `in_progress` needs a non-empty `understanding.md`;
`done` needs a non-empty `resolution.md`. They fire on hand-edits too — a gate
only the helper enforces is a convention wearing a mechanism's coat.

### The role is per-session, and `HATS_ROLE` pins it

`.hats/role` was per-DIRECTORY, so two sessions in one repo shared one fence
and the second session's switch silently re-aimed the first one's. Each session
now records its own position under `.hats/sessions/<session_id>`; resolution is
`HATS_ROLE` → this session → `.hats/role`.

Set `HATS_ROLE` where the fence must be real (autopilot, spawned per-role
sessions, CI): a write to `.hats/role` is then refused with a refusal that
names the pin. Every switch appends to `.hats/role-history`, and that audit is
deliberately not behind the debug flag.

Nothing to run. Old projects work unchanged; `.hats/sessions/` appears on its
own. Add `.hats/sessions/` and `.hats/role-history` to `.gitignore`.

### Shared prompt fragments

`agents/_shared/pipeline.md` (the whole route, capability map, what «done»
means) and `agents/_shared/channels.md` (how channels are read and written) are
now read by every role at activation. Nothing to migrate — they ship with the
plugin.

### hats has tests

`bash tests/run.sh`. No framework to install. Known gaps are registered in
`tests/KNOWN-GAPS.md`: they print on every run, do not fail it, and DO fail it
the day they start passing.

## 4.3.5 → 4.4.0

### Decision records + reopen triggers (FPF-lite)

Three lightweight borrows from the [First Principles Framework](https://github.com/ailev/FPF) — the *ideas* (auditable decisions, scope, reopen-triggers), not the formal vocabulary. Old-Twitter style is untouched: every addition is one line per item, written to a file, never to chat.

- **CTO** now records each significant stack choice as a one-line **decision record** in `stack.md` under a `## Decision records` section: `**<choice>** — over <alternative(s)>, because <reason>. Reopen if <condition>.`
- **QA** adds a `## Scope & reopen` section to `test-contract.md` for `@critical` scenarios only: where the contract holds and when it stops being valid. Catches "green but on the wrong assumption".
- **Developer** treats a hit `Reopen if …` condition as a flag-up to CTO/QA, not a silent workaround.

**No project changes needed.** This is prompt-only — existing `stack.md` / `test-contract.md` files keep working; the new sections appear the next time CTO/QA rewrite them. Doctor has nothing to migrate.

## 4.3.0 → 4.3.1

Plugin manifest fix: removed explicit `"hooks": "./hooks/hooks.json"` from `plugin.json`. The standard `hooks/hooks.json` is auto-loaded by Claude Code, and declaring it explicitly caused a duplicate-load error on `/doctor`. No project-side change.

## 4.2.0 → 4.3.0

### Old-Twitter activation + result style

Roles no longer print multi-line "Checking in" banners or status dashboards on activation. Activation is now silent (read inbox + threads + notes.md, mark read, pick next action) and the role announces in ONE line, ~200 chars, then proceeds.

**Default is action, not permission.** The Plan-then-confirm gate is gone:
- Removed "Phase 1: Plan (interactive)" / "Phase 2: Execute" framing across all 5 agents.
- Removed "NEVER call the Agent tool without explicit human confirmation" rule.
- Roles never ask "what are we building?", "want me to start with 1?", or about commits — they just do all by default.
- Go-mode is no longer the special path; it's the only path. The `go`/`continue`/etc. shortcut still works but is now redundant.

**New `## How you talk` section** in every agent enforces:
- One line per response (~200 char target).
- Result shape: `Role: <verbed> <thing>. → <file>` — no recap, the user reads the file.
- Cycle update shape (Developer): `Developer: Cycle 2/5 — 14 pass, 3 fail. Fixing X.`
- Max one question per response, only when literally blocked.

**No project changes needed.** Activation files (`.hats/role`, `.hats/<role>/notes.md`) and shared channels are unchanged. Doctor has nothing to migrate.

## 4.1.1 → 4.2.0

### New: model + version tagging in debug logs

Every JSONL log line now includes `hv` (Hats version) and `model` (Claude model) so you can filter logs by either when analyzing friction:

```jsonl
{"ts":"...","hv":"4.2.0","model":"claude-opus-4-7-20251024","role":"developer","tool":"Bash","command":"..."}
```

**Model resolution order** (per log entry):
1. `.hats/model` file (manual override — `echo "claude-opus-4-7" > .hats/model`)
2. Auto-detected from the most recent assistant message in the session transcript
3. `$CLAUDE_MODEL` / `$ANTHROPIC_MODEL` env vars
4. `"unknown"`

**Why this matters** — when reviewing accumulated logs, some friction patterns may already be resolved by Claude getting smarter (Opus 4.6 → 4.7 etc.), not by changes to Hats. The new fields let you compare same role behaviour across model + Hats version combinations before proposing a Hats-side fix. See `self-learning.md` for jq filter examples.

**No schema break** — old log files without these fields stay readable; new lines just have richer metadata.

## 4.0.0 → 4.1.0

### New: per-role scratchpads (`notes.md`)

Each role gets a persistent working memory file at `.hats/<role>/notes.md` that survives across activations and sub-agent spawns. Reduces redundant file reads (real-project logs showed 20-45× re-reads of the same file in one autopilot session) and carries context between cycles.

Adds `.hats/developer/` directory (previously skipped — developer had no own dir). Init/doctor manage it.

### New: thread-based messaging (`shared/threads/`)

Ad-hoc per-topic conversations now live in `.hats/shared/threads/<topic>.md` (kebab-case filenames). Any role can read or append. Channels (`<role>2team.md`, etc.) remain for canonical broadcasts; threads cover cross-cutting topics that don't fit the channel matrix.

`.hats/status.json` gets a parallel `threads` key:
```json
{
  "messages": { ... existing ... },
  "threads": {
    "auth-redesign": { "count": 5, "read_by": { "cto": 5, "manager": 3 } }
  }
}
```

Threads are created lazily — no doctor enforcement. Just write `.hats/shared/threads/<topic>.md` and update `status.json.threads.<topic>` when needed.

Guard updated: `shared/threads/*.md` is open to all roles (any role can append to any thread).

### New: silent status broadcasts

When a role makes a decision, learns a constraint, or changes an assumption during conversation that other roles need to know, it writes silently to the appropriate channel/thread without asking. The user sees a one-line "(Noted in <file> — <Role>(s) should see.)" at the end of the reply. Triggered only by **decisions** (not exploration or chat). Complements proactive handoffs: handoffs ask first ("want me to tell them?"), silent broadcasts don't.

### New: proactive handoffs

Every role offers to draft a thread when the conversation drifts into another role's domain. The user switches roles when convenient; the target role surfaces unread threads on activation. Activation steps now include a `status.json.threads` check parallel to the inbox check.

The handoff captures **the user's request in their own words** (no paraphrasing) so intent doesn't drift across role switches.

### New: "go" mode

Type `go` (or `continue`, `next`, `proceed`, `gogo`) as the first message after activating any role to skip the activation question and have the role pick up the most obvious next action from inbox + threads + scratchpad + project state. Each role has tailored defaults — Developer goes straight to fixing failing tests in `qa-report.md`, QA reviews unread `dev2qa` and re-runs.

### New: `/hats:status` skill

Read-only digest of message channels, threads, scratchpad sizes, test status, and a suggested next action. Does not change `.hats/role`.

### New: secret redaction in debug logs

`scripts/debug-log.sh` now redacts common token shapes (Figma `figd_`, OpenAI/Anthropic `sk-`, GitHub `ghp_`, Slack `xox*-`, AWS `AKIA*`, Bearer tokens, JWT) before writing to `.hats/logs/`. **If you have existing `.hats/logs/*.jsonl` files, audit them — they may contain unredacted secrets from before this update.**

### .gitignore additions
- `.hats/debug` (debug toggle file should not be committed)

### Guard tightening: developer dir isolation
- Non-developer roles can no longer write to `.hats/developer/` (was an isolation gap).

### Guard relaxation: CTO can read `.hats/qa/`
- The CTO read-block on `.hats/qa/` is removed. Architecture review legitimately needs visibility into the test surface.

### Autopilot: inline round signal
- Developer Turn now receives a 3-5 line digest of QA's latest message + failing-test summary inline in the prompt, so the dev sub-agent doesn't have to re-discover the round's signal from files.

## 3.2.0 → 4.0.0

### Breaking: symlinks removed, shared data consolidated

All cross-role symlinks are removed. Specs and designs move into `.hats/shared/` subdirectories. This eliminates recursive symlink cycles that caused tools (bddgen, playwright) to create infinite directory nesting.

**New structure:**
- `.hats/shared/specs/` — Manager writes `.feature` files here (was `.hats/manager/`)
- `.hats/shared/designs/` — Designer writes design files here (was `.hats/designer/`)
- `.hats/manager/`, `.hats/designer/`, `.hats/cto/` — empty private workspaces (no symlinks)

**What moved:**
```bash
# Specs
mkdir -p .hats/shared/specs
mv .hats/manager/*.feature .hats/shared/specs/

# Designs
mkdir -p .hats/shared/designs
mv .hats/designer/*.md .hats/shared/designs/
```

**Remove all symlinks:**
```bash
find .hats/manager/ .hats/designer/ .hats/cto/ .hats/qa/ -maxdepth 1 -name '.hats-*' -type l -delete
```

**Guard update:** The write guard now enforces ownership of `shared/specs/` (manager only) and `shared/designs/` (designer only) in addition to the existing per-file rules for `shared/`.

**Agent path changes:**
- `.hats/manager/*.feature` → `.hats/shared/specs/*.feature`
- `.hats/designer/*` → `.hats/shared/designs/*`
- `.hats-manager/` → `.hats/shared/specs/`
- `.hats-designer/` → `.hats/shared/designs/`
- `.hats-shared/` → `.hats/shared/`
- All `../status.json` → `.hats/status.json`

**run-tests.sh:** QA must ALWAYS use `bash run-tests.sh` to run tests. Never run test commands directly (no raw `npx playwright`, `npx bddgen`, `pytest`).

## 3.1.0 → 3.2.0

### Test contract and `qa` attributes

QA now writes a **test contract** to `.hats/shared/test-contract.md` listing all observable expectations (qa attributes, API endpoints, response fields). The Developer reads this contract instead of guessing what tests expect.

**Selectors:** QA tests must use `qa="..."` HTML attributes instead of CSS classes, ids, or tag names. Example: `<button qa="reset-button">Reset</button>`, selected as `[qa="reset-button"]`.

**Existing projects with tests:** If `.hats/qa/` already contains tests using CSS selectors:
1. Run `/hats:qa` — QA will review existing tests, migrate selectors to `qa` attributes, and write `test-contract.md`
2. Run `/hats:developer` — Developer will read the contract and add `qa="..."` attributes to the implementation

**New file:** `.hats/shared/test-contract.md` (created by QA, read by Developer)

**Guard update:** QA can now write `test-contract.md` to `.hats/shared/`.

### Autopilot scope change

Autopilot (`/hats:autopilot`) now runs only the **QA ↔ Developer loop**, not the full pipeline. Manager, Designer, and CTO must be run manually first. Max 3 outer rounds.

## 3.0.0 → 3.1.0

### Role file moved

`.hats-role` → `.hats/role` — the role activation file now lives inside `.hats/` with everything else.

**Auto-migration (doctor handles this):**
- If `.hats-role` exists at project root, move it to `.hats/role`
- If `.gitignore` contains `.hats-role`, replace with `.hats/role`

**Manual fix:**
```bash
[ -f .hats-role ] && mv .hats-role .hats/role
sed -i '' 's/^\.hats-role$/.hats\/role/' .gitignore
```

### Debug logging (optional)

Touch `.hats/debug` to enable JSONL debug logging to `.hats/logs/YYYY-MM-DD.jsonl`. Remove the file to disable. Zero overhead when off.

### .gitignore

- `.hats-role` → `.hats/role`
- Add `.hats/logs/` (debug log output)

## 2.3.0 → 3.0.0

### Breaking: directory restructure

All Hats directories move into `.hats/`. The `developer/` directory is eliminated — code lives at project root.

**Move code out of developer/ (if applicable):**
```bash
# If your code was in developer/, move it to project root first:
mv developer/* . && rm -rf developer/
```

**Remove old Hats dirs** (after moving content):
```bash
rm -rf manager/ designer/ cto/ shared/ qa/ status.json
```

**Create new structure:**
```bash
mkdir -p .hats/{manager,designer,cto,shared,qa}
# Move specs:
mv manager/*.feature .hats/manager/ 2>/dev/null || true
# Move designs:
mv designer/* .hats/designer/ 2>/dev/null || true
# Move tests:
mv qa/* .hats/qa/ 2>/dev/null || true
# Move shared:
mv shared/* .hats/shared/ 2>/dev/null || true
mv status.json .hats/status.json 2>/dev/null || true
```

**Recreate symlinks:**
```bash
ln -sfn ../shared .hats/manager/.hats-shared
ln -sfn ../designer .hats/manager/.hats-designer
ln -sfn ../shared .hats/designer/.hats-shared
ln -sfn ../manager .hats/designer/.hats-manager
ln -sfn ../shared .hats/cto/.hats-shared
ln -sfn ../manager .hats/cto/.hats-manager
ln -sfn ../designer .hats/cto/.hats-designer
ln -sfn ../shared .hats/qa/.hats-shared
ln -sfn ../manager .hats/qa/.hats-manager
```

Note: no symlinks are created for the developer role — developer reads `.hats/` paths directly.

## 2.2.0 → 2.3.0

### Symlink renames

Old names are removed; recreate with new names:

**manager/**
- `.hats-designs` → renamed to `.hats-designer`

**designer/**
- `.hats-specs` → renamed to `.hats-manager`

**cto/**
- `.hats-specs` → renamed to `.hats-manager`
- `.hats-designs` → renamed to `.hats-designer`

**qa/**
- `.hats-specs` → renamed to `.hats-manager`

**developer/**
- `.hats-specs` → renamed to `.hats-manager`
- `.hats-designs` → renamed to `.hats-designer`

To fix: remove old symlinks and recreate:
```bash
rm manager/.hats-designs designer/.hats-specs cto/.hats-specs cto/.hats-designs qa/.hats-specs developer/.hats-specs developer/.hats-designs
ln -sfn ../designer manager/.hats-designer
ln -sfn ../manager designer/.hats-manager
ln -sfn ../manager cto/.hats-manager
ln -sfn ../designer cto/.hats-designer
ln -sfn ../manager qa/.hats-manager
ln -sfn ../manager developer/.hats-manager
ln -sfn ../designer developer/.hats-designer
```

## 2.1.0 → 2.2.0

### New file in `shared/`
- `shared/cto2team.md` -- CTO → team stack announcements (create empty if missing)

### `status.json`
Add `cto2team` channel to `messages` key:
```json
{
  "messages": {
    "cto2team": { "count": 0, "read_by": { "manager": 0, "designer": 0, "qa": 0, "developer": 0 } }
  }
}
```

## 2.0.0 → 2.1.0

### New files in `shared/`
- `manager2team.md` -- Manager → team announcements (create empty if missing)
- `qa2dev.md` -- QA → Developer messages (create empty if missing)
- `dev2qa.md` -- Developer → QA messages (create empty if missing)
- `dev2designer.md` -- Developer → Designer questions (create empty if missing)
- `qa2designer.md` -- QA → Designer questions (create empty if missing)
- `designer2team.md` -- Designer → Developer + QA responses (create empty if missing)

### `status.json`
Add `messages` key if missing:
```json
{
  "messages": {
    "manager2team": { "count": 0, "read_by": { "cto": 0, "designer": 0, "qa": 0, "developer": 0 } },
    "qa2dev": { "count": 0, "read_by": { "developer": 0, "manager": 0 } },
    "dev2qa": { "count": 0, "read_by": { "qa": 0, "manager": 0 } },
    "dev2designer": { "count": 0, "read_by": { "designer": 0, "manager": 0 } },
    "qa2designer": { "count": 0, "read_by": { "designer": 0, "manager": 0 } },
    "designer2team": { "count": 0, "read_by": { "developer": 0, "qa": 0, "manager": 0 } }
  }
}
```

## 1.0.0 → 2.0.0

### New directory
- `cto/`

### New symlinks (12 total)

**manager/**
```bash
ln -sfn ../shared manager/.hats-shared
ln -sfn ../designer manager/.hats-designs
```

**designer/**
```bash
ln -sfn ../shared designer/.hats-shared
ln -sfn ../manager designer/.hats-specs
```

**cto/**
```bash
ln -sfn ../shared cto/.hats-shared
ln -sfn ../manager cto/.hats-specs
ln -sfn ../designer cto/.hats-designs
```

**qa/**
```bash
ln -sfn ../shared qa/.hats-shared
ln -sfn ../manager qa/.hats-specs
```

**developer/**
```bash
ln -sfn ../shared developer/.hats-shared
ln -sfn ../manager developer/.hats-specs
ln -sfn ../designer developer/.hats-designs
```

### .gitignore
- Must contain `.hats/role`

### Files
- `status.json` must exist (create with `{}` if missing)
