# Plan: mini-mail, the mail of mini-pim, reading and answering the author's Gmail, on Linux and on mini-9pi (`apps/pim/mail/`)

The author (2026-10-29), after plan_apps.md: "let's start a
plan_mail.md for mini-mail ideally we could read my gmail account; I
think it uses pop3 or IMAP". Then: "we can redesign things for IX
(m-ix), and don't have to follow the playground or plan 9 (upas)";
and "let's try to design something well integrated, like a suite,
powerful, and useful for real, but also small, like we did a bit with
mini-office (and mini-netscape)."

**Status: stages 1 to 5 built (the formats; sending and reading, and
mini-maild; the cache and the items; the window; `apps/pim/`).** Mail is the first part of the suite
[`plan_pim.md`](plan_pim.md): its messages are the suite's first
items, and its design follows the suite's (one store, stamps, links,
plain text). This plan says what is mail's own.

The short answer: **IMAP to Gmail, over the TLS ix already has**, with
an app password; SMTP to send. The formats and SMTP are copied from the
author's playground, where they were written and tested (and where
POP3 and SMTP reached Gmail over the playground's own TLS,
2026-09-26). IMAP and the client are ix's own, designed for the
suite, not after any program.

## Gmail: what it speaks, and how it lets a program in

| What | Where | Over |
|---|---|---|
| read, kept on the server | `imap.gmail.com:993` | IMAP4rev1, TLS from the start |
| send | `smtp.gmail.com:465` | SMTP, TLS from the start, AUTH PLAIN |

(POP3, `pop.gmail.com:995`, downloads and forgets the server. Not
taken: the author's mail is read on a phone too, and its labels and
read marks must stay shared.)

The login: since March 2025 Google lets a third-party program into
Gmail by OAuth 2.0, or by an **app password**, the one exception it
keeps, and app passwords exist only on an account with 2-step
verification ([Google's
page](https://knowledge.workspace.google.com/admin/sync/transition-from-less-secure-apps-to-oauth)).
The account's own password is refused. So an app password, made once
in the account's security page, the login the whole address. Google's
page gives the exception no end date; OAuth 2.0 (SASL XOAUTH2: a
project at Google, a browser's consent, tokens refreshed over HTTPS)
is the stage to take if it ends.

## The design

### What it does

What the author does with mail, and no more:

- **Conversations**, not messages: Gmail's own (`X-GM-THRID`), shown
  as one entry, its messages one under another, the quoted parts
  folded.
- **Labels**, not folders: Inbox, a label, Sent, All Mail. **Archive**
  (out of Inbox, kept) as the one gesture after reading, Gmail's.
- **Search** first: the box sends Gmail's own syntax as is
  (`X-GM-RAW`), so the whole mailbox is searched by the server, not
  the cache; the suite's search adds the other items.
- **Snooze** (`z`, "monday"): the conversation out of the Inbox until
  then, back on top that day: plan_pim.md's `until:`, the same as a
  task's. On Gmail's side it is archived meanwhile, so the phone
  agrees.
- **The Screener** (HEY's): mail from a sender never answered nor
  accepted waits apart, a yes or a no each; no, and their mail goes
  past the Inbox from then on (a Gmail label, so it is kept and the
  phone sees it too). The receipts and newsletters, said so once per
  sender, to their own labels, the receipts to Money.
- **Reading offline**: what has been fetched stays, so the plane,
  and mini-9pi without network, still show it.
- **Writing**: reply, reply to all, forward, a new one; the addresses
  completed from People; a draft kept as one types; attachments.
  Sent by SMTP (Gmail files a copy in Sent itself).
- **The keyboard**, Gmail's and mutt's letters: `j` `k` next and
  previous, `o` open, `r` reply, `a` all, `f` forward, `e` archive,
  `#` delete, `/` search, `c` compose, `t` a task of it, `z` snooze.

### What makes it the suite's

- A message is an **item** stamped `message` (plan_pim.md, idea 1):
  its headers kept in the store, its body in the cache. Stamping it
  `task` (`t`), with a due date, is how mail is "to answer by Friday";
  it is then in Today and the task list, and still a message.
- The sender is a **link** to a contact when there is one, made one
  with a key when there is not (BBDB): a person's page lists the
  conversations with them.
- **Invitations** (a `text/calendar` part, iMIP) are shown as the
  event, with accept and decline, which answer by mail and put the
  event in the calendar.
- The **recognizer** (plan_pim.md, idea 4) underlines dates, places,
  amounts in a message; a key makes an event, a contact, a posting
  linked back to the message.

## IMAP, ix's own

The protocol is the instructive part. Mark Crispin's (1986), a mailbox
kept on the server and looked at from anywhere, against POP's (1984)
mailbox carried home: and harder to read than any of ix's other
protocols, which is the lesson:

- Commands **tagged** (`a1 UID FETCH ...`), so several are in flight,
  and answers **untagged** (`* 3 EXISTS`) that come unasked, a new
  message arriving while one fetches.
- **Literals**: `{1234}` then that many bytes, so a message's bytes,
  any bytes, travel inside a line-based protocol.
- A reply's syntax of nested lists, parenthesized, with strings
  quoted, atoms and NIL: a small reader of its own, worked example in
  its `.mli`.
- **UIDs** and UIDVALIDITY: a message's number that does not change,
  and the number saying when the cache must be thrown away.

The subset: LOGIN (or AUTHENTICATE PLAIN), CAPABILITY, LIST, SELECT,
UID SEARCH, UID FETCH (`ENVELOPE`, `FLAGS`, `RFC822.SIZE`, `X-GM-THRID`,
`X-GM-LABELS` for a range of the newest; `BODY.PEEK[]` when a message
is opened, so that opening is not reading), UID STORE (`\Seen`,
`X-GM-LABELS`), UID MOVE or COPY, IDLE (mail pushed while the
connection is open), LOGOUT. About 600 lines with its tests.

## What exists

In the playground (`~/playground/libs/networking/`), each `.mli` with
its worked example and tested; copied, each file saying where it comes
from and what changed:

| there | lines (.ml) | what | taken |
|---|---|---|---|
| `mail/Mail` | 186 | RFC 5322: headers, folding, addresses, dates, References | yes; its header parser the store's too |
| `mail/Mime` | 272 | multipart, base64, quoted-printable, encoded words | yes |
| `mail/Mail_thread` | 193 | Zawinski's threading (1997) | yes: conversations where there is no Gmail |
| `protocols/Smtp` | 162 | the dialogue, AUTH PLAIN | yes |
| `unix/Mail_server` | 253 | a server, SMTP in, POP3 out | its SMTP half, for the tests |
| `mail/Mbox`, `protocols/Pop3` | 66, 89 | | no: the cache is a file a message; no POP3 |
| `TinyEudora` | 1,183 | Eudora's client | no: its ideas only (above) |

In ix: `lib_networking/tls/` (TLS 1.3 and 1.2, `X509`, the roots),
`tcp/` (`Tcp`, `Dns`, their Plan 9 versions over `/net/tcp`), `Base64`,
`Civil`, `Clock`. Left out when TLS was copied
(`lib_networking/README.md`, *checked*): `Tls_client`'s connection as
lines, which IMAP and SMTP need.

## What real mail needs

The playground's mailboxes were written for its lessons; a real
Gmail account is harder, and this is where much of the work is:

- **HTML only.** Much of what arrives has a `text/html` part and a
  poor `text/plain` one, or none. The plain part when it is good;
  otherwise the HTML made text by `browsers/`' engine (lynx's way: the
  blocks, the links numbered). The page in mini-netscape on a key.
- **Charsets**: UTF-8, ISO-8859-1, Windows-1252, made UTF-8 when read;
  then drawn (open question).
- **Size**: tens of thousands of conversations. The list fetches the
  newest page of headers; a body when opened; search goes to the
  server.
- **Attachments**: a picture shown (`lib_graphics/images`), a PDF in
  mini-page, anything else saved; written ones read from the store.

## The password, and the tests

- **The app password is asked, kept in the process, never written**:
  not in the store, not in a file of the tree, not in a test's
  environment. A place to keep it is plan_gaps.md's password store,
  when it exists; `pim remind`, which checks mail in the background,
  is given it by the window that asked. (2026-10-29, the author: "yes
  let's do this ~/.ix-pim/ thing": a file the author makes,
  `~/.ix-pim/password`, mode 600, is read first; mini-pim still writes
  it nowhere, and refuses a file others may read, as ssh a key.)
- **`make test` never talks to Gmail.** A server of ix's own,
  `tests/`' mini-maild: SMTP from `Mail_server`, and the IMAP subset
  above, Gmail's extensions included, over a mailbox written for the
  tests (a conversation of five, an HTML-only message, Latin-1, an
  invitation, an attachment). Every protocol checked by a session in
  `make test-lite`, as mini-httpd is for mini-curl. Gmail is checked
  by the author, by hand.

## Stages

1. **The formats**: `Mail`, `Mime`, `Mail_thread` copied, their tests;
   the charsets.
2. **The connection**: `Tls_client`'s lines; `Smtp` copied; mini-maild
   with SMTP.
3. **IMAP**, client and mini-maild's side, their sessions in
   `make test-lite`.
4. **The cache and the items**: a message a file, its headers an item
   of plan_pim.md's store (its stage 2 begun here).
5. **The view**: conversations, labels, reading, the keyboard, on
   Linux; golden frames against mini-maild.
6. **Gmail**: the author's account, by hand. The real mail of the
   section above, fixed as it comes.
7. **Writing**: reply, forward, new, drafts, attachments, sent by SMTP.
8. **The suite's links**: a task of a message, the sender a contact,
   invitations, the recognizer, snooze, the Screener (with
   plan_pim.md's stages 3 to 5).
9. **On mini-9pi**: the card's roots, the clock set (SNTP, or every
   certificate is "not yet valid"), DNS through `/net/ndb`; Gmail
   read under QEMU and on the board.
10. **Later**: OAuth 2.0; a spam filter by Bayes (Graham, 2002), if
    Gmail's ever lets too much through.

About 2,500 lines of `.ml`: 650 copied, IMAP 600, the cache and items
300, the view and writing 950.

## Open questions

- **Accents and other scripts**: mini-office's Hershey fonts have
  none, and the author's mail is in French. A font with Latin-1 at
  least (a bitmap, as Plan 9's subfonts, or an outline font, which
  plan_gaps.md lists), or accents drawn as strokes over the letter?
  mini-office wants the same.
- **The HTML**: text by the browser's engine, as proposed, or the
  page drawn in the view by mini-netscape's engine, images off?
- **Several accounts**, or the author's one?

## Status

2026-10-29: plan written. Nothing built.

2026-10-29: snooze and the Screener added, after plan_pim.md's
review of what worked. Nothing built.

2026-10-29: stage 1, the formats: `Mail`, `Mime`, `Mail_thread`
copied in `apps/pim/mail/` (671 lines of `.ml`), their tests (17, in
`make test`), compiled by mini-ml too. The charsets: ISO-8859-1 read
as Windows-1252 (WHATWG's), ISO-8859-15's eight own characters; the
playground read both as Latin-1. `apps/pim/README.md` says what
changed. Next: stage 2, `Tls_client`'s lines and `Smtp`.

2026-10-29: stage 2, the connection: `Lines` (ix's own: a connection
of lines over TCP or TLS that drives a pure machine), `Smtp` copied
(its `?auth` said), `Smtp_server` the SMTP half of the playground's
`Mail_server` made a pure machine (AUTH PLAIN added, any password);
two programs, `mini-pim send` (to Gmail by default, `-plain` for
mini-maild) and mini-maild (127.0.0.1, one client at a time, a file a
message, `spool/<user>/<n>`). mini-maild is a program of `apps/pim/`
beside mini-pim rather than of `tests/`: it is run by hand too. Tests:
Unit_smtp, Unit_smtp_server (the two machines against each other,
`Lines` over a socketpair), and `tests/sent.sh` (a message sent,
delivered to two users, one in Bcc:, the relay refused), in `make test`.
Not tried: TLS, which is Gmail's only (stage 6, by hand). Next: stage
3, IMAP.

2026-10-29: stage 3, IMAP: `Imap`, the responses read (atoms, quoted
strings, NIL, lists, literals: `Lines.bytes`) and the client (LOGIN,
SELECT, UID SEARCH, UID FETCH, UID STORE, LOGOUT); `Imap_server`,
mini-maild's side, Gmail's extensions included (X-GM-LABELS,
X-GM-THRID by Mail_thread, X-GM-RAW's words), INBOX the messages
labelled \Inbox and `[Gmail]/All Mail` all; mini-maild on two ports,
the flags and labels kept in the process. Changed from the plan above:
the headers fetched as `BODY.PEEK[HEADER.FIELDS (...)]`, read by
`Mail.parse`, not ENVELOPE (a structure of its own, without
References:, which Mail_thread needs where Gmail's X-GM-THRID is not);
no IDLE nor MOVE yet (archive is `-X-GM-LABELS (\Inbox)`); the
summaries ask Gmail's items always, so a server without X-GM-EXT-1 is
not read. `mini-pim list`, `read`, `archive`; `tests/session.sh`
(sent.sh grown: three messages, two a conversation, one Windows-1252, listed,
read, searched, archived) and Unit_imap (a FETCH with its literal, the
client against Imap_server over a socketpair) in `make test`. Not
tried: Gmail (stage 6, by hand: `echo <app password> | mini-pim -u
you@gmail.com list`). Next: stage 4, the cache and the items.

2026-10-29: stage 4, the cache and the items: plan_pim.md's store
begun, `store/Item` (an item a `Mail.t`: name: value lines, stamped)
and `store/Items` (`$PIM_STORE`, else `~/.ix-pim`, else
`$home/lib/pim`; `items/<id>` a file an item, `cache/<msgid>` a
message's bytes); `Mail_item`, a message's item, its id `mail:` and
Gmail's X-GM-MSGID (now in `Imap.summary`), the server's fields
replaced at each list and a person's kept (a stamp task, a due date).
`mini-pim list` writes the items, `read` takes the cache first and
fills it, `archive` updates the labels; `-offline` lists and reads
from the store alone. An item keeps the mailbox and UID of its last
list only: a message listed in All Mail after INBOX is no more in
INBOX's offline list until listed there again. Tests: Unit_items, and
session.sh's offline end (the last list, a message read, one not).
Next: stage 5, the view.

2026-10-29: stage 5, the view: `window/Mail_window`, a
`Playground.game` over the store, offline first: the conversations of
Inbox or All Mail (Tab), a line each, unread in bold; j k, o, u, e,
/ (a search of the store: who sent and the subject), g (get the mail:
the app password asked once, kept while the window is open, never
written); a conversation opened, its messages oldest first, fetched
into the cache when the password is known. Its text in Hershey's
letters by Glyph_unicode, each placed, so in columns and with the
accents (the curly quotes drawn straight). `Mail_sync` and
`Conversations` out of Pim.ml, the commands' and the window's.
mini-pim is one program: a command, the terminal; none, the window
(`user=`, `server=`, `plain`); `apps/pim/sdl/` its window on Linux,
`bin/mini-pim`. Tests: `tests/frames.sh`, seven frames against
mini-maild (empty, fetched, read, back, search, All Mail, archive),
their sums in `frames.expected`, a `make test` job; mini-ml compiles
it (`compile_ix.sh` given apps/pim's includes, with lib_playground).
Not yet: labels other than Inbox and All Mail, the HTML of a message
(Mime.text's plain part only), scrolling with the mouse, IDLE, the
keys t (a task) and z (snooze) of stage 8. Next: stage 6, Gmail by the
author, by hand.

2026-10-29: the window's menu bar (the author: "those keyboard
shortcut are nice, but I think we also need a menu with those actions
available from the menus too"): Mail (Get Mail, Search..., Exit),
Conversation (Open, Back to List, Archive, Next, Previous), Go (Inbox,
All Mail), each item saying its key; a key and an item are one
command, done by one function. mini-office's dropdowns (Gui.menu_in).
Three more frames, by the mouse: a menu open, Get Mail, Archive.

2026-10-29: the app password from a file the author makes, the
store's `password` (`~/.ix-pim/password`), its first line, read by the
commands and the window before asking; refused, and said, when its
mode lets others read it. An app password stays valid until revoked
(or the account's password changed), so typed once into that file.
Tests: Unit_items (none, its line, refused), session.sh (a list with
nothing on standard input; the file opened to others refused).

2026-10-29: stage 6 begun without Gmail (the author away; what real
mail needs, as far as mini-maild can show it). HTML-only mail made
text: `Mail_text`, the plain parts when one is not blank, else the
HTML by browsers/html's `Line_mode` (the Line Mode Browser's text,
each link numbered, the links listed after), the attachments said a
line each; the window and `read` show it. All Mail found by its
`\All` (LIST, RFC 6154), not its name: a French Gmail's is
`[Gmail]/Tous les messages`; mini-pim still says `[Gmail]/All Mail`
in its store and flags (`Mail_sync.all_mail`), and mini-maild takes
the name (`-a`). Tests: Unit_mime (an HTML-only alternative in
Windows-1252, a plain part with a picture), session.sh (a mini-maild
in French).

2026-10-29: stage 7 begun, writing, from the terminal: `Mail_compose`
(pure: a reply, to all or not, Reply-To: first, Re: once, In-Reply-To:
and References: so it threads, the text quoted under "On <date>,
<who> wrote:"; a forward, Fwd:, the message's headers then its text;
a draft as an item stamped draft; the message sent, dated, its
Message-ID: at the sender's domain, the subject an encoded word and
the text quoted-printable when not ASCII, a multipart/mixed with
attachments). `mini-pim reply [-all] uid` and `forward uid` print the
draft, mutt's way: a file edited, then `send`, which sends a file with
`Attach:` (files) or `Forward:` (the message's attachments, from the
cache) as a draft. Sending moved into `Mail_sync` (`send`,
`send_draft`, `gmail_smtp`). Dates in +0000: mini-ml's Unix has no
localtime. Tests: Unit_compose (6), session.sh (a reply to all, sent
and as Carol has it; a forward with a file attached).
