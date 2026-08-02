# Known gaps

A gap is a promise hats makes that its code does not keep. Each one is a live
row in the test suite: it prints on every run, it does **not** fail the suite,
and it **does** fail the suite the day it starts passing — so a gap cannot be
closed silently, and cannot be forgotten either.

Registered with `gap <id> <assertion>` in the test files.

---

## G1 — the QA can read source code

**Promised** (README, verbatim):

> Permissions are enforced by hooks — the Developer literally *can't* read
> tests, and the QA *can't* read source code.

**Actual:** `scripts/read-guard.sh` sets `qa) BLOCKED=""`. The developer half is
enforced (`developer) BLOCKED=".hats/qa/"`), the QA half is not. QA can read
every line of the implementation.

**Why it matters.** This is not a detail — it is the thesis. The whole point of
splitting the roles is that QA writes tests from the SPEC, so it cannot inherit
the implementation's blind spots. A QA that has read the code tests what the
code does, which is exactly the failure mode hats exists to prevent, wearing a
badge that says it has been prevented.

**Why it is not fixed in the same breath as it was found.** Closing it is a
behaviour change for every existing project, and the blast radius needs a
minute's thought rather than a reflex:

- QA legitimately needs *some* things at the project root — `package.json` to
  know the runner, config to know ports, `setup.md` for how to start the app.
  A blanket block on everything outside `.hats/` would break test generation
  on day one.
- So the fix is a list, not a switch: block source directories, allow the
  handful of files QA must see, and let `stack.md` / `setup.md` carry anything
  else it needs — which is what those files are for.

Belongs to its own step, with its own falsification (block it, watch a QA run
fail for the stated reason; unblock the allow-list entry, watch it pass).

**Row:** `tests/read-guard.test.sh` — «qa cannot read source (README's central
claim)».

---

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
