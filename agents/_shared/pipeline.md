# The route: who does what, and what happens after you

*Read this before your role file. It applies to every role.*

Five roles, one human. You see one station; this is the whole line.

```
   human
     |  says what they want
     v
  MANAGER    -> .hats/shared/specs/*.feature        what must be true
     |          .hats/tasks/<id>/task.md            what someone must do
     v
  DESIGNER   -> .hats/shared/designs/               what it looks like
     v
  CTO        -> .hats/shared/stack.md, setup.md     what we build it with
     v
  QA         -> .hats/qa/                           tests that must fail first
     |          .hats/shared/qa-report.md           what failed, in plain words
     v
  DEVELOPER  -> the project root                    code that makes them pass
```

Nothing in that arrow is a permission to skip a station: if the stack is known,
the CTO station is simply already done. Any role may be talked to at any time.

## What each station owes the next one

| You are | You may write | The next station cannot start without |
|---|---|---|
| Manager | `shared/specs/`, `manager2team`, `.hats/tasks/` | a spec with acceptance criteria |
| Designer | `shared/designs/`, `designer2team` | screens for the behaviour in the spec |
| CTO | `stack.md`, `setup.md`, `api.md`, `cto2team` | how to run the thing |
| QA | `.hats/qa/`, `qa-report.md`, `test-contract.md`, `qa2dev` | tests that fail for the stated reason |
| Developer | the project root, `setup.md`, `api.md`, `dev2qa` | nothing — you are the last station |

The guard enforces this. A refusal is not a bug report; it means the thing you
are writing belongs to someone else, and the channel to that someone is open.

## What you can reach, and what you cannot

**REACHABLE — do it, do not ask.** Reading anything you are allowed to read,
running the test suite, running the project, writing in your own areas, asking
another role in its channel, appending to a thread.

**NEEDS THE HUMAN — say exactly what you need and why, in one line.**
Credentials and keys. Anything that spends money. Anything that touches
production. Installing system-level tools. A decision between options that are
all technically fine — that is a preference, and preferences are theirs.

**IMPOSSIBLE — say so plainly and stop asking.** You cannot see another role's
private workspace. QA cannot make the Developer read a test file, and the
Developer cannot read one. You cannot start another role's session; you can
only leave a message and tell the human which command to run.

**TWO ATTEMPTS.** If something does not work twice, stop and say what you tried
and what happened. A third attempt at the same thing is a way of not saying
you are stuck.

**DO NOT ASK THE HUMAN TO RUN COMMANDS YOU CAN RUN.** If you can run it, run it.

## When you are stuck

Escalate along the line, not sideways and not in silence:

- Developer stuck on a test or a spec → QA (`dev2qa`), and if it is a stack
  question → CTO via `dev2qa`.
- QA stuck on ambiguous behaviour → Manager (`qa2dev` is for the Developer;
  use a thread or `qa2designer` for design questions).
- Any role stuck on what the product should do → Manager.
- Manager stuck → the human. That is the only escalation that leaves the team.

An escalation that reaches nobody is the failure this section exists to
prevent. Name the blocker, name what would unblock it, and say who you told.

## What «done» means

Done is not «I wrote the code». Done is:

- the tests that pin the behaviour are green, **and**
- you have shown they can go red for the stated reason — break the mechanism,
  watch the row fail, put it back. A green that was never seen to fail is not
  evidence, it is a hope with a checkmark.
- what you checked and what you concluded is written where the next station
  reads it, not only in the chat.
