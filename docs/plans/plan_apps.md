# Plan: the applications, what a person does with a computer and which of it ix lets them do (`apps/`)

The author (2026-10-29), after plan_gaps.md: "I wonder if we have
also important gaps in apps/"; then "I'm not necessarily talking
about gaps with the playground, more teaching gaps and apps that
could deserved to be in IX, just like office I think is. It's a
fundamental program for users in the end (and also useful for a
programmer)"; then "plan_gaps is really for the 'principia
softwarica' hardcore aspect; stuff a programmer should know, programs
that a developer use. but apps/ is different".

**Status: a survey, still a list to choose from** (as plan_gaps.md:
each application, when taken, gets a plan of its own). Mail, the
calendar and the address book are built, as mini-pim, on Linux only
so far; the table below says what is where. Taken next, by the author:
[`plan_files.md`](plan_files.md), [`plan_video.md`](plan_video.md) and
[`plan_maps.md`](plan_maps.md).

## The measure

plan_gaps.md asks what a programmer should know and ix does not show
yet. This plan asks something else: what a person does with a
computer, and whether ix lets them do it, with a program worth
reading. mini-office is the example: it is not there for a technique
missing from a textbook but because writing a letter, adding up a
column and drawing a figure are what a computer is for, to its user;
and it turned out to teach a great deal on the way (a piece table
with runs of looks, a sheet as a graph recalculated in Kahn's order,
recursive descent, bitmap against objects, undo as values kept).

So an application belongs here when:

1. a user would miss it: it is one of the few things everybody does
   with a computer, not a tool for programmers (those go to
   plan_gaps.md: four went there from this survey, see the end);
2. it can be small and whole, as mini-office is, on lib_gui and
   lib_playground, on Linux and on mini-9pi;
3. among those, the ones that bring a technique ix does not have
   come first. The technique is how to choose, not the reason to
   have one.

What the playground (`~/playground/apps/`) has is a source where it
has the application (TinyEudora, TinyCalendar, TinyPowerPoint...),
not the measure.

## What a user does, and what ix has

| What | In ix | On m-ix (the card) | Missing |
|---|---|---|---|
| Write, calculate, draw, present | mini-office (`apps/office/`), slides and their show included | yes: `office` | spelling |
| Read a document | mini-page (`apps/page/`): PDF and pictures | yes: `page` | |
| Listen | mini-play (`apps/music/play/`), mini-rebirth | yes: `play`, `rebirth` | a player with a library and playlists |
| Watch | mini-netscape hands YouTube's films to `mpv` on Linux | no | a video player |
| Write to people | mini-pim's Mail (`apps/pim/`) | **no** | chat |
| Keep time and people | mini-pim's Calendar, People, Tasks, Notes, Money | **no** | `date` still GMT only |
| Look at and fix photos | mini-page shows one; mini-office's paint, 1 bit | yes, those two | a viewer of many and an editor |
| Find a place | | | maps |
| Look after files | the shell, `ls`, `cp`, `mv` | yes | a file manager |
| Browse the web | `browsers/` (lynx, netscape) | yes: `lynx`, `netscape` | |
| Play | `games/` | yes | |

Surveyed (2026-10-29) from the directories and the headers of
`apps/`'s programs, `utilities/`, `lib_networking/`,
`lib_audio/formats/`, `lib_graphics/images/` and `lib_crypto/`;
what is marked *checked* below was read in the code. Brought up to
date 2026-10-30, from `kernels/9pi/Makefile`'s `CARD_*` lists and each
directory's `mkfile`.

mini-pim is the one row built for Linux only: `apps/pim/` has dune's
build and no `mkfile`, so mini-mk does not make it and it is not on
the card. mini-ml compiles its files (`compile_ix.sh`), but the
program has not been run on mini-9pi (plan_pim.md's Status). t-IX has
office, play, a browser and a calculator, and no mail or calendar.

## The applications, by what a person does

Each: what it would be, what ix already has under it, and what it
brings that ix does not show.

### Mail

**Done, on Linux**: mini-pim's Mail ([`plan_mail.md`](plan_mail.md),
stages 1 to 5), the author's Gmail by IMAP and SMTP, mini-maild to
test against. Not as sketched here: a store of items rather than
upas/fs's file tree, and the Screener (HEY's) rather than a Bayes
filter, which is still open. Left: plan_mail.md's stage 6 and
mini-9pi.

The survey's text: the largest hole, the oldest thing people do
between computers, and ix had nothing for it.

- **What**: a reader (the mailboxes, a message, its parts, a reply),
  sending by SMTP and reading by IMAP or POP3, over TLS.
- **Under it in ix**: TLS 1.2 and 1.3 and TCP (`lib_networking/`,
  mini-9pi's own stack), base64 (`lib_networking/tls/Base64.ml`,
  *checked*); mini-office's text for writing one.
- **What it brings**: RFC 822's headers; MIME, where a message is a
  tree of parts, each encoded (base64, quoted-printable) and typed;
  a mailbox as a file (mbox) and Plan 9's way, upas/fs, where the
  mailbox *is* a file tree served by 9P, a message a directory, a
  part a file (beside `windows/`'s rio, the other file server a user
  sees). And a spam filter by Bayes (Graham's "A Plan for Spam",
  2002): ix's first program that learns from examples.
- **Source**: Plan 9's upas; the playground's TinyEudora.

### Photos

- **What**: a folder of pictures as thumbnails, one picture large,
  turned, cropped, its levels and colours changed, filters (blur,
  sharpen), layers; saved.
- **Under it in ix**: the decoders (`lib_graphics/images/`: JPEG
  baseline and progressive, PNG, GIF, XPM), mini-page's way of
  showing a picture (`Pageview.ml`, *checked*), mini-office's paint
  and `Part_image`, PNG's encoder (`Png.encode`, *checked*).
- **Missing under it**: a JPEG encoder (`Jpeg.mli` only decodes,
  *checked*); without it a photo edited is saved as a PNG, many times
  larger. Exif is skipped (*checked*), so a phone's photo taken upright
  would show on its side.
- **What it brings**: compositing with alpha (Porter and Duff,
  1984), the pair of mini-office's paint, which has one bit; a
  convolution; resampling (a thumbnail made well, not by dropping
  pixels); a histogram and levels; and dithering (Floyd and
  Steinberg, 1976) for a screen of few colours, which is
  `apps/misc/Colors.ml`'s 256 (*checked*: it explains the map, but
  nothing reduces a photograph to it).
- **Source**: the playground's TinyPhotoshop, TinyDeluxePaint.

### A calendar and an address book

**Done, on Linux**: mini-pim's Calendar and People
([`plan_pim.md`](done/plan_pim.md), which added tasks, notes and
money): RRULE, iCalendar and vCard, time zones in `time/Zone`, and
Google's calendars and contacts read. `date` itself is still GMT only.
Left, in that plan's Status: writing back to Google, and events moved
or deleted in the window.

The survey's text:

- **What**: a month and a week, events that come back (every Tuesday,
  the last Friday of a month), reminders; people, with their
  addresses, which mail uses too.
- **Under it in ix**: `cal` and `date`, both GMT only (*checked*:
  `Date.ml`'s header says /env/timezone is not read).
- **What it brings**: the calendar's arithmetic (the Gregorian rules,
  a day's number); repetition as iCalendar's rules say it (RRULE);
  time zones from the tz database, and summer time, the classic of
  what looks simple and is not; the formats others send (iCalendar,
  vCard). Plan 9's calendar(1), a file of lines grepped each morning,
  is the smallest one and the place to start.
- **Source**: the playground's TinyCalendar and its PIM (TinyPalmPilot:
  date book, addresses, memos, to-dos).

### Video

- **What**: a film played, with its sound, paused, sought.
- **Under it in ix**: JPEG's DCT (`lib_graphics/images/Dct`), MPEG's
  audio layers (`lib_audio/formats/mpeg_audio`), mini-play's output
  to /dev/audio.
- **What it brings**: MPEG-1's video: motion compensation, frames
  made from the frames before and after them (I, P, B), the order
  they are stored in against the order they are shown in; the system
  stream that interleaves sound and picture; keeping the two in step
  by the sound's clock. MPEG-1 is old enough to be simple and is
  JPEG's next chapter.
- **The catch**: a user's films are H.264 and later, not MPEG-1, so
  they would have to be converted first. It teaches a lot and plays
  little of what a user has, and whether a Pi 1 or 2 keeps up in OCaml
  has not been measured. The author's answer (2026-10-30): the
  historical formats, for their teaching value; `plan_video.md`.

### Spelling, in mini-office

- **What**: words not in the dictionary underlined as one types, and
  suggestions.
- **Under it in ix**: mini-office's text and its view.
- **What it brings**: McIlroy's spell (1978-1982): a dictionary fitted
  into very little memory by hashing and coding the hashes, prefixes
  and suffixes taken off before looking; suggestions by edit distance
  (Levenshtein; Norvig's corrector). Small, and in the program ix
  already has.

### Slides, in mini-office

**Done, and already there when the survey was written, which missed
it**: a presentation is one of mini-office's kinds, Slide > Show its
show (`Office.ml`'s header). It has no master, transitions or builds,
on purpose.

### Music, as a library

- **What**: mini-play's formats with a window: the songs by artist and
  album, a playlist, shuffle, a scope or an equalizer.
- **Under it in ix**: mini-play and `lib_audio/` (MOD, MIDI, MP3,
  Vorbis, WAV, ABC), mini-rebirth's panels.
- **What it brings**: the tags (ID3), a graphic equalizer (a bank of
  filters). Small.
- **Source**: the playground's TinyWinamp, TinyMediaPlayer, `Id3`,
  `Graphic_eq`.

### Chat

- **What**: an IRC client: channels, people, messages as they come.
- **Under it in ix**: TCP, TLS, lib_gui.
- **What it brings**: a protocol of lines both ways at once, the
  keyboard and the network waited on together: a process each, Plan
  9's way, against one loop over both. Smaller than mail and much of
  its plumbing.
- **The catch**: people chat on closed services an IRC client does not
  reach, so this teaches more than it serves.
- **Source**: the playground's TinyIRC.

### A file manager

- **What**: folders as windows of icons or lists, a file opened by
  its kind, moved by dragging.
- **Under it in ix**: the namespace, the decoders for thumbnails.
- **What it brings**: little technique; a user's view of the
  namespace, and the question of what opens what (Plan 9's plumber's
  rules against a table of types). For a user, it may matter more
  than its technique says.

### Maps

- **What**: a map moved and zoomed, a place found, a route.
- **What it brings**: projections (Mercator's, the web's), tiles at
  zoom levels, a spatial index (quadtree, R-tree), shortest paths
  (Dijkstra, A*).
- **Taken** (2026-10-30), with the weather: `plan_maps.md`. The data is
  fetched from the internet rather than kept on the card; OSM's tile
  policy forbids saving an area, so offline would need an extract.

## Proposed, by value for the cost

Done: mail, the calendar and the address book (mini-pim), and slides
(mini-office). What is left, in order (2026-10-30, the author's choice
for 1 to 3):

0. **mini-pim on m-ix**, before any new application: a `mkfile`, on
   the card, run on mini-9pi. Not a new program, but until then the
   largest row of the table is Linux only, against the rule that every
   m-ix program runs under mini-9pi.
1. **The file manager**: [`plan_files.md`](plan_files.md), a file's
   kind leading to its program.
2. **Video**: [`plan_video.md`](plan_video.md), the historical formats,
   played by `play` and from the file manager.
3. **Maps and the weather**: [`plan_maps.md`](plan_maps.md), fetched
   from the internet.
4. **Photos**: the big thing left that nearly every user does and ix
   cannot do, useful for real on the author's own JPEGs. It brings
   compositing, convolution, resampling and dithering, and needs a
   JPEG encoder, DCT's other half; the file manager's thumbnails come
   with it.
5. **Spelling** in mini-office: small, in the program already there.
6. **Music's library**: small, mostly what exists.
7. **Chat**.

## Moved to plan_gaps.md

Four that came up in this survey are a programmer's, not a user's,
and are in plan_gaps.md's "Tools a programmer uses": search by an
index (beside grep), sync by rsync's rolling checksum (beside
mini-git's deltas), a password store (Plan 9's secstore and factotum),
and symbolic algebra (beside hoc, bc and dc).

## Open questions

- Is the measure right: what a user does first, the technique as the
  way to choose among them?
- Mail on mini-9pi: against a real server outside (QEMU's network,
  the board's), or mini-maild, ix's own? (mini-maild now exists; which
  one to run there is still open.)
- Where they live: decided by what was built, each suite or program
  under `apps/` beside the others (`apps/pim/`, so `apps/photos/`).

## Status

2026-10-29: survey written. Nothing built.

2026-10-29: mail, the calendar and the address book taken together,
with tasks, notes and money, as one suite: [`plan_pim.md`](done/plan_pim.md),
its mail [`plan_mail.md`](plan_mail.md). Nothing built.

2026-10-30: mini-pim built (plan_pim.md done, plan_mail.md's stages 1
to 5), on Linux only. The table and the order above brought up to
date; slides found to be in mini-office already.

2026-10-30: the author takes the file manager, video's historical
formats, and maps with the weather. Their plans written, nothing built.
