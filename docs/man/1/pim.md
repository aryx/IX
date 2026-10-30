\title{pim}{1}{apps}

# NAME
pim – mail, calendar, people, tasks, notes and money, one store

# SYNOPSIS
**pim** \[ *name*`=`*value* ... ]

**pim**
[ **-s** *host*`:`*port* ]
[ **-plain** ]
[ **-u** *user* ]
[ **-offline** ]
[ **-today** *day* ]
*command* ...

# DESCRIPTION
*Pim* is a suite for organizing a life: its mail, read and written with
Gmail; a calendar; the people one knows; what there is to do; notes;
money. They are not six programs but six views of one store, where an
item is a mail, an event, a task, a person, a note or a money line, or
several at once (a mail one has to answer is a task; a bill is a task
with money in it), and where each item can name others, which then list
it. With no *command*, *pim* is a window; with one, it is the same store
from a terminal.

## The window
It opens on Home: a tile for each view, and Today under them, the day's
events, the tasks late (in red) and due, what comes back from a snooze,
the unread mail from people of the address book, and the first lines
of the day's page. `m c p t n b` or a click opens a view, `d` the day's
page, `/` the search. In a view, the first menu is the suite's (Pim),
the others the view's, each item saying its key; Control and a number
goes to a view (0 Home, 1 Mail, 2 Calendar, 3 People, 4 Tasks, 5 Notes,
6 Money), as does the list at the foot of the sidebar. The mouse does
what the keys do: a click on the sidebar's place (a mailbox, a list, an
account), on a row of a list (a conversation or a note opened, a task,
a line selected); the wheel moves a list's selection, or scrolls the
message read. Control-E
searches every view (Gmail's words: `from:alice`, `is:task`,
`before:2026-12-01`, `-is:read`): the items found as one types, by the
view they open in; Up and Down choose, Enter opens one, Tab shows one
view's, Escape goes back.

**Mail**, with Gmail's keys: `j k` move, `o` opens a conversation, `u`
back, `e` archives, `s` stars (Gmail's star; Starred in the sidebar
lists them; Unread there the Inbox's not read), `/` searches Gmail, Tab the Inbox or All Mail, `g`
gets the mail (the password asked once, kept while the window is
open); `c` writes, `r a f` reply, to all, forward (a draft kept at each
change; Send, Save Draft, Discard); `z` snoozes until a day typed as
words (monday, in 3 days), `t` makes it a task, `p` its sender a
person, `i` an invitation's events. In a message read, the days, the
amounts and the addresses are underlined, and `x` lists them, Enter
keeping one: a day an event, an amount a bill, an address a person.
Mail's Turn On the Screener makes the Inbox four lists: the Imbox, the
Screener, where a new sender waits (`y` lets them in, `n` screens them
out), the Feed and the Paper Trail (Mailbox > Sender:). Anyone in
People, or who wrote before it was turned on, is in the Imbox.

**Calendar**: `c` an event in a line ("lunch with alice tue 12:30",
"standup every monday 9h30", "déjeuner avec alice mardi 12h30", "roma
nov 3 to nov 7"), the person found in People; an event of several
days a bar across them in the week and the month, each calendar its
color (a timed event its dot), the suite's own blue; `d w m` a day, a week, a month; `j k` the next
and previous, `t` today, the arrows the day; `o` a day's page; `g`
Google's calendars fetched.

**People**: `n` a person ("Dan <dan@ix>"), `o` their page: what links
to them (events, tasks, money, notes), the money whose payee is their
name, the mail with them; `c` writes to them.

**Tasks**: `n` a task in a line, its day at the end ("pay the rent by
friday"); To Do begins with the inbox, what has no day yet; `x` done
(a repeating one makes its next), `d` its day, `z` snoozed, `s` put off
to Someday; Tab To Do, Someday, Done.

**Notes**: `n` a note, `d` the day's page; the text is saved as it is
typed; `[[contact:alice@ix]]` in it links to anything, and under the
text are what it links to and what links to it, a click opening one.

**Money**: an account's register (date, number, payee, category,
payment, deposit, cleared, balance); `n` a line typed in its columns,
the payee completed from the last time (QuickFill); `c` cleared; `r`
reconciles against a statement's balance, the difference explained (a
line not ticked, a wrong sign, two digits swapped), `f` finishes; Tab
the next account, the month's categories, then the envelopes: what is
assigned to each, spent, left, and what is left to assign; `a` assigns
("Groceries 400").

What the window is given is a list of *name*`=`*value*:

`user=`*address*
:    The account, the whole address (`you@gmail.com`).

`server=`*host*`:`*port*, `smtp=`*host*`:`*port*, `plain`
:    Another mail server than Gmail's, and no TLS (\man{maild}{1}).

`view=`*view*
:    The view opened first: `mail`, `calendar`, `people`, `tasks`,
     `notes` or `money`.

`write=mailto:`*address*
:    Mail's composer opened, filled from a `mailto:` link: its addresses,
     cc, subject and text (a bcc said, left out); what
     \man{netscape}{1} runs for one.

`today=`*day*
:    The day it is, for the tests (2026-10-29).

## The commands
**send** *file*
:    The message in *file* sent; a draft (from **reply** or
     **forward**) with its attachments.

**list** [ **-n** *count* ] [ **-q** *search* ] [ **-m** *mailbox* ]
:    The newest conversations, a line each: the newest message's UID,
     `*` if unread, the day, who, the subject. **-q** is Gmail's search.

**star** *uid* ..., **unstar** *uid* ...
:    Gmail's star given or taken off; `-m '[Gmail]/Starred' list` lists
     the starred.

**read** *uid*, **reply** [ **-all** ] *uid*, **forward** *uid*, **archive** *uid* ...
:    A message read (and marked so); a reply or a forward printed, to
     edit and send; out of the Inbox.

**snooze** *uid* *words*
:    The conversation out of the Inbox until the day the words say,
     back on top that day.

**search** *query*, **show** *id*
:    The store's items a query matches; an item, and its links both ways.

**add** *id* [ *name*`=`*value* ... ], **set** *id* *name*`=`*value* ...
:    An item made (`add task:rent due=friday`), its kind its id's;
     fields changed, an empty value taking one away. `due=` and
     `until=` may be words.

**contact** *uid*, **people**
:    A message's sender made a person; the address book.

**event** *words*
:    An event from a line, as the window's `c`.

**import** *file*
:    An iCalendar file's events (`.ics`), a vCard file's people
     (`.vcf`, Google Contacts' export), or a bank's QIF file's lines
     (`.qif`, into **-a** *account*, those already there left out).

**sync**
:    Google's calendars fetched (see FILES); with **-u**, the Inbox too.

**today**
:    The day: its events, the tasks late and due, what came back from a
     snooze, the unread mail from people, the day's page.

**remind** [ **-every** *minutes* ]
:    Runs, and says each reminder as its minute comes: a line, and on
     Linux a notification. An event with a time is said ten minutes
     before, or as many as its `remind:` says; a task at its `remind:`.
     Every five minutes it fetches the calendars and, with **-u**, the
     mail, saying what is new from people.

**register** [ **-a** *account* ], **balance**
:    An account's lines and its balance after each (`Assets:Checking`
     when not said); every account's balance.

**budget**, **assign** *envelope* *amount*
:    The envelopes and what is left to assign; money assigned to one
     (`assign Groceries 400`; a negative amount takes it back).

The options:

**-u** *user*
:    The account (else the store's file `user`). The password is the store's file `password` if there
     is one, else the first line of standard input.

**-s** *host*`:`*port*, **-plain**
:    Another server than Gmail's (smtp.gmail.com:465 to send,
     imap.gmail.com:993 to read), and no TLS.

**-offline**
:    **list** and **read** from what the store kept, no server.

**-v**, **-debug**, **-quiet**
:    What it reads (the store, the password's and the calendars'
     files), connects to and fetches, on standard error; and more; not
     even the warnings (\man{common}{1}). The window takes them too.

**-today** *day*, **-at** *hh*`:`*mm*
:    The day it is, and for **remind** the one minute to say, for the
     tests.

# THE STORE
The store is a directory of text files, an item a file, read and
changed with any editor; nothing is saved by hand. An item is lines of
*name*`: `*value*, a mail's header's syntax, then its text:

```
id: task:rent
stamp: task money
title: rent
due: 2026-11-05
repeat: FREQ=MONTHLY;BYMONTHDAY=5
posting: Expenses:Rent  900.00
posting: Assets:Checking
```

`stamp:` says what the item is: `message`, `event`, `task`, `contact`,
`note`, `money`, `budget`, `sender`; one or several. The fields the
views read:

`title:`, `name:`, `email:` (one a line), `phone:`, `birthday:`
:    What an item is called; a person's addresses, phones and birthday.

`when:`, `end:`, `ends:`, `where:`, `repeat:`, `except:`, `remind:`, `calendar:`
:    An event's day and time, its end, its last day (several days), its
     place; its repeat
     (iCalendar's rule); the days a repeat skips; the minutes before
     it is reminded (`no` for never); the Google calendar it came from.

`due:`, `done:`, `until:`, `someday:`, `remind:`
:    A task's day, the day it was done; the day an item (a task, a mail)
     is snoozed to; a task put off to Someday; when it is reminded
     (`2026-11-03 9:00`).

`re:`, `with:`, and `[[`*id*`]]` in a text
:    Links: what an item is about (a task's mail, an event's
     invitation), who is with it. Every item lists what links to it.

`date:`, `payee:`, `posting:`, `cleared:`
:    A money line: its postings (an account and an amount, one amount
     left out, the books balancing), a category being an account
     (`Expenses:Groceries`), a transfer another account (`[Assets:Savings]`
     in the register).

`envelope:`, `amount:`; `screen:`
:    A `budget` item's envelope and amount; a `sender` item's decision
     (`imbox`, `feed`, `paper`, `out`).

# FILES
`$PIM_STORE`, or `~/.ix-pim` on Linux, or `$home/lib/pim` on Plan 9:
the store; `items/` its items, `cache/` the mail's bytes.

*store*`/user`
:    The account's address, written by a person (`echo you@gmail.com >
     ~/.ix-pim/user`): the window's `user=` and the commands' **-u** when
     they are not given.

*store*`/password`
:    The app password (Google's, for mail), if one wants it kept: made
     by a person, mode 600; *pim* never writes it, and refuses it when
     others may read it.

*store*`/calendars`
:    A line a Google calendar, its name then its secret address in
     iCalendar format (Google Calendar's settings, "Secret address in
     iCal format"): mode 600 too, as the password's.

`/etc/localtime`, `/env/timezone`, or `TZ`
:    The zone the times are in.

# EXAMPLES
```
pim user=you@gmail.com
pim -u you@gmail.com list < password-file
pim add task:passport due='in 2 weeks'
pim event dentist nov 5 at 4pm
pim search from:alice is:unread
pim -u you@gmail.com remind &
```

# DIFFERENCES
Read only with Google, but for the mail: Google lets a program write
a calendar or the contacts only with OAuth, not yet here. A time
written in another zone (TZID) is read as it is written.

# SEE ALSO
\man{maild}{1}, \man{office}{1}, \man{curl}{1};
`apps/pim/README.md`; `docs/plans/done/plan_pim.md`

# DIAGNOSTICS
A server that refuses, a password file others may read, a day that is
not one, are said, and the status is not empty.
