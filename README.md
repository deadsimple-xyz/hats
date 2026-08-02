# Hats

BDD-driven AI dev team. Five roles, one [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

```
manager -> designer -> cto -> qa -> developer
   |          |         |      |       |
 specs     mockups    stack  tests    code
```

## Quick Start

```bash
/plugin marketplace add deadsimple-xyz/claude-plugins
/plugin install hats@deadsimple
/reload-plugins
/hats:init                         # creates .hats/ directory structure
/hats:manager                      # "What are we building?"
```

Requires [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI.

## Commands

```
/hats:init          # set up project (new or existing)
/hats:manager       # specs & planning
/hats:designer      # wireframes & UI descriptions
/hats:cto           # stack decisions
/hats:qa            # automated tests from specs
/hats:developer     # implementation (TDD)
/hats:autopilot     # run the full pipeline autonomously
/hats:solo          # exit role mode, work as plain Claude
/hats:doctor        # diagnose and fix project structure
```

The typical flow is `manager > designer > cto > qa > developer`, but you can talk to any role at any time. If you know your stack, skip the CTO. If you have your own designs, skip the Designer. If something breaks in tests, jump into QA and discuss it.

## How It Works

You are the product owner. You talk to the **Manager** and describe what you want. The Manager writes [Gherkin](https://cucumber.io/docs/gherkin/) specs -- human-readable, machine-parseable `.feature` files:

```gherkin
@auth
Feature: JWT Authentication
  Users can register and login.
  Technical: RS256, access token 15min, refresh 7d.

  @critical @happy-path
  Scenario: Successful login
    Given a user "test@mail.com" with password "secret123" exists
    When user sends POST /auth/login with valid credentials
    Then response status is 200
    And response contains access_token and refresh_token
```

Then each role takes over:

| Role | Can read | Can write |
|------|----------|-----------|
| **Manager** | `.hats/shared/` | `.hats/manager/`, `.hats/shared/specs/`, `.hats/shared/manager2team.md` |
| **Designer** | `.hats/shared/` | `.hats/designer/`, `.hats/shared/designs/`, `.hats/shared/designer2team.md` |
| **CTO** | `.hats/shared/` | `.hats/cto/`, `.hats/shared/stack.md`, `setup.md`, `api.md`, `cto2team.md` |
| **QA** | `.hats/shared/`, `.hats/qa/` | `.hats/qa/`, `.hats/shared/qa-report.md`, `qa2dev.md`, `qa2designer.md`, `test-contract.md` |
| **Developer** | `.hats/shared/` + project root | project root, `.hats/shared/setup.md`, `api.md`, `dev2qa.md`, `dev2designer.md` |

Permissions are enforced by hooks -- the Developer literally *can't* read tests, and the QA *can't* read source code. Both halves are checked by rows in `tests/read-guard.test.sh`; the QA half was prose until 5.0.0, which is precisely why the tests exist.

**Know the edge of that guarantee.** The hooks match the file tools — `Write`, `Edit`, `Read`, `Glob`, `Grep`. **Bash is not matched**, so a role that reaches for a shell can read and write anything: `cat src/app.ts` works, and so does `echo … > file`. Roles need Bash constantly and legitimately, and deciding what an arbitrary command will touch means parsing a shell — so this is a known edge rather than an oversight (`tests/KNOWN-GAPS.md`, G3). The fences shape what a role does by default; they are not a sandbox. QA writes a plain-language report (`.hats/shared/qa-report.md`) so the Developer understands what failed and why, without seeing test code.

## Project Structure

After `/hats:init`:

```
my-app/
  .hats/
    manager/         Private workspace (Manager)
    designer/        Private workspace (Designer)
    cto/             Private workspace (CTO)
    qa/              Automated e2e tests + run-tests.sh
    shared/          All cross-role data
      specs/           .feature files (Manager writes)
      designs/         Mockups and wireframes (Designer writes)
      stack.md         Technology decisions (CTO)
      setup.md         How to run the project (CTO/Developer)
      api.md           API conventions (CTO/Developer)
      test-contract.md qa attributes & expectations (QA)
      qa-report.md     Test results for Developer (QA)
      manager2team/    Manager -> team           one file per entry
      cto2team/        CTO -> team               + INDEX.md, newest first
      designer2team/   Designer -> team
      qa2dev/          QA -> Developer
      dev2qa/          Developer -> QA
      dev2designer/    Developer -> Designer
      qa2designer/     QA -> Designer
      threads/         any role may append (conversations)
    tasks/           what is being worked on, one folder per task
    status.json      Current state and message counters
    role             Active role (managed by hooks)
  src/               Your code lives at project root
```

## Tasks are folders in git

Specs say what must be **true**. Tasks say what someone is **doing** — and
until v5 hats had no answer at all to «what is in flight, and what was closed
yesterday and why» that outlived the session it was asked in.

```
.hats/tasks/
  INDEX.md                        the board, one table
  0042-runner-flaky-on-login/
    task.md                       status / priority / owner / spec + the ask
    understanding.md              written when work starts
    resolution.md                 written when it closes
```

Three gates, enforced by the hook rather than asked for in a prompt:

- **`open -> done` is refused** — a task closes only after being in work.
- **`in_progress` needs a non-empty `understanding.md`** — say what you think
  the job is *before* doing it. Afterwards that sentence is a summary, which is
  a different and much easier thing to write.
- **`done` needs a non-empty `resolution.md`** — what you checked, what you
  concluded. The next person's question is «how do you know».

```bash
bash "$HATS/scripts/task.sh" new "Runner is flaky on login" 1 developer @auth
bash "$HATS/scripts/task.sh" next
bash "$HATS/scripts/task.sh" status .hats/tasks/0042-runner-flaky-on-login in_progress
```

Editing `task.md` by hand works too and is gated identically — the helper is a
convenience, not the fence.

## Channels are directories

Each channel is a directory of entries plus a generated `INDEX.md`, newest
first:

```
.hats/shared/qa2dev/
  INDEX.md                  read this
  0246-2026-07-30-qa.md     one entry, one subject
  0245-2026-07-30-qa.md
  ARCHIVE.md                everything as it was before migration
```

**Why.** A channel used to be one file, appended at the bottom. `Read` returns
the first 2000 lines and the roles are told never to `tail`. Measured on a live
project: `qa2dev.md` held 15 entries spanning `[40]..[51]`, and a role
following its own instructions saw 6 of them and stopped at `[42]`. Nine
entries were read by nobody, ever. It goes wrong at about 130 KB — most
projects by their second month.

Migrate an existing project with `/hats:doctor`, or by hand:

```bash
bash "$HATS/scripts/channel.sh" split .hats/shared/qa2dev.md
```

The split is verified byte-for-byte before anything is written, and the
original is kept as `ARCHIVE.md`. Run across six live projects: 35 channels of
35 migrated with no loss, and what a role reads on activation went from 2894 KB
to 119 KB of index.

Write with the same helper, which numbers, dates, names you and refreshes the
index:

```bash
echo "Runner is green." | bash "$HATS/scripts/channel.sh" \
  append .hats/shared/qa2dev QA
```

## Roles, sessions and the fence

The active role lives in `.hats/role`, and the guards read it. Two things worth
knowing:

- **`HATS_ROLE` pins the role.** Set it in the environment and the role cannot
  be changed from inside the session — a write to `.hats/role` is refused and
  says why. Use it wherever the fence must be real: autopilot, spawned per-role
  sessions, CI. Without it the door stays open, because the same door is how a
  human switches roles.
- **The role is per-session.** Two Claude Code sessions in one repo used to
  share one role file, so the second session's switch silently re-aimed the
  first one's fence. Each session now keeps its own position, and every switch
  appends a line to `.hats/role-history` — audit that is not behind the debug
  flag.

## Debug Logging


Enable debug logging to see exactly what each role does — every tool use, command, file read/write, and guard block:

```bash
touch .hats/debug          # enable
rm .hats/debug             # disable
```

Logs go to `.hats/logs/YYYY-MM-DD.jsonl` (one JSON object per line). Zero overhead when disabled — the hook checks for the flag file and exits immediately.

Example log:
```jsonl
{"ts":"2026-03-04T14:30:00Z","role":"none","tool":"Write","file":".hats/role"}
{"ts":"2026-03-04T14:30:01Z","role":"manager","tool":"Read","file":"agents/manager.md"}
{"ts":"2026-03-04T14:30:05Z","role":"manager","tool":"Agent","description":"Write feature specs"}
{"ts":"2026-03-04T14:30:07Z","role":"manager","tool":"Write","file":".hats/shared/manager2team.md"}
{"ts":"2026-03-04T14:30:15Z","event":"write_block","role":"designer","file":"src/index.ts","tool":"Write","reason":"designer can only write inside .hats/"}
```

See [self-learning.md](self-learning.md) for how to use logs to improve Hats itself.

## Decision records & reopen triggers

Decisions that outlive the chat get one line in the file they belong to — auditable later, and tagged with the condition that should make you revisit them:

- **CTO** records each significant stack choice in `stack.md`: `**Postgres** — over SQLite, because concurrent writes + RLS. Reopen if we drop multi-tenant.`
- **QA** tags `@critical` contract items in `test-contract.md` with the scope they hold for and a reopen condition — so a green test on the wrong assumption gets caught.
- **Developer** flags a hit `Reopen if …` condition up to CTO/QA instead of silently coding around a decision that no longer holds.

One line per decision is the whole ceremony. (Borrowed in spirit from the [First Principles Framework](https://github.com/ailev/FPF) — the idea, not the formalism.)

## What «done» means

Every role reads four shared fragments at activation, and they carry the parts
of the job that are the same for everyone:

| fragment | what it settles |
|---|---|
| `agents/_shared/pipeline.md` | the whole route, who owes what to whom, what you can reach without asking, what needs the human, what is impossible, and the two-attempt rule |
| `agents/_shared/channels.md` | how channels are read and written, and why `status.json` is a state file rather than a third channel |
| `agents/_shared/tasks.md` | the task board and the three gates |
| `agents/_shared/evidence.md` | a green you have never seen go red is not evidence |

The last one is the expensive rule and the one that pays fastest. Closing
something on the strength of a test means breaking the mechanism the test
watches, seeing the row go red **for the reason you named**, putting it back,
and saying so in one line. If breaking the mechanism changes nothing, that is
the finding: the rows never touched it.

The QA report carries a three-line signature — what was checked (the command
and its actual numbers), what was concluded (including what is still open), and
what was falsified.

## Testing hats itself

```bash
bash tests/run.sh
```

No framework to install. Known gaps live in `tests/KNOWN-GAPS.md`: they print
on every run, they do not fail it, and they DO fail it the day they start
passing — so a gap cannot be closed silently or forgotten.

## Why

When one AI writes code AND tests, it tests its own assumptions -- same blind spots. By splitting into roles with separate contexts and separate prompts, the QA tests *requirements* while the Developer implements *solutions*. Neither can see the other's code.

The Developer can't read test source -- only test results via `.hats/shared/qa-report.md` and `bash .hats/qa/run-tests.sh`. The QA can't read implementation -- it writes tests from specs alone. Gherkin `.feature` files are the contract between roles: readable by you, parseable by the AI.

## License

MIT
