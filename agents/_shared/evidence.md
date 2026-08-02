# Evidence: what «it works» has to carry

*Read this before your role file. It applies to every role.*

## A green test is not evidence until you have seen it go red

This is the most expensive rule here, and the one that pays for itself fastest.
A test that passes tells you two things are consistent. It does not tell you
the test could ever have failed — and a test that cannot fail is worse than no
test, because it occupies the place where a real check would have gone and
reports success from it.

So: when you close something on the strength of a test,

1. break the mechanism the test is supposed to be watching — delete the guard,
   invert the condition, empty the list;
2. run it, and **watch the row go red for the reason you named**;
3. put it back, run it again, watch it go green.

Then say what you broke and what went red. One line:

> *Falsified: removed the trailing-slash check in the path match → 4 rows red
> («developer cannot Grep the qa dir» among them). Restored, green.*

**A falsification that changes nothing is the finding.** If you break the
mechanism and every row still passes, you have just learned that the rows never
touched it. That is not an inconvenience to route around — it is the bug, and
it was invisible a minute ago.

Two shapes this catches, both seen in practice:

- the row never reached the branch it claimed to test (a condition earlier in
  the function short-circuited it);
- the row asserted something that was true for an unrelated reason.

## What a report owes

A report is not prose about effort. Whatever the shape of your role's report,
it carries two things or it is not a report:

- **What was checked** — the command, the count, the file, the case. Not
  «tested thoroughly».
- **What was concluded** — including what is still open. «All green» over five
  green suites and one that was never run is a false statement with a true
  sentence inside it.

If you could not check something, say that instead of implying you did. An
unchecked thing said plainly costs one line; found later, it costs the trust in
every line beside it.

## Numbers, verbatim

When you have a number, give the number. `2641 tests, 73 skipped, 1 failure`
tells the next person where they stand. «Tests are passing» does not, and stops
being true without anyone noticing.

When you quote output, quote it — do not paraphrase a failure into something
tidier. The exact message is what the next person will search for.

## Do not report as done what you have not run

The most common way this goes wrong is not lying, it is momentum: the change is
obviously right, the suite is slow, the work is finished in your head. Run it.
If you did not run it, the sentence is «written, not yet run», and that is a
perfectly good thing to say.
