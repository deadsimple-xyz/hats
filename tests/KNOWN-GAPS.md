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
