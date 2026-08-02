# Channels: how to read them and how to write them

*Read this before your role file. It applies to every role.*

A channel is how one role speaks to another. There is one per direction:
`manager2team`, `cto2team`, `designer2team`, `qa2dev`, `dev2qa`, `qa2designer`,
`dev2designer`.

## The shape

A channel is a **directory**, one file per entry:

```
.hats/shared/qa2dev/
  INDEX.md                        newest first — read this
  0246-2026-07-30-qa.md           one entry
  0245-2026-07-30-qa.md
  ...
  HEAD.md                         the channel's title block
  ARCHIVE.md                      everything as it was before migration
```

**Why it is not one file.** It used to be, and it silently broke. A channel is
appended at the bottom, `Read` returns the first 2000 lines, and you are told
never to `tail`. On a middling project that meant a role saw entries 40–42 of
40–51: nine out of fifteen were read by nobody, ever. It went wrong at 138 KB,
which is most projects by their second month. One entry per file makes the
newest reachable instead of theoretically present.

Some projects have not migrated yet. If you find `qa2dev.md` and no `qa2dev/`,
the flat file is still the channel — read it, and say once that
`bash .hats/../scripts/channel.sh split .hats/shared/qa2dev.md` would fix it.

## Reading

1. **Read `INDEX.md`.** It is newest-first, one entry per line, with the first
   real line of each body. It grows with the NUMBER of entries, never with
   their size — a 50 KB entry costs it under 300 bytes.
2. **Read only the entries you actually need**, by filename, with `Read`.
   Usually that is everything since you last looked, which is the top of the
   index down to the entry you already know.
3. **Never read the whole directory** to «catch up». If the index is not enough
   to decide which entries matter, the entries are being written badly — say so
   in the channel rather than reading a megabyte.

`ARCHIVE.md` is history that has already been split into the entries beside it.
Reading it means reading everything twice. Leave it alone unless you are
looking for something specific and old.

## Writing

Use the helper. It numbers the entry, dates it, names you, and refreshes the
index:

```bash
echo "your message body" | bash "$HATS_PLUGIN/scripts/channel.sh" \
  append .hats/shared/qa2dev QA
```

Writing an entry file directly with `Write` also works and the guard allows it,
but then the index is stale until someone regenerates it (`channel.sh index
<dir>`), and a stale index is exactly the failure this design exists to remove.

**One entry, one subject.** The index shows one line per entry; an entry that
covers four unrelated things is invisible in it no matter how well written.

## Ownership

A channel's name says who may write it, and the guard enforces it: `qa2dev`
belongs to QA, `dev2qa` to the Developer, `manager2team` to the Manager, and so
on. That has not changed with the shape. What you may **read** has not changed
either.

Threads (`.hats/shared/threads/*.md`) are the exception and stay as they are:
any role may append to any thread. Use a thread when the exchange is a
conversation; use a channel when it is an announcement.
