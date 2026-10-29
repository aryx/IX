# apps/pim: mini-pim

A suite for organizing a life: mail, calendar, people, tasks, notes
and money, one store, each referring to the others. The plan:
[`plan_pim.md`](../../docs/plans/plan_pim.md); its mail,
[`plan_mail.md`](../../docs/plans/plan_mail.md), the first part.

So far, plan_mail.md's stages 1 to 5: the mail's formats, sending by
SMTP and reading by IMAP, with Gmail or with mini-maild on this
machine, what is read kept in the suite's store (plan_pim.md's stage
2 begun), and a window over it with Gmail's keys. Their tests:
`tests/`, the unit tests (dune's), `session.sh`, mini-pim's commands
against mini-maild, and `frames.sh`, its window's (`make test`'s two
"mini-pim").

    bin/mini-pim user=... [server=host:port] [plain]
                       the window: j k move, o open, u back, e archive,
                       / search, Tab Inbox or All Mail, g get the mail
    bin/mini-pim [-s host:port] [-plain] [-u user] command
        send file      the message in a file sent
        list [-n 20] [-q search] [-m mailbox]
                       the newest conversations, a line each
        read uid       a message, marked read
        archive uid... out of the Inbox
        -offline       list and read from the store, no server
                       by default with Gmail (smtp.gmail.com:465,
                       imap.gmail.com:993, TLS), the app password the
                       store's file password (mode 600) or the first
                       line of standard input
    bin/mini-maild [-p port] [-i port] [-d domain] [-a name] spool
                       mail for its domain taken by SMTP and read by
                       IMAP, on 127.0.0.1, a file a message:
                       spool/<user>/<uid>; -a All Mail's name

    mail/Mail          a message (RFC 5322): fields, folding,
                       addresses, dates, Message-IDs
    mail/Mime          its parts and encodings (RFCs 2045-2047), text
                       made UTF-8
    mail/Mail_thread   conversations, by Zawinski's threading
    mail/Smtp          sending (RFC 5321): the client, a pure machine
    mail/Smtp_server   the server's machine, mini-maild's
    mail/Imap          reading (RFC 3501, Gmail's extensions): its
                       responses read, literals and all; the client
    mail/Imap_server   the server's machine, mini-maild's
    mail/Lines         a connection of lines, over TCP or TLS, that
                       drives those machines
    mail/Mail_text     a message as the text to read: HTML only made
                       text (browsers/html's Line_mode), attachments
                       said
    mail/Mail_item     a message as an item of the store
    mail/Mail_sync     the server and the store: what the commands and
                       the window do
    mail/Conversations messages as conversations, the words a list shows
    window/Mail_window the mail in a window
    store/Item         an item: name: value lines, Mail's syntax,
                       stamped
    store/Items        the store: a directory, a file an item
                       ($PIM_STORE, ~/.ix-pim, $home/lib/pim), and the
                       mail's cache

Each copied `.ml` says in one line where it comes from and what
changed (`ix: the author's playground's <path>; ...`). The numbers
below are `scripts/playground_copies.sh apps/pim`'s, against the
playground at `90c4b4b6` (2026-10-27).

## What was copied

The playground's `libs/networking/mail/` but `Mbox` (the cache is to
be a file per message, plan_mail.md), and `protocols/Smtp`: 8 files,
1,273 lines there (813 of `.ml`), 1,295 here (829 of `.ml`); their
tests, `Unit_mail` less its mbox test; and of `unix/Mail_server` (253
lines) its SMTP half, `Smtp_server` (99), with neither its sockets
(the playground's `Server`, over WebSocket too) nor POP3.

## What changed

- **What mini-ml takes**: `Option.value`'s `~default` and
  `Option.fold` a `match`; `Mime.content_type`'s optional `?digest`
  and `Smtp.client`'s `?auth` said by every caller.
- **The server a machine**: `Mail_server`'s SMTP counter, which wrote
  to its sockets, is `Smtp_server.step`, a line in, the reply and the
  message taken out, as `Smtp`'s client; it takes AUTH PLAIN (any
  password), as the client sends it to Gmail.
- **The charsets**: the playground read Windows-1252 and ISO-8859-15
  as Latin-1. Real mail has Windows-1252's curly quotes, dashes and
  euro in the bytes Latin-1 gives to control characters, often labelled
  ISO-8859-1; so ISO-8859-1 is read as Windows-1252 (WHATWG's Encoding,
  as browsers), and ISO-8859-15 by its eight characters of its own.
- **The interfaces**: what they named that ix has not (`Ics`, `Pop3`,
  TinyEudora's `Our_mail`) said so.

## What is ix's own

The charsets' tables in `Mime` and their test; `store/`,
`window/`, `Mail_item`, `Mail_sync`, `Conversations`; `Imap` and
`Imap_server` (the playground had POP3 only); `Lines` (the
playground's `Transport` was its kind, over its own TLS and
WebSocket); the two programs, `Pim.ml` and `Maild.ml` (after the
playground's tiny_maild, a file a message instead of an mbox, IMAP for
its POP3, one client at a time as mini-httpd); `Unit_smtp_server`,
`Unit_imap`, `Unit_items`, `session.sh`, `frames.sh` (the window's
frames, recorded against mini-maild), `Test.ml`.
