# apps/pim: mini-pim

A suite for organizing a life: mail, calendar, people, tasks, notes
and money, one store, each referring to the others. The plan:
[`plan_pim.md`](../../docs/plans/done/plan_pim.md); its mail,
[`plan_mail.md`](../../docs/plans/plan_mail.md), the first part.

The plan is done (its stages 1 to 7; what is left in its Status):
the mail, sent by SMTP and read by IMAP, with Gmail or with mini-maild
on this machine; the store of items, stamped and linked both ways;
the window, a Home and its six views, Mail, Calendar, People, Tasks,
Notes, Money; Google's calendars and contacts read. Its manual pages:
pim(1) and maild(1) (`docs/man/1/`), what follows the short of them.
Their tests: `tests/`, the unit tests (dune's), `session.sh`,
mini-pim's commands against mini-maild, and `frames.sh`, its
window's (`make test`'s two "mini-pim").

    bin/mini-pim [user=...] [server=host:port] [smtp=host:port] [plain]
            [view=mail|calendar|people|tasks|notes|money]
                       the window, on Home: a tile a view (m c p t n
                       b, or a click), the day's events, what is late
                       or due today, unread mail from people, d the
                       day's page; in a view, the Pim menu and
                       Ctrl+0 to 6 (Home, Mail, Calendar, People,
                       Tasks, Notes, Money), the switcher at the
                       sidebar's foot; Ctrl+E (/ on Home) searches
                       them all, Enter opens what is found
                       Mail: j k move, o open, u back, e archive,
                       / search, Tab Inbox or All Mail, g get the mail,
                       c compose, r a f reply, to all, forward,
                       z snooze, t a task, p the sender to People,
                       i an invitation to the Calendar; the days,
                       amounts and addresses of a message underlined,
                       x to keep one (an event, a bill, a contact);
                       Mail > Turn On the Screener: the Imbox, the
                       Screener (y in, n out), the Feed, the Paper
                       Trail, a sender's decision kept (HEY's)
                       Calendar: c an event in a line ("lunch with
                       alice tue 12:30", "standup every monday
                       9h30"), j k next and previous, t today, d w m
                       a day, a week, a month, the arrows the day,
                       g Google's calendars fetched (Calendars)
                       Tasks: n a task in a line ("pay the rent by
                       friday"), x done, d its day, z snooze, o open
                       (a message in Mail), s someday, Tab To Do
                       (GTD's inbox first), Someday, Done; a repeating
                       task done makes its next
                       People: n a person (Dan <dan@ix>), o their
                       page (what links to them, the money paid them,
                       the mail with them; o opens one), c write to
                       them
                       Notes: n a note, d today's page, the text with
                       [[id]] links, what it names and what names it
                       under it (a click opens one), Tab Notes or Days
                       Money: an account's register, n a line in its
                       columns (QuickFill), c cleared, r reconcile
                       (the difference explained), f finish, Tab the
                       next account, then the month's categories,
                       then the envelopes (YNAB's), a assigns money
    bin/mini-pim [-s host:port] [-plain] [-u user] command
        send file      the message in a file sent
        list [-n 20] [-q search] [-m mailbox]
                       the newest conversations, a line each
        read uid       a message, marked read
        reply [-all] uid, forward uid
                       a draft printed, to edit, then send
        archive uid... out of the Inbox
        snooze uid words
                       the conversation out of it until a day (monday,
                       in 3 days), back in it that day
        search query   the store's items, Gmail's syntax: from:alice
                       is:task label:travel before:2026-12-01 -word
        show id        an item, and its links both ways (a person:
                       the mail with them)
        contact uid, people
                       the sender a contact; the address book
        event words    an event from a line, as the window's c
        import file.ics
                       an iCalendar file's events
        import file.vcf
                       contacts, Google Contacts' export (vCard)
        sync           Google's calendars fetched, by their secret
                       addresses in ~/.ix-pim/calendars (mode 600);
                       with -u the Inbox
        today          the day: its events, the tasks late and due,
                       the mail back from a snooze, unread mail from
                       people, the day's page
        remind [-every 5]
                       runs: each reminder as its minute comes (an
                       event 10 minutes before, remind: says), a line
                       and notify-send's notification; every 5 minutes
                       the calendars fetched, with -u the mail, what
                       is new from people said
        import file.qif [-a account], register [-a account], balance
                       a bank's lines, those not there yet; an
                       account's register; every account's balance
        budget, assign envelope amount
                       the envelopes (YNAB's), what is left to assign;
                       money to one (assign Groceries 400)
        add id [name=value...], set id name=value...
                       an item made (task:pay-rent due=2026-11-05),
                       its fields changed
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
    mail/Mail_compose  a message written: reply, reply to all,
                       forward, a draft as an item, the message sent
    mail/Mail_item     a message as an item of the store
    mail/Mail_sync     the server and the store: what the commands and
                       the window do
    mail/Conversations messages as conversations, the words a list shows
    Pim_store          the terminal's commands over the store: search,
                       show, add, set, event, import, today, money
    window/Pim_window  the window: the suite, Home, going from view to
                       view
    window/Mail_window the mail: its keys, its menus, the server
    window/Mail_model  its state, read from the store
    window/Mail_view   its picture
    window/Found_window
                       what a message says kept: a day an event, an
                       amount a bill, an address a contact
    window/Search_window
                       one search over every view, the items found by
                       the view they open in
    window/Tasks_window
                       the tasks to do and done, captured in a line
    window/People_window
                       the address book, a person's page
    window/Notes_window
                       notes and days, their links both ways
    window/Calendar_window
                       a day, a week, a month of events
    window/Money_window
                       an account's register, reconciling, a report
    window/Pim_look    what the views share: menus, letters, rows
    store/Item         an item: name: value lines, Mail's syntax,
                       stamped
    store/When         a day typed as words, English and French
    store/Events       events: their occurrences in days shown, an
                       invitation's made items
    store/Capture      a line made an event: its day, time, repeat,
                       people
    store/Today        the day: events, tasks late and due, bills,
                       mail from people, the day's page (Home and
                       mini-pim today)
    store/Detect       the days, amounts and addresses in a text
    store/Envelopes    YNAB's envelopes: assigned, spent, available,
                       what is left to assign
    store/Screen       HEY's Screener: where a sender's mail goes
    store/Calendars    Google's calendars read, by their secret
                       addresses, a fetch a mirror
    store/Vcard        vCard files read: Google's and Apple's
                       contacts
    store/Remind       when a reminder is said: an event's minutes
                       before, a task's remind:
    store/Books        the money: double entry, postings in items, an
                       account's register, a bank's lines matched
    money/Money        amounts in cents, and in words
    money/Ledger       a register's lines, QuickFill, categories
    money/Reconcile    a register against a statement, the difference
                       explained
    money/Qif          Quicken's interchange format
    time/Recur         a repeating event's rule (iCalendar's RRULE)
    time/Ics           iCalendar files, read and written
    time/Zone          the local time: zoneinfo's TZif files, POSIX's
                       rules, Plan 9's /env/timezone
    store/People       the address book, filled from the mail, BBDB's
                       way; the mail with a person
    store/Search       a search over every item, Gmail's syntax
    store/Links        links both ways: the ids an item names (in its
                       fields, [[ ]] in its text), and the items
                       naming it
    store/Items        the store: a directory, a file an item
                       ($PIM_STORE, ~/.ix-pim, $home/lib/pim), and the
                       mail's cache

Each copied `.ml` says in one line where it comes from and what
changed (`ix: the author's playground's <path>; ...`). The numbers
below are `scripts/playground_copies.sh apps/pim`'s, against the
playground at `90c4b4b6` (2026-10-27).

## What was copied

For the calendar (plan_pim.md, stage 3): the playground's
`libs/core/time/Recur` and `appkits/pim/Ics`, and their tests
(`Unit_recur`, `Unit_ics`); for the money (stage 6), its
`appkits/money` (`Money`, `Ledger`, `Reconcile`, `Qif`) and their
test (`Unit_money`); mini-ml's changes said in each file's
first lines (an optional argument said by every caller, a polymorphic
variant a type, `Option.value` and `Option.fold` a match).

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
`window/`, `time/Zone`, `Mail_item`, `Mail_sync`, `Conversations`; `Imap` and
`Imap_server` (the playground had POP3 only); `Lines` (the
playground's `Transport` was its kind, over its own TLS and
WebSocket); the two programs, `Pim.ml` (with `Pim_store`) and `Maild.ml` (after the
playground's tiny_maild, a file a message instead of an mbox, IMAP for
its POP3, one client at a time as mini-httpd); `Unit_smtp_server`,
`Unit_imap`, `Unit_items`, `session.sh`, `frames.sh` (the window's
frames, recorded against mini-maild), `Test.ml`.
