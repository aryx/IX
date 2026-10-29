# apps/pim: mini-pim

A suite for organizing a life: mail, calendar, people, tasks, notes
and money, one store, each referring to the others. The plan:
[`plan_pim.md`](../../docs/plans/plan_pim.md); its mail,
[`plan_mail.md`](../../docs/plans/plan_mail.md), the first part.

So far, plan_mail.md's stage 1: the mail's formats, in `mail/`, with
their unit tests (`tests/`, dune's: `make test`'s "mini-pim: unit
tests"). No program yet.

    mail/Mail         a message (RFC 5322): fields, folding, addresses,
                      dates, Message-IDs
    mail/Mime         its parts and encodings (RFCs 2045-2047), text
                      made UTF-8
    mail/Mail_thread  conversations, by Zawinski's threading

Each copied `.ml` says in one line where it comes from and what
changed (`ix: the author's playground's <path>; ...`). The numbers
below are `scripts/playground_copies.sh apps/pim`'s, against the
playground at `90c4b4b6` (2026-10-27).

## What was copied

The playground's `libs/networking/mail/` but `Mbox` (the cache is to
be a file per message, plan_mail.md): 6 files, 981 lines there (651
of `.ml`), 1,007 here (671 of `.ml`); and their tests, `Unit_mail`
less its mbox test.

## What changed

- **What mini-ml takes**: `Option.value`'s `~default` and
  `Option.fold` a `match`; `Mime.content_type`'s optional `?digest`
  said by every caller.
- **The charsets**: the playground read Windows-1252 and ISO-8859-15
  as Latin-1. Real mail has Windows-1252's curly quotes, dashes and
  euro in the bytes Latin-1 gives to control characters, often labelled
  ISO-8859-1; so ISO-8859-1 is read as Windows-1252 (WHATWG's Encoding,
  as browsers), and ISO-8859-15 by its eight characters of its own.
- **The interfaces**: what they named that ix has not (`Ics`, `Pop3`,
  TinyEudora's `Our_mail`) said so.

## What is ix's own

The charsets' tables in `Mime` and their test, `Test.ml`.
