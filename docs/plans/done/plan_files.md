# Plan: mini-files, a file manager that opens each file with its program (`apps/files/`)

The author (2026-10-30), after plan_apps.md: "I think we could do a
file manager that would dispatch to the appropriate 'player', and then
support mpeg and play them with 'play' or via the new file manager."

**Status: done** (`lib_mime/`, `apps/files/`): stages 1 to 4; what is left below. Its video is
[`plan_video.md`](plan_video.md).

## What it is for

Folders in a window, and a file opened by a double click or Enter
without knowing which program reads it. It is the one program that
makes the others a system to someone who does not live in the shell:
mini-office, mini-page, mini-play, mini-emacs and mini-netscape become
what a file's kind leads to.

It runs on mini-9pi from its first stage, with a `mkfile` and on the
card (mini-pim, built on Linux first, is still not there).

## The idea: a file's kind, then a rule

    the file's first bytes --Kind--> application/pdf, video/mpeg, ...
    (its name, when they say nothing)      |
                                           v
    ~/.mailcap's rules, then the built-in table: page %s, play %s, ...
                                           |
                                           v
                     the program started, in a window of its own

**The bytes first, the name after**, as file(1) (1973) and VLC's
demuxers: a name can lie or say nothing. The playground's `Media`
already does it for sound, pictures and film (185 lines, with the
history in its `.mli`); it gets the rest of what ix reads (PDF, HTML,
text, mini-office's documents, iCalendar, vCard).

**One table of rules, shared with the browser.** `Browser_helpers`
already reads the same thing: `~/.mailcap` (RFC 1524) and built-in
rules, from a content type to a program. mini-netscape's "what I do not
show goes to a helper" and mini-files' "what I am not goes to a program"
are the same question, so the rules move to a small library both link
(`lib_mime/`: not `lib_core`, which every program of ix links). Then a `video/mpeg` link in
mini-netscape goes to mini-play too, as Mosaic's went to mpeg_play.

**`mini-open file`** is the same dispatch for the terminal (macOS's
open, Linux's xdg-open) and takes three lines over the library.

Not taken: Plan 9's plumber. Its rules are a small language over text
and messages sent to a running program, which is the better answer for
"this word in my editor is a file name", and a larger one than "this
file, which program". It stays the question to come back to if
mini-emacs or mini-rio's terminal wants to open things too.

## Starting a program

| Where | How |
|---|---|
| Linux | a process beside it (`Browser_helpers.run`) |
| mini-rio | `new` written to `/dev/wctl`: a window of its own |
| mini-9pi, the bare screen | not started: the status line asks for rio first (decided in stage 2: a program there would fight this one for the screen, the mouse and the keys) |

## What it shows

- A list (name, size, day), sorted by any of them, and icons, each kind
  with its own. Thumbnails come with the photos (plan_apps.md), not here.
- The path as buttons, the parents one click away; a back key.
- Copy, move, rename, delete, a new folder; dragging, as `cp` and `mv`
  do it, through `FS` and capabilities (`Cap.readdir`, `Cap.open_out`).
  Delete asks first; there is no Trash at the start.
- What it does not do: network places, a search index, previews beyond
  the thumbnails later.

## What it brings

Little technique, by plan_apps.md's own measure, and that is accepted:
it is here for its user. What it does show: magic numbers, and the Finder's
history against the shell's (Xerox Star, 1981; the Macintosh, 1984;
Norton Commander's two panes, 1986), which goes in the `.mli` header.
Plan 9, which had no file manager, is the other half of that story.

## Stages

1. **Kind and rules**: the library, `Media` copied and extended,
   `Browser_helpers` moved onto it (its tests still passing), `mini-open`,
   and unit tests of each kind from the repository's own sample files.
2. **The window**: the list, moving around, opening; on Linux and on
   mini-9pi under mini-rio, on the card. Recorded frames in `make test`.
3. **Changing files**: copy, move, rename, delete, a new folder, each
   checked on a scratch directory by a session.
4. **Icons**, and dragging.

Estimate: 800 to 1,200 lines of `.ml`, an estimate and not a measure.

## Open questions

- Two panes (Norton's) or one window a folder (the Finder's)? Proposed:
  one pane at the start, the cheapest to read.
- The name: mini-files (`files` on the card) proposed.

## Status

2026-10-30: plan written. Stage 1 done: `lib_mime/`'s `File_kind` (the
playground's magic numbers, the answer a content type, 15 of the
repository's samples and every other magic in its tests) and `Helpers`
(`Browser_helpers` moved, its tests unchanged, with rules for what ix's
programs read); `mini-open`, on the card as `open`. `mini-page` reads
PNG and JPEG only, so GIF has no rule yet; mini-office takes no file on
its command line, so its documents have none either.
Stage 2 done: `Folder` and `Files`, the list, sorted by a click on a
column, the path as buttons, Backspace, `b`, Enter and a double click;
under mini-rio `Helpers.run` writes `new` to `/dev/wctl`. `root=` keeps it
under a folder, which the frames' fixture needs. Checked by 14 recorded
frames and 3 sessions of what it starts, on Linux.
Stage 3 done: `c`, `x`, then `v` in the folder wanted (the Finder's way,
one pane), `r`, `n`, `d` asking first, only `y` deleting. Nothing
overwrites, a move elsewhere is a copy then a removal, a copy failing
halfway removes what it made. A symbolic link is never followed: deleted,
the link goes and not its target; a tree holding one is refused a copy or
a move to another folder, since Plan 9's calls have no links to make.
Checked by `apps/files/tests/changes.sh` on a scratch tree, by both
compilers' programs.
Stage 4 done: `Icons`, ten of them, drawn of shapes, each row's kind read
when it is on the screen, four a frame; a row dragged onto a folder, or
onto a folder of the path, is moved there.

Left: mini-files has not been run under mini-rio on mini-9pi (it builds for
Plan 9, the card lists it). `Sys_plan9.is_device` is false on Plan 9, so
selecting `/dev/mouse` there would wait (`bugs/ix.md`). A big copy stops the
window while it runs. No Trash, as planned at the start. Office documents have
no rule yet (mini-office takes no file). GIF and video go to mini-play since
plan_video.md's stage 5.
