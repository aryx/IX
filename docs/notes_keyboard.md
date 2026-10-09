# Notes on the keyboard: where keys were lost, late, stuck or doubled

The author, 2026-10-09, mini-emacs's arrow late on mini-9pi: "I feel
we have lots of issues with the keyboard and its special key and
repeat rate and draining ... we should write a note document about
this, how it became a problem in emacs, the playground, etc. as we
encountered it", "and whether there are general patterns of solutions
to apply".

Twelve problems in two weeks, in the kernel, the window system, the
playground's loop, two editors' hosts. Each has its row in
[`plans/bugs/ix.md`](plans/bugs/ix.md), with its reproduction; here
they are side by side, by what was wrong, and what they have in
common.

## The path of a key

    a key down or up
      -> the USB keyboard's report (its whole state, or QEMU's queue of changes)
      -> the kernel: usbd or Kusb reads the endpoint; Kbd makes of scan codes
           /dev/kbd    messages: the keys down now ("k..." "K...")
           /dev/cons   characters: runes, a line at a time or raw (consctl)
      -> mini-rio, in a window: its own cons and kbd files, served by 9P
      -> the program's host: Plan9_loop (the playground's games and apps),
           Window_draw (a Tui program: mini-turbopascal, mini-emacs),
           or on Linux SDL's events, or a terminal's bytes (Tty_unix)
      -> the program: an event (a key's name, a character), an update, a screen

Five stations, each with a buffer, and two files for one keyboard.
Every problem below is one of: a buffer that drops or keeps too much,
two streams nothing orders, a program slower than the keys, or a key
that does not mean on one station what it means on the next.

## What happened

| | where | what one saw | what it was |
|---|---|---|---|
| 1 | QEMU's USB keyboard, the kernel's read of it (2026-10-08) | a key held stays down after it is let go: a maze turning by itself | QEMU keeps the keys' changes in a queue of 16 and drops what comes when it is full; the kernel read the endpoint once an interval, fewer reads than a held arrow's 60 codes a second: the key's up was dropped. A real keyboard says its whole state |
| 2 | a real Pi1 (2026-10-08) | no keyboard at all | three things of the USB controller an emulator does not ask |
| 3 | the console, after a program that asked raw (2026-10-08) | no echo of what is typed | raw was turned off at `rawoff` only, not when the program ended |
| 4 | mini-rio, after a program that read the keyboard ended (2026-10-06) | the next line typed is shown and not run | a read left waiting by the dead program was answered with the line |
| 5 | Kbd's table (2026-10-09) | Control-F9 runs the program and breaks the line too | Plan 9's table gives a control character for Control and an F key (a carriage return for F9): the key came twice, as a `/dev/kbd` message and as a character |
| 6 | Kbd, Alt (2026-10-09) | Alt-F does not open the menu | Alt is Plan 9's compose key: Alt and a letter was the start of a sequence, nothing typed |
| 7 | the playground's loop, `Plan9_loop` (2026-10-09) | an Enter comes before the end of the line typed before it | a key's down is `/dev/kbd`'s, a character `/dev/cons`'s: two files, two readers, and with a frame of seconds the kbd was nine characters ahead |
| 8 | the same loop (2026-10-09) | an Enter that comes with characters in one tick is lost, two in one tick are one | a tick had "what was typed" and "the keys down", and a program took one or the other |
| 9 | mini-drscheme (2026-10-09) | a line typed fast is not run | the program asked whether the line was whole before the frame's typed text was in it: on Linux a frame is 16 ms and no key is that short |
| 10 | mini-turbopascal's host (2026-10-09) | the arrow is late | the whole screen (5,763 cells) was made and compared twenty times a second, a key or none: the program never waited, and the keys queued behind it |
| 11 | mini-emacs's host (2026-10-09) | no key seems to do anything | the fix of 10 paints when the model is another value; mini-emacs's was one value changed in place |
| 12 | mini-emacs (2026-10-09) | an arrow held goes on after it is let go, the next key comes seconds later | each key was a whole screen made again (the rows, the colors), some seconds of them queued while the arrow was held |

## The patterns

**A. A program slower than the keys queues them, and then lives in the
past (10, 12; 1 in the kernel).** A keyboard repeats thirty times a
second; under an emulator a screen can take a second. Nothing is
lost, which is the trouble: every key is honored, late. Three answers,
by cost:

1. *Wait for a key, do not poll.* A loop that makes a screen at every
   tick has no time for keys (10). The host sleeps in `Event.select`
   and makes a screen only when the model is another.
2. *Take all the keys that are there before painting.* The screen
   after ten keys is one screen, not ten (`Window_draw`'s `more`,
   since 10). It needs an update that is cheap without its view: so
   the update must not draw, and a model must say cheaply that it
   changed (11: a model changed in place cannot; mini-emacs gives a
   box made again).
3. *Make the common key cheap.* A key that moves a cursor changes two
   cells. Keep what was made and what it was made of, and make again
   only when that changed (mini-turbopascal's `Turbo_view.cache`,
   mini-emacs's `Frame.cache`: a line down was 1,900 ms on arm under
   mini-5i, and is 140), and let the host skip the rows that are the
   same rows (`Curses.take` and `same`).

What was not done, and is the last answer: *drop repeats*. A key that
is a repeat (the same key, no key up between) could be thrown away
when the program is behind, keeping the last; a terminal's bytes do
not say which keys are repeats, `/dev/kbd` does.

**B. Two streams for one keyboard have no order between them (5, 7,
8).** Plan 9 gives the characters typed (`/dev/cons`) and the keys
down (`/dev/kbd`) in two files. A game wants the second (a key held,
two keys at once), an editor the first (what was typed, in its
order), and a program that reads both must choose, key by key, which
file says it: never both. The rule the hosts follow now: what edits
a text (a character, Enter, Backspace, Tab, Escape) is the console's;
what is held (arrows in a game, modifiers) or has no character (an F
key, Alt and a letter) is the kbd's; and a key of the second kind
must not also put a character on the console (5: the table changed).

**C. A tick is not a unit of typing (8, 9).** A frame that asks "what
was typed this frame" and "which keys are down" has lost the order
within the frame, and a program written where a frame is shorter than
a key breaks where it is longer. An event is a key; a tick is time.
`Tui`'s programs have that (`Key`, `Tick`), the playground's loop
gives a key that edits a tick of its own.

**D. State kept for a reader that is gone (3, 4).** Raw mode, a read
waiting: when the program that asked ends (or is killed), what it
left must be undone by who kept it, on the close of its file, not on
the request that would have ended it.

**E. An emulator is not a keyboard (1, 2), and a script is not a hand
(9).** QEMU's keyboard has a queue a real one has not; a real board
asks what no emulator does; a test that types at 0.3 s a key, or all
of a line in one frame, sees other bugs than a person. Each of these
was found by the author typing, then given a script that does what
the hand did (`kernels/9pi/tests/perf/held.py`: a key pressed again
thirty times a second).

**F. A key's name differs at each station (5, 6, and mini-emacs's
Meta).** Plan 9's Alt composes, a terminal's Alt is Escape before the
key, SDL's is a modifier; Control and an F key is a rune, a control
character or a message. One vocabulary in the middle (the bytes a
terminal sends: `Vt.key`, `Cells.key`), each host translating into
it, and the program its own names from it (`Keymap.of_bytes`). What
a station cannot say is said another way and written in the help
(Escape then the key for Meta; Escape then a digit for an F key).

## What to check in a new program or host

- Does it wait, or does it poll? What does it cost when no key comes?
- What does one key cost, and what does the commonest key cost? Under
  mini-5i (`-keys` with forty arrows), not only on Linux.
- Are the keys there taken before the screen is painted?
- Which file says each key, and does any key come twice?
- What does it leave behind if it is killed (raw mode, a read)?
- An arrow held five seconds then let go: does it stop? Then the
  other arrow: at once? By hand, and under QEMU and on a board.
