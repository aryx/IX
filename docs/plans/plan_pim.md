# Plan: mini-pim, a suite for organizing a life: mail, calendar, people, tasks, notes and money, one store, each referring to the others (`apps/pim/`)

The author (2026-10-29), after plan_apps.md: "Ideally we would start
a plan_pim.md where we would have also a calendar, contact, todo,
reminder, email, all integrated in some form, or where one could
refer one another; just steal good ideas from PIM out there or famous
one. Even a mini-quicken or something for finance, maybe also
integrated with this PIM thing, that is a 'suite' like office, but
not for document authoring but for life organizing and comms and
more." Then: "we can redesign things for IX (m-ix), and don't have to
follow the playground or plan 9 (upas)"; and "let's try to design
something well integrated, like a suite, powerful, and useful for
real, but also small, like we did a bit with mini-office (and
mini-netscape)."

**Status: begun, mail's stages 1 to 5 (its formats, sending,
reading, kept, a window), and the store (stage 2) begun.**
Mail, the first part, has its own plan, [`plan_mail.md`](plan_mail.md).

## What it is for

The author's own life, really: their Gmail read and answered, their
appointments, the people they know, what they have to do, their
money. On Linux, and on mini-9pi. Small, as mini-office is (4,745
lines of `.ml`): a design where one idea does the work of many
features, not a list of features.

## The ideas taken, what worked and what did not

The author (2026-10-29), after a first table of famous PIMs: "I
dunno if there are really good ideas from popular or innovative PIM
we could steal". There are, but a list of famous programs mixes the
ideas that won with the programs that failed, and the difference is
the useful part. So the ideas sorted by what happened to them.

### Proven: used by millions, and the design rests on them

- **Search, don't file** (Gmail, 2004). Gmail launched with 1 GB when
  others gave 2 to 4 MB, and a search box where the others had
  folders; people stopped filing and never went back. Labels replaced
  folders because a message can be in two places. Here: search is the
  way in, not a box in a corner; labels, not folders, for every item.
- **Snooze, or defer**: an item gone until a date, then back on top.
  The paper **tickler file** (43 folders: 31 days and 12 months, a
  paper put in the day it is wanted again) is the idea; **Inbox by
  Gmail** (2014-2019) made it the gesture of mail, and every client
  copied snooze before Google closed Inbox; **Things** and
  **OmniFocus** made it the gesture of tasks (a defer or start date:
  "can't begin before the 10th", hidden until then). It is one idea for
  mail and tasks, and with stamps it is one field: a `when` that hides
  the item until it comes.
- **Dates typed as words** (**Fantastical**, 2010; **Todoist**):
  "lunch alice tue 12:30", "every 2nd monday", made an event or a
  repeat. **Lotus Agenda** (1988) had the idea first and sold poorly;
  these are the programs that shipped it, and people now expect it.
- **Data detectors** (Apple's Advanced Technology Group: Bonnie Nardi,
  James Miller, David Wright, 1997): dates, addresses, phone numbers,
  flights recognized in any text, an action offered. A research
  prototype then; every mail program's underlined dates today. Inbox
  by Gmail's cards (a flight, a parcel) were its descendant.
- **One agenda across everything** (**Emacs's org-mode**, Carsten
  Dominik, 2003; **Outlook Today**): the day's events, what is due,
  what is late, from wherever they are kept. Org-mode's following
  among programmers is the proof that plain text is enough for it.
- **Instant, no Save** (**Palm Pilot**, Jeff Hawkins, 1996): four
  things, on at once, every change kept. Palm sold millions where the
  Newton had failed, by doing less; every phone does it now.
- **The register and QuickFill** (**Quicken**, Scott Cook and Tom
  Proulx, Intuit, 1984): the screen as the paper checkbook, not an
  accountant's ledger; a payee completed and the line copied from the
  last time; reconciling against the statement. Quicken beat some
  forty programs that were better accounting and worse checkbooks.
- **An invitation is a mail that is an event** (**Outlook** and
  Exchange, 1997; iCalendar's iMIP, 1998): the one integration of
  mail and calendar that everybody uses, because it crosses programs
  and companies.

### Innovative: a following, not the mainstream, worth taking

- **The Screener** (**HEY**, Basecamp, 2020): the first mail from a
  new sender waits for one yes or no; no, and they are never seen
  again. Small, and it changes the inbox from what others send to what
  one has agreed to read. HEY's other split: the **Imbox** (people),
  the **Feed** (newsletters, read like a paper) and the **Paper
  Trail** (receipts, kept, not read). Here a receipt goes to Money.
- **Backlinks and the daily note** (**Roam Research**, 2019;
  **Obsidian**, 2020; Ward Cunningham's wiki, 1995, before them): a
  page lists what links to it, without anyone writing that list; and
  each day a page, written in, that everything of the day links from.
  Here: links are kept both ways, and Today is a page one writes in,
  not only a list.
- **Give every dollar a job** (**YNAB**, You Need A Budget, Jesse
  Mecham, 2004): the money there is assigned to envelopes before it is
  spent (rent, food, the car's next repair), so a budget is what one
  has, not a forecast. The envelopes of a household's kitchen drawer,
  on a screen. A better idea than Quicken's category report, which
  says afterwards where the money went; and small.
- **Double entry in a text file** (**ledger**, John Wiegley, 2003;
  hledger, beancount): a transaction is postings that sum to zero,
  and a category is just an account. Plain-text accounting is a niche,
  of programmers, and its file is the best store for money there is.
- **Contacts from the mail one reads** (**BBDB**, Jamie Zawinski,
  1991, in Emacs): a niche, but nobody wants to type an address that
  is already in a header.

### Famous, and failed: what to learn from them

- **Chandler** (Mitch Kapor's Open Source Applications Foundation,
  2002-2009). The best idea in this list as a model of the data: one
  item **stamped** as a message, an event, a task, not three copies in
  three programs; this design takes it (below). And the most famous
  failure: years, millions of dollars, a team of good programmers, and
  no program people used. Scott Rosenberg's *Dreaming in Code* (2007)
  tells it: it tried to be everything (a new kind of PIM, peer-to-peer
  sharing, a repository of its own, a platform for others), and kept
  redesigning. The warning this plan keeps: stamps, and a small
  program round them; no sync of our own, no platform.
- **Lotus Agenda** (Kapor again, Jerry Kaplan, Ed Belove, 1988): free
  items, categories assigned by rules from the words, views as
  queries. Loved by those who learned it, and sold poorly: it asked
  its user to design their own database. Its typed dates won later
  (above); its free-form structure did not.
- **The Apple Newton** (1993): a shared store (the soup) every
  application queried, and Assist, which understood "lunch with Bob
  Friday". The handwriting recognition was mocked, and the device was
  too big and too dear; the Palm did less and sold. The store is a
  fine idea and is this design's; the lesson is the Palm's.
- **Microsoft Bob** (1995) and Clippy: help that interrupts. Nothing
  here pops up unasked except a reminder one has set.

### Also taken

- **Getting Things Done** (David Allen, 2001): an inbox for everything
  captured, emptied by deciding (do it, schedule it, give it, drop it)
  and a weekly review. A method, not a program; the inbox of captured
  items at the top of Tasks is its part here.
- Unix's **calendar(1)**, **leave** and **at** (1970s): a reminder is a
  line in a file and a process that waits.

## The design

Six ideas, and everything else follows from them.

### 1. One store of items, each stamped

There are no separate databases of mail, events, tasks and contacts.
There are **items**, and an item carries one or more **stamps**,
Chandler's word: `message`, `event`, `task`, `contact`, `note`,
`money`. A stamp is a few fields of its own:

    message   from, to, subject, labels, the body (the mail cache)
    event     when, how long, repeat, where
    task      due, done, priority
    contact   name, addresses, phones
    note      a text
    money     postings (account, amount), cleared

So "answer Alice by Friday" is Alice's mail stamped `task` with a due
date, not a task that copies it; the concert is an event stamped
`money` with the ticket's price; a bill is a task stamped `money`,
due on the 5th, repeated every month. Stamping is how the suite is
integrated, and it is why it can be small: the calendar shows what
has `when`, the task list what has `due`, the register what has
postings, whatever else the item is.

### 2. Links both ways

An item names others: `with: contact:alice`, `re: mail:<id@host>`,
`for: event:e17`. The store keeps the reverse too, as `Sheet` keeps
"read by" beside "reads" (`apps/office/sheet/Sheet.mli`). So every
item has a page of what refers to it, and the most useful page of the
suite is a **person's**: their addresses, and below, the mail with
them, the next events with them, the tasks for them, the money paid
to them, all by the reverse links.

### 3. Plain text, in files a person can read

The store is text files in the user's directory (`$home/lib/pim/` on
mini-9pi, the store's place on Linux), an item a paragraph of `name:
value` lines, the same syntax as a mail's headers and read by the
same parser:

    id: t42
    stamp: task money
    title: pay the electricity
    due: 2026-11-05
    repeat: FREQ=MONTHLY;BYMONTHDAY=5
    with: contact:edf
    posting: Expenses:Utilities  62.40
    posting: Assets:Checking

Readable and fixable with `ed`, searched with `grep`, its history and
its backup by mini-git, no Save (the Palm's: every change written).
The mail's bodies are the one exception: a cache of the server's
messages, one file per message, which can be thrown away. The
standard formats are at the border only, read and written, never the
store: iCalendar, vCard, QIF and CSV and OFX from a bank, MIME.

### 4. One agenda, one search, one line to capture

- **Today** (org-mode's agenda, Outlook Today, the daily note): the
  day's events, the tasks due or late, the bills due, the reminders,
  what was snoozed to today, the unread mail from people in the
  address book; and under them the day's own page, written in, a note
  linked from what the day touched. The suite opens on it.
- **Search** over every item, Gmail's syntax where it fits:
  `from:alice`, `is:task`, `before:2026-12-01`, `label:travel`, words.
- **Capture** (Agenda, Newton): one line typed anywhere, "lunch with
  alice tue 12:30", made an item: the date and time found, Alice
  found in the address book, stamped `event`. The same recognizer runs
  over mail, as Data Detectors: a date, a person, an amount in a
  message, underlined, and a key makes it an event, a contact, a
  posting.

### 5. Snooze: one gesture for mail and tasks

Any item can be put away until a date (the tickler file, Inbox by
Gmail, Things): `z` and "monday", or "in 3 days", typed as words. It
leaves every list and comes back on top of Today and of its own view
on that day. It is not a feature of mail and another of tasks but one
field, `until:`, which every view reads the same way: hidden before
it. A task's start date (Things' defer) is the same field.

### 6. Reminders that run when the window is closed

ix has a kernel: a reminder is not limited to while the program is
open (the playground's limit). A small process of the suite's,
`pim remind`, waits for the next item due and shows it: a window on
mini-rio, a line on the terminal, on Linux a notification. The same
process checks mail every few minutes, so Today is ready when opened.

## The views

One program, mini-pim, as mini-office is one, its views over the one
store:

    Today | Mail | Calendar | People | Tasks | Notes | Money     [search]
    ---------------------------------------------------------------
    the view                                     | the item opened,
                                                 | its links below

- **Mail** (plan_mail.md): conversations, labels, reading, writing.
- **Calendar**: a month and a week, events dragged, repeats as rules
  computed for the days shown, never stored as lists.
- **People**: the address book, filled by hand and from mail read
  (BBDB); a person's page (idea 2).
- **Tasks**: by due date and priority; GTD's inbox (captured, not yet
  decided) at the top.
- **Notes**: text with links to anything (`[[contact:alice]]`).
- **Money** (below).

And the same store from a terminal, for real use and for the tests:
`pim today`, `pim add 'lunch with alice tue 12:30'`, `pim search
from:alice`, `pim remind`.

## Money

Quicken's face over ledger's books:

- **The register** of an account, Quicken's: date, payee, category,
  amount, the balance after each line; QuickFill (a payee completed
  and the line copied from the last time); **reconciling** against a
  statement, the difference explained (a line not ticked, two digits
  swapped: the arithmetic of nines). Amounts in cents, never floats.
- **Under it, double entry**: a transaction is postings summing to
  zero, and a category is an account (`Expenses:Groceries`), so a
  transfer between accounts and a category report are the same thing,
  and the books always balance. The pair to show: Quicken's one signed
  amount per line against ledger's postings.
- **Envelopes** (YNAB): the money in the accounts assigned to
  envelopes (rent, food, holidays) before it is spent, each spending
  taken from one; the budget is what is left in each, not a forecast.
  In double entry an envelope is one more account, so it costs little.
- **Integrated by stamps**: a bill is a task with postings and a
  repeat, so it is in Today when due, and paying it is ticking it; a
  ticket is an event with postings; a receipt that comes by mail is
  linked from its transaction, its amount found by the recognizer;
  the payee is a contact, so a person's page shows the money too.
- **From the bank**: CSV and OFX files imported, matched to the lines
  already there (the same amount and a near date) before adding.
  No connection to a bank.

## What it stands on

In ix: `lib_networking` (TLS, TCP, DNS; HTTPS for a calendar's URL),
`Base64`, `Civil` and `Clock` (in `lib_networking/tls/`, to move to
lib_core when a second user comes), lib_gui and lib_playground,
mini-office's `File_menu` and store, the text editing of
`gui/Text_edit`; mini-git for the store's history.

From the playground, the code of the standard things, where writing it
again teaches nothing (each copied file saying so, as mini-office's):
`Mail`, `Mime`, `Mail_thread`, `Smtp` (plan_mail.md); `Julian` and
`Recur` (iCalendar's repeat rules), `Ics` and `Vcard`; `Money` (cents,
the amount in words), `Reconcile`, `Qif`. Not their programs: no
TinyEudora, TinyCalendar, TinyPalmPilot or TinyQuicken; their ideas
are in the table above.

## Google's side

The author's account, as far as it lets a program in with an app
password (plan_mail.md):

- **Mail**: IMAP and SMTP, read and written (plan_mail.md).
- **Calendar**: an invitation is a mail with an iCalendar part
  (iMIP, RFC 6047), so the events others invite one to come in by
  mail, and accepting is a mail back. The calendar itself, read only,
  by its private address in iCalendar format (Google Calendar's
  settings, "Secret address in iCal format"), fetched by HTTPS; to be
  checked that it is still offered. Writing back to Google's calendar
  is CalDAV, which needs OAuth since 2025: later.
- **Contacts**: a vCard file exported from Google once, imported;
  CardDAV, OAuth, later.

## Stages

1. **Mail**, plan_mail.md's stages: the author reads their Gmail in
   ix. The store and the item come in here, the messages its first
   items.
2. **The store**: items, stamps, links both ways, the files, the
   terminal's `pim`; search.
3. **Time**: `Julian`, `Recur` copied, time zones (the zone's rules
   from the system's zoneinfo on Linux, `/env/timezone` on mini-9pi);
   **Calendar** and **Today**; invitations from mail; Google's
   calendar by its address.
4. **People**: the address book, filled from mail; a person's page.
5. **Tasks** and **reminders**, `pim remind`; **snooze** (`until:`,
   for tasks and mail alike); capture and the recognizer, dates typed
   as words, in a line and in mail.
6. **Money**: the register, double entry under it, reconciling, the
   bank's files, bills as tasks; then envelopes.
7. **Notes**, links in text, backlinks; Today's daily note.
8. **Later**: two-way sync with Google (OAuth, CalDAV, CardDAV), or
   with another ix by mini-git; the views on a phone-sized
   screen.

A rough size, to be held to: the store, links and search 800 lines;
time 500 (half copied); mail 2,500 (plan_mail.md); calendar and Today
800; people 300; tasks, reminders and capture 700; money 800 (a third
copied); notes 200. About 6,500 lines of `.ml`, mini-office's size
and a half.

## Open questions

- **The name**: mini-pim, or one of a person's words (mini-organizer,
  mini-life)?
- **One file per kind of item, per month, or per item?** Per item
  is simplest for mini-git and for two programs writing at once; per
  month is easiest to read with an editor. (Taken for now, 2026-10-29:
  per item, `Items`; the author has not said.)
- **The recognizer's languages**: English only, or French too
  ("déjeuner avec alice mardi 12h30")?
- **Where it runs**: is mini-9pi a place the author would really use
  it, or Linux first and mini-9pi as for mini-office, shown working?

## Status

2026-10-29: design written. Nothing built.

2026-10-29: the ideas sorted by what happened to them (proven,
innovative, failed), after the author's doubt; snooze, the Screener,
the daily note and envelopes added to the design, Chandler's failure
kept as the warning on its scope. Nothing built.

2026-10-29: begun, by mail (stage 1): `apps/pim/`, one library
(`ix_pim`) in folders as mini-office; `mail/` has the formats,
plan_mail.md's stage 1.

2026-10-29: mail's stage 2: `mini-pim send`, the terminal's first
command, and mini-maild, the server its tests send to.

2026-10-29: mail's stage 3: `mini-pim list`, `read`, `archive`, by
IMAP; a line a conversation.

2026-10-29: the store begun, by mail's stage 4: `store/Item`, an item
a `Mail.t` (the header parser the store's, idea 3), stamped (idea 1);
`store/Items`, a file an item, written at once; a message an item
stamped `message`. Not yet: links both ways, search over items, the
other kinds.

2026-10-29: mail's stage 5: mini-pim's first window, its mail; one
program with the terminal's commands.

2026-10-29: mail's stages 6 (as far as mini-maild shows it: HTML-only
mail, All Mail by its \All) and 7 (writing: reply, forward, drafts,
from the terminal and in the window).

2026-10-29: stage 2, the store, continued: `store/Search`, a search
over every item, Gmail's syntax where it fits (words, phrases,
`field:value` for any field, `is:` a stamp or unread, `label:`,
`before:` and `after:` the item's day: due:, else when:, else a
message's date; `-` not); `store/Links`, links both ways, a word of a
field naming an item's id, the reverse computed when asked (nothing
kept in step when ed or mini-git changes an item). The terminal's
`search`, `show` (an item and its links both ways), `add`, `set`.
Tests: Unit_store; session.sh (a task made of answering Carol's
message, each found from the other). Not yet: the window's search over
items (its / searches the mail), the other kinds' views.

2026-10-29: stage 5 begun by mail's stage 8: snooze, the `until:`
field (idea 5), for messages (archived on Gmail meanwhile, back that
day); tasks, a message stamped task with a due day, a Tasks list in
the window; days typed as words (`store/When`, the recognizer's
first part, English and French: the open question answered both for
days). Not yet: `pim remind`, capture of a line, snooze of a task.

2026-10-30: stage 4 begun, People: `store/People`, a contact of a
message's sender made by a key (BBDB's way: p in the window, `mini-pim
contact uid`), its id the address (contact:alice@ix), an email: line
an address; a person's page, their addresses and the mail with them by
any of them (found by address, not by links), then what names them
(Links). The window's Go > People and a person's page; the terminal's
`people` and `show`. Tests: Unit_people, session.sh, a frame. Not
yet: addresses completed in To:, a vCard imported, the sender shown
as the contact's name in lists.

2026-10-30: the window a suite (the author: "a 'meta' gui is also
useful to launch the components", the terminal's commands kept as
they are): `window/Pim_window`, a Home of tiles, one a view (Mail,
Tasks, People: m t p or a click), each saying what is unread, late,
due, and under them Today's beginning, the tasks late and due today
and the mail back from a snooze (idea 4); in a view, a first menu
Pim and Ctrl+0 to 3 (Outlook's Go menu and keys) and a switcher at
the sidebar's foot (Outlook 2003's buttons). Mail_window (993 lines)
split by view: `Tasks_window` (To Do and Done, a task captured in a
line with its day at its end, `When.ending`: capture's first part;
x, d, z for a task too, idea 5; o a message's task opened in Mail),
`People_window` (a person added by hand, their page, a message of
theirs opened in Mail, c writes to them), `Pim_look` (what the views
share). A view asks the suite for another (`Pim_look.go`), and each
is read again from the store as it is shown. Tests: Unit_when (a day
at a line's end), 25 frames (9 new: Home, its menu, a tile, capture,
done, a task's message opened, a person added, written to), mini-ml.
Not yet: Calendar, Notes, Money, a search over every view.
