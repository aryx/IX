# kernel/squeak/

mini-squeak: Squeak on the bare Raspberry Pi 4. The board starts a
virtual machine, the virtual machine starts Smalltalk, and there is
nothing else: no process, no file, no shell. Everything on the screen
(the windows, the menus, the Browser, the text typed, the atoms that
bounce) is an object drawn by Smalltalk, which its own Browser can
change while it runs. Its plan, with what each stage found:
[`docs/plans/plan_system_squeak.md`](../../docs/plans/plan_system_squeak.md).

Smalltalk itself is not here: it is `languages/smalltalk/`,
mini-smalltalk (the Blue Book's virtual machine in OCaml, the system
and Squeak's Morphic in Smalltalk, after the author's playground's),
which is also a command on Linux and, as `mini-squeak` there, the same
Squeak in a window. This directory is the third host: the board.

## Running it

    ./mini-pi -g -q mini-squeak     under QEMU, in a window (a click grabs the mouse)
    ./mini-pi -g mini-squeak        under mini-qemu: five minutes to the first screen

from ix's root (`-n`: no build). Or here, by hand, with ix's tools
(`PATH=../../bin:$PATH`; `mini-mk` in `lib_core/` and in
`languages/smalltalk/` first, which `mini-pi` does):

    mini-mk               _mk/7/kernel/squeak/kernel8.img: Squeak
    mini-mk SYSTEM=Mini   MiniMorphic in it: fifty squares, black and white
    mini-mk check         the boot under QEMU (SLOW=1: under mini-qemu too)

The Pi 4 only: on arm, OCaml's integers have 31 bits and the machine
wants 32 (the plan's Status, stage 1).

The mouse, by Smalltalk's colours: the left button (red) picks up
what does not want the mouse and puts it down, sets the caret and
selects in a text, picks in a list; the right (yellow) is a text's
menu (do it, print it, inspect it, accept); the middle (blue) puts a
halo on a morph. To see what it is for: in the Browser, change
`EllipseMorph>>drawOn:`, accept, and the atoms beside it are drawn the
new way at once. Control-C stops what runs too long. Nothing is saved:
what is done is lost when the machine stops.

## What is in this directory

| file | lines | what |
|---|---:|---|
| `Host` | 107 | what Smalltalk's machine asks of what is under it (the mouse, the keys, a clock, the Transcript), from the board: mini-xv6's USB keyboard and mouse, the serial line's characters as keys, the generic timer, the serial line; and the Display shown on the framebuffer, 800 by 600 in 32 bits, its own bytes written as they are |
| `Main` | 25 | the boot: the devices, Smalltalk brought up and its world started (`Squeak`, languages/smalltalk's), then the world's cycle for ever |
| `clock.c` | 21 | the milliseconds since the start |
| `mkfile` | 139 | the image: these, `machine/`, languages/smalltalk's objects, mini-ml's runtime and the standard library |

`machine/` (links): `Machine` (the board, as the other kernels see
it), the Pi 4's C and assembly, the kernels' USB keyboard and mouse
(`Usbhost`). `tests/`: the boot's lines for each system.

Smalltalk's text (6,547 lines) is in the image as strings and is
compiled at each start: 578,256 bytecodes and some five thousand
million instructions to the first screen.

## The check

`mini-mk check` boots the image under QEMU and compares the serial
line with `tests/boot.squeak.expected` (`boot.mini.expected` with
`SYSTEM=Mini`), and **the first screen with the one mini-smalltalk
draws on Linux** for the same system after one cycle of its world
(`mini-smalltalk -k squeak -world 1 -ppm`, dune's build): the same
pixels. So no picture is kept here; Smalltalk's own tests
(`languages/smalltalk/tests`) hold its screens. It is in none of ix's
suites: run it here, by hand. Never run on the board itself.

Not in the check, tried by hand under QEMU (QMP's mouse and keys): the
pointer moved into the Workspace, a click, two characters typed, which
appear at the caret while the atoms and the car go on.
