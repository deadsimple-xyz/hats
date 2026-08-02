# Known gaps

A gap is a promise hats makes that its code does not keep. Each one is a live
row in the test suite: it prints on every run, it does **not** fail the suite,
and it **does** fail the suite the day it starts passing — so a gap cannot be
closed silently, and cannot be forgotten either.

Registered with `gap <id> <assertion>` in the test files.

---

## G1 — the QA can read source code — **CLOSED in 5.0.0**

The README sold it as the product: «the Developer literally can't read tests,
and the QA can't read source code». Only the first half was ever enforced —
`read-guard.sh` had `qa) BLOCKED=""`, an empty list. QA could read every line
of the implementation.

Not a detail: it is the thesis. Roles are split so QA writes tests from the
SPEC and cannot inherit the implementation's blind spots. A QA that has read
the code tests what the code does — the exact failure the split exists to
prevent, wearing a badge that says it was prevented.

**Closed with an ALLOW-list, not a block-list**, because «the implementation»
has no fixed name — it is whatever a project calls its directories. So for QA
the project root is closed, and a short list is opened: manifests
(`package.json`, `Package.swift`, `go.mod`, …), test configs, `Makefile`,
`docker-compose.yml`, `tsconfig.json`, `.env.example`, `README.md`. Everything
under `.hats/` is untouched — specs, stack, designs, its own tests, the
channels.

Anything else QA needs belongs in `stack.md` or `setup.md`, which is what those
files are for. The refusal says so, and says how to widen the list.

**Escape hatch, on purpose:** `.hats/qa/read-allow`, one glob per line, widens
it per project. A fence with no gate gets torn down; a fence with a gate that
has to be written down stays up.

**Rows:** `tests/read-guard.test.sh` — the refusal on source (by `Read` and by
`Grep`), twelve manifests and configs that stay open, the escape hatch opening
exactly what it lists and nothing else, and the three other roles losing
nothing. Four falsifications: fence removed → 7 red; allow-list emptied → 12;
escape hatch ignored → 1; `.hats/` swept into the block → 3.

## G2 — a role can take off its own fence in one write

**Sequence, entirely within the rules as written:**

1. role is `qa`; a write to `src/` is refused;
2. `qa` writes `developer` into `.hats/role` — permitted by rule 1 of
   `guard.sh`, unconditionally, because roles must be able to switch;
3. the same write to `src/` now passes.

**Why the door exists.** It is the same door the human uses. `/hats:qa` is a
skill whose instruction is «write `qa` to `.hats/role`» — the switch is
performed BY the agent, so the file must be writable by the agent. The fence
cannot tell the operator from the thing being fenced.

**What this does and does not mean.** It is not an exploit; nothing is hiding.
It means the role system is a convention with a mechanism attached, not a
mechanism. Every guarantee in the README holds exactly as long as the model
follows the instruction not to relabel itself — which is the shape this project
already names elsewhere: *an instruction is not a mechanism*.

**Decided (2 August): environment plus audit.** `HATS_ROLE` pins the role where
the fence must be real — autopilot, per-role spawned sessions, CI — and a write
to `.hats/role` under it is REFUSED, with a refusal that names the pin instead
of failing silently. Where a human is at the wheel the door stays open, because
one session per role is a real cost to pay every day for a risk that shows up
rarely. What changed is that it is no longer invisible: every switch appends to
`.hats/role-history` with the session, the old role and the new one — and that
audit is deliberately NOT behind the debug flag, because the day you want it is
the day nobody thought to turn logging on.

**The options as they were weighed:**

- **`HATS_ROLE` in the environment.** Strongest: a process cannot rewrite the
  env its parent gave it, so the position of the fence moves outside the reach
  of the thing being fenced. Cost: one session, one role — mid-session
  switching goes away, and per-role subagents all inherit the parent's value.
- **Handoff rules.** Permit only the switches the pipeline actually needs and
  refuse the rest (notably `qa` → `developer`, the pair that must never see
  each other). Cheap, partial, and it fights the README's «talk to any role at
  any time».
- **Audit only.** Log every switch with its session; let `doctor` and the tests
  show «the role flipped 47 times today». Prevents nothing, reveals everything.

**Row:** `tests/role-store.test.sh`.

---

## G3 — the role is ambient: two sessions in one repo share one fence  — CLOSED

`.hats/role` is per-DIRECTORY. Two Claude Code sessions in the same repo — one
per product, a subagent beside its parent, an autopilot beside a human — read
and write the same byte. The second session's switch silently re-aimed the
first session's fence, and neither was told.

**Closed.** Hooks receive `session_id` (verified on a live log line,
`"sid":"8de5645b"`, matching the running session — not taken on trust). The
guard now records each switch against `.hats/sessions/<session_id>`, and
`hats_role` in `scripts/common.sh` resolves: `HATS_ROLE` → this session's file →
`.hats/role`.

The tie-breaker between the last two went wrong twice before it went right, and
both wrongs are worth keeping written down:

1. **«newest file wins»** handed the fence back to whoever switched last —
   every switch rewrites `.hats/role` too, so the shared file was always newest.
   That was the original bug wearing a fix.
2. It also made the rule a race against filesystem timestamp granularity. A
   falsification caught it: mutating the tie-breaker changed no row, because
   both writes landed in the same second and the branch was never reached. The
   test was passing through a door it never opened.

**CONTENT decides now, and deterministically.** `.hats/role` holds what we
hold → ours. It holds what another session holds → that session switched, ours
stands. It holds a value no session claims → a human wrote it by hand, theirs
wins.

**Known limit, pinned by a row:** a human hand-writing exactly the value some
other live session already holds is indistinguishable from that session
switching, and we keep ours. Timestamps could not have told them apart either.

**Rows:** `tests/role-store.test.sh`, five falsifications (isolation off,
other-session detection inverted both ways, env pin removed, env demoted).

---

## G3 — every fence is a Write/Edit/Read fence, and Bash walks around all of them

Found by a QA agent on its first live turn under 5.0.0, unprompted, while
explaining what had got in its way:

> «хук матчит только Read|Glob|Grep, Bash не гарден вообще — забор для QA
> фактически совещательный»

Verified immediately, and it is exactly right:

| through Bash | result |
|---|---|
| `cat src/counter.ts` as QA | allowed |
| `echo x > src/counter.ts` as QA | allowed |
| `echo done > .hats/tasks/*/task.md` | allowed — all three task gates skipped |

`hooks.json` matches `Write|Edit` and `Read|Glob|Grep`. Bash is matched only by
the debug logger, which never blocks. So every guarantee in this project holds
for a role that uses the file tools, and evaporates for one that uses a shell.

**Why it is not simply fixed by adding `Bash` to the matcher.** A command line
is not a path. `cat a b c`, `sh -c '…'`, a heredoc, `find -exec`, a Makefile
target, `npm test` — deciding what a command will touch means parsing a shell,
and a parser that is 95% right is a fence with a hole whose shape nobody knows.
Worse, roles need Bash constantly and legitimately: `run-tests.sh`, `git`,
`npm`, the helpers this plugin ships.

**What is worth doing, in order:**

1. **Say it out loud.** The README implies the fences are absolute. They are
   absolute for the file tools. That sentence belongs in the README, because a
   guarantee people misread is worse than one they know the edges of.
2. **Cheap, narrow interception** for the shapes that are unambiguous and
   actually observed: a redirect into a path the role may not write
   (`> .hats/qa/...`), a bare `cat`/`head`/`tail` of a blocked directory. Not a
   parser — a handful of patterns that fail OPEN on anything they do not
   understand, so the fence never blocks legitimate work it merely fails to
   recognise.
3. **Audit before enforcement.** Log Bash commands that touch blocked paths for
   a while, look at what real roles actually do, and only then decide what to
   refuse. Guessing at this in advance is how a discipline becomes a jam — this
   project has paid for that once already.

**(1) and (3) are DONE (2026-08-02).** The README now names the edge, and
`scripts/bash-audit.sh` is hooked on `Bash`: it records a line in
`.hats/bash-audit.jsonl` when a role's command names a directory that role
cannot touch through the file tools, distinguishing a redirect (write-shaped)
from anything else (read-shaped). **It never refuses.** Ordinary work —
`npm test`, `git status`, the role's own runner — leaves no line, or the log is
noise nobody reads.

The vocabulary is deliberately the SAME as the guards', so the audit measures
that rule rather than offering a second opinion about it. And it is not behind
the debug flag: the day you want this log is the day nobody thought to turn
logging on.

**(2) is still open, and stays open until there is data.** What to refuse
should come from what real roles actually reach for, not from what I can
imagine tonight. Look at `.hats/bash-audit.jsonl` after a few real days; the
shapes that appear and are never legitimate are the candidates, and each one
gets its own row and its own falsification before it blocks anything.

**Rows:** `tests/bash-audit.test.sh` — six commands proving it never refuses
and says nothing to the role, the three live-observed shapes being recorded
with role and reason, ordinary work leaving no line, one line per command
rather than one per matching directory, and an unknown role left alone.
Four falsifications: recording removed → 5 red; write/read no longer
distinguished → 2; the audit made to refuse → 6; recording everything → 4.

Still true, and still the point: **a row asserting «Bash is unguarded» is not
written**, because it would lock the defect in as intended behaviour.
