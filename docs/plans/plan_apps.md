# Plan: the applications, what a person does with a computer and which of it ix lets them do (`apps/`)

The author (2026-10-29), after plan_gaps.md: "I wonder if we have
also important gaps in apps/"; then "I'm not necessarily talking
about gaps with the playground, more teaching gaps and apps that
could deserved to be in IX, just like office I think is. It's a
fundamental program for users in the end (and also useful for a
programmer)"; then "plan_gaps is really for the 'principia
softwarica' hardcore aspect; stuff a programmer should know, programs
that a developer use. but apps/ is different".

**Status: a survey, nothing built.** As plan_gaps.md, a list to
choose from: each application, when taken, gets a plan of its own.

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

| What | In ix | Missing |
|---|---|---|
| Write, calculate, draw | mini-office (`apps/office/`) | slides; spelling |
| Read a document | mini-page (`apps/page/`): PDF and pictures | |
| Listen | mini-play (`apps/music/play/`), mini-rebirth | a player with a library and playlists |
| Watch | | a video player |
| Write to people | | mail; chat |
| Look at and fix photos | mini-page shows one; mini-office's paint, 1 bit | a viewer of many and an editor |
| Keep time and people | `cal` and `date` (`utilities/time/`), GMT only | a calendar, an address book |
| Find a place | | maps |
| Look after files | the shell, `ls`, `cp`, `mv` | a file manager |
| Browse the web | `browsers/` (lynx, netscape) | |
| Play | `games/` | |

Surveyed (2026-10-29) from the directories and the headers of
`apps/`'s programs, `utilities/`, `lib_networking/`,
`lib_audio/formats/`, `lib_graphics/images/` and `lib_crypto/`;
what is marked *checked* below was read in the code.

## The applications, by what a person does

Each: what it would be, what ix already has under it, and what it
brings that ix does not show.

### Mail

The largest hole: the oldest thing people do between computers, and
ix has nothing for it.

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
  and `Part_image`.
- **What it brings**: compositing with alpha (Porter and Duff,
  1984), the pair of mini-office's paint, which has one bit; a
  convolution; resampling (a thumbnail made well, not by dropping
  pixels); a histogram and levels; and dithering (Floyd and
  Steinberg, 1976) for a screen of few colours, which is
  `apps/misc/Colors.ml`'s 256 (*checked*: it explains the map, but
  nothing reduces a photograph to it).
- **Source**: the playground's TinyPhotoshop, TinyDeluxePaint.

### A calendar and an address book

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

- **What**: a document of slides, shown on the whole screen, a key a
  slide.
- **Under it in ix**: mini-office's pages and parts are most of it.
- **What it brings**: little new; a mode of mini-office rather than a
  program. Worth it for the user, cheap.
- **Source**: the playground's TinyPowerPoint.

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
- **Later**: the data is the problem (an OpenStreetMap extract on the
  card), not the code.

## Proposed, by value for the cost

1. **Mail**, reader and SMTP and IMAP: the largest hole, on the TLS
   and TCP ix has; upas/fs's file tree its Plan 9 lesson. Then its
   spam filter.
2. **Spelling** in mini-office: small, in the program already there.
3. **Photos**: compositing, convolution, dithering, on the decoders
   already there.
4. **The calendar and the address book**, the address book shared with
   mail.
5. **Video**: MPEG-1, after the photos (the DCT and the colours).
6. **Slides** and **music's library**: small, mostly what exists.
7. **Chat**, **the file manager**; **maps** later.

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
  the board's), or a small one of ix's own to test against, as
  mini-httpd is for the browsers?
- Where they live: `apps/mail/`, `apps/photos/`... beside office,
  music and page, or by what they do (`apps/internet/` as the
  playground)?

## Status

2026-10-29: survey written. Nothing built.
