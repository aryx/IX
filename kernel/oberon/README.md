# kernel/oberon/

mini-oberon: Wirth and Gutknecht's Oberon system (*Project Oberon*,
the 2013 edition) as one sees and uses it, written in OCaml, running
on the bare Raspberry Pi 1 and Pi 4. Its plan, with what was decided
and what each stage found, is
[`docs/plans/done/plan_system_oberon.md`](../../docs/plans/done/plan_system_oberon.md).

It is not a twin: no pixel or byte is compared with the original.
What is kept is the look and the feel (the two tracks of tiled
viewers, texts everywhere, a command a name `M.P` clicked in any text,
the three keys of the mouse and their interclicks, Oberon's own fonts)
and the approach (the book's modules by their names and their
layering, the central loop, frames and messages, a text as pieces).
What is under is free: there is no Oberon compiler and no RISC5 code,
a module is an OCaml module, and the collector is mini-ml's.

## Running it

    ./mini-pi -g mini-oberon      the Pi 1, in a window
    ./mini-pi -g mini-oberon4     the Pi 4 (arm64)

from ix's root (`-q`: QEMU in mini-qemu's place; `-n`: no build). Or
here, by hand:

    mini-mk              _mk/7/kernel/oberon/kernel8.img (the Pi 4)
    mini-mk O=5          _mk/5/kernel/oberon/kernel.img (the Pi 1)
    mini-mk run          under mini-qemu, the serial line only
    mini-mk check        the session below (O=5: the Pi 1's)

It is built by ix's own tools only (mini-mk, mini-ml, mini-cc,
mini-asm, mini-ld: `PATH=../../bin:$PATH`), which want the standard
library built first (`mini-mk` in `lib_core/`; `mini-pi` does it).

## Using it

The mouse has three keys. In a text:

- the **left** key sets the caret; what is typed goes there;
- the **right** key selects, from where it goes down to where it goes
  up;
- the **middle** key runs the command whose name is under it
  (`System.Open`, `Edit.Store`...); what follows the name is its
  parameter, and a `^` there means the latest selection;
- a second key pressed while the first is held (an interclick): right
  then left deletes the selection; right then middle copies it to the
  caret; left then middle copies the latest selection to where the
  caret is put; left then right gives it the looks at the caret.

In the bar at a text's left: the left key brings the line pointed at
to the top, the right key goes back, the middle key goes to the place
in the text that the height in the bar says. Ctrl-c, ctrl-x and ctrl-v
copy, cut and paste; backspace deletes.

A viewer's menu (its first line, in inverse) holds commands as any
text does. Dragged with the left key, it moves the viewer's top up or
down; with the middle key held too, the viewer goes where the mouse
is let go, in either track.

`System.Tool`, at the right, lists commands to click. Those that are
here: `System.Open`, `Close`, `CloseTrack`, `Recall`, `Copy`, `Grow`,
`Clear`, `Directory`, `CopyFiles`, `RenameFiles`, `DeleteFiles`,
`SetFont`, `Watch`, `ShowModules`, `ShowCommands`, `ShowFonts`;
`Edit.Open`, `Store`, `ChangeFont`, `CopyLooks`, `Search`, `Locate`,
`Recall`; `Hilbert.Draw`, `Sierpinski.Draw`, `Checkers.Open`,
`Stars.Open` (and in its menu `Stars.Step`, `Run`, `Stop`, `Close`),
`Blink.Run` and `Blink.Stop`. A name that is no command (the
compiler's, `ORP.Compile`) says so in the log.

## What is in this directory

Everything mini-oberon is made of is here: its own files, and under
`machine/` and `tests/` the ones it shares with ix's other kernels,
each a symbolic link (`ls -l machine` says from where). Only the
language is outside: mini-ml's runtime and the standard library. The
mkfile says in full what the image is made of, and includes nothing of
`kernel/lib`.

The modules, each with Oberon's name, a directory a part of the system
(the book's chapters); the order they start in is the mkfile's
`OBERON`:

| directory | module | lines | what |
|---|---|---:|---|
| `files/` | `FileDir`, `Files` | 91 | the directory and the files, riders |
| `display/` | `Display` | 132 | the frame, its five operations in three modes; frames and messages |
| | `Input` | 24 | the mouse and the keyboard, as the loop asks them |
| | `Viewers` | 142 | the tracks and the viewers in them: opened, changed, closed |
| | `MenuViewers` | 182 | a viewer with a menu and a main frame |
| `texts/` | `Fonts` | 79 | Oberon's `.Fnt` files read |
| | `Texts` | 269 | the piece table; buffers, readers, writers, the scanner; a text's file |
| | `TextFrames` | 589 | a text shown and edited: lines, the caret, the selection, the scroll bar |
| | `Edit` | 129 | the texts' commands |
| `system/` | `Modules` | 14 | the commands' table (no loader: every module is in the image) |
| | `Oberon` | 211 | the loop, the messages, the cursors, the log, a command's call, the tasks |
| | `System` | 208 | the system's commands |
| `apps/` | `Hilbert`, `Sierpinski`, `Stars`, `Blink`, `Checkers` | 220 | programs of others: frames, messages and tasks of their own |
| (here) | `Main` | 30 | the boot: the devices, then the loop |

(Lines of the `.ml` files, 2026-10-06; each has a `.mli` that says what
it is and how it differs from Oberon's.)

How it differs from the book, in short:

- **A message is an exception's value** (`Display.msg = exn`): a
  module declares its own (`exception Step`) and a handler is a
  `match`. Oberon extends a record and tests its type.
- **A frame's own state is what its handler's closure holds**; Oberon
  extends the frame's record.
- **A text's pieces are a list of values**, cut and joined; Oberon's
  are a ring of records changed in place.
- **A text frame draws again the line that changed**, or from it down;
  Oberon moves the pixels and draws only what is new.
- **The display is the Pi's**, 16 bits a pixel, two colours of them;
  Oberon's is a bit a pixel.
- **The disk is a text in the kernel's image** (`FileDir.mli`), its
  files read into memory at the boot: what is written is lost when the
  machine stops. Oberon's own file system is a later stage.

`machine/` (links, but two): `Machine` (the board, as the other
kernels see it), the boards' C and assembly, mini-xv6's USB driver
(`Usbhost`). `Screen.ml` and `File.ml` there are not links: the two
names that driver calls, a line each that tells `Input`.

`disk/`: the files of the image. Oberon's nine fonts and `System.Tool`
are Project Oberon's, taken from a disk image of the 2013 system by
`fetch.py` (run once, not in the build) and kept under its licence
(`license.txt`); `Welcome.Text` is ours.

`tests/`: the session's steps and what it must show.

## The check

`mini-mk check` boots the image under mini-qemu and under QEMU with a
USB keyboard and mouse, plays `tests/session.steps` (keys typed, the
mouse moved, its keys pressed, by QMP) and compares the serial line
with `tests/boot.expected` and the screen after each step with
`tests/session.md5`. The screens are the same on the two boards and
under the two emulators.

It takes several minutes for a board and is **not in `make test`, nor
in any of ix's suites**: run it here, by hand, after a change. What
the suites do with this directory is compile it:
`languages/ml/tests/compile_ix.sh` (in `make test-lite` and
`make test-ml`) has mini-ml compile every `.ml` of ix, these too. And
`make loc` counts it apart, not in m-ix.

The steps are made by `tests/steps.py` from places on the screen (a
click on `System.Watch` is a move to where the word is): a change of
the layout or of `System.Tool` moves the words, and the steps with
them.

Not in the session, because they move by themselves and a screen's
MD5 would not hold: `Stars.Run` and `Blink.Run`, the tasks.
