# Tasks: what is being worked on

*Read this before your role file. It applies to every role.*

Specs say what must be **true**. Tasks say what someone is **doing**. Until v5
hats had only the first, so «what is in flight right now, and what was closed
yesterday and why» was not answerable from the repository — it lived in
whatever session happened to be open, and died with it.

A task is a folder, and it is in git.

```
.hats/tasks/
  INDEX.md                          generated — the whole board, one table
  0042-runner-flaky-on-login/
    task.md                         header + the ask
    understanding.md                written when work starts
    resolution.md                   written when it closes
```

`task.md` opens with a header both a human and the guard can read:

```
status: in_progress      open | in_progress | blocked | done
priority: 1              1 is hottest
owner: developer
spec: @auth              the .feature tag this serves, if any

# Runner is flaky on login

What needs doing, in the words of whoever asked for it.
```

## The three gates

These are enforced by the hook, not requested here. You will be refused, and
the refusal names the file you are missing.

1. **`open -> done` is refused.** A task closes only after being in work. A
   task that was never in work was never understood, and «done» about it means
   nothing anyone can rely on.
2. **`in_progress` needs a non-empty `understanding.md`.** Say what you think
   the job is, in your own words, BEFORE doing it. Afterwards the same sentence
   is a summary of what happened, which is a different and much easier thing to
   write — and worth far less.
3. **`done` needs a non-empty `resolution.md`.** What you checked, and what you
   concluded. Not «fixed it». The next person's question is «how do you know»,
   and this is where the answer lives.

Editing the body of a task, writing `understanding.md`, writing
`resolution.md` — none of that is gated. Only the status is.

## Doing it

```bash
H="$HATS/scripts/task.sh"

bash "$H" new "Runner is flaky on login" 1 developer @auth   # the Manager's job
bash "$H" next                                                # the hottest open task
# ...write understanding.md...
bash "$H" status .hats/tasks/0042-runner-flaky-on-login in_progress
# ...do the work, write resolution.md...
bash "$H" status .hats/tasks/0042-runner-flaky-on-login done
```

Editing `task.md` by hand works too and is gated identically — the helper is a
convenience, not the fence.

## The queue

**When a session is running** — the human said «go», «carry on», «what's left» —
take tasks by priority, one after another, without asking between them.

**When they asked for one specific thing** — do that thing, then ASK whether to
carry on with the rest. Their specific ask is not permission to empty the
board.

A task in `blocked` is not yours to carry: say who you told and what you need,
in the channel that goes to them (see `agents/_shared/pipeline.md`).
