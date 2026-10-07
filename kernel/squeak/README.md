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

    mini-mk               _mk/7/kernel/squeak/kernel8.img: Squeak, its quiet start
    mini-mk SYSTEM=Squeak with what moves by itself: the atoms, the car driving
    mini-mk SYSTEM=Mini   MiniMorphic in it: fifty squares, black and white
    mini-mk DEPTH=16      a framebuffer of 16 bits (32 by default)
    mini-mk check         the boot under QEMU (SLOW=1: under mini-qemu too)

**The quiet start is the default**, because the machine is slow (mini-ml's
code: the plan's Status): with the atoms bouncing and the car driving, a
pass of the world is 88,000 bytecodes, a second under QEMU, and the
mouse is felt a second late. Quiet, a pass is 5,000, and the machine
works when one does something. The atoms are in the world's menu (the
left button on the grey), and a click on the car script's `paused`
starts the car.

**QEMU's window**: its SDL one shows nothing on the author's desktop
(black, for every kernel, while a screen's dump has the picture); its
GTK one works. A QEMU built for `raspi4b` wants GTK's development
package when it is configured (`--enable-gtk`).

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
| `Host` | 152 | what Smalltalk's machine asks of what is under it (the mouse, the keys, a clock, the Transcript), from the board: the kernels' USB keyboard and mouse, the serial line's characters as keys, the generic timer, the serial line; the Display shown on the framebuffer, 800 by 600 in 32 bits, its own bytes written as they are (or in 16, converted); and the pointer, which Squeak does not draw |
| `Main` | 27 | the boot: the devices, Smalltalk brought up and its world started (`Squeak`, languages/smalltalk's), then the world's cycle for ever |
| `host.c` | 55 | the milliseconds since the start; the Display's pixels made 16 bits |
| `mkfile` | 149 | the image: these, `machine/`, languages/smalltalk's objects, mini-ml's runtime and the standard library |

`machine/` (links): `Machine` (the board, as the other kernels see
it), the Pi 4's C and assembly, the kernels' USB keyboard and mouse
(`Usbhost`). `tests/`: the boot's lines for each system.

Smalltalk's text (6,547 lines) is in the image as strings and is
compiled at each start: 555,323 bytecodes and some five thousand
million instructions to the first screen.

## The check

`mini-mk check` boots the image under QEMU and compares the serial
line with `tests/boot.quiet.expected` (`boot.squeak.expected`,
`boot.mini.expected` with `SYSTEM=`), and **the first screen with the
one mini-smalltalk draws on Linux** for the same system after one
cycle of its world (`mini-smalltalk -k quiet -world 1 -ppm`, dune's
build): the same pixels. So no picture is kept here; Smalltalk's own tests
(`languages/smalltalk/tests`) hold its screens. It is in none of ix's
suites: run it here, by hand. Never run on the board itself.

Not in the check, tried by hand under QEMU (QMP's mouse and keys): the
pointer moved into the Workspace, a click, two characters typed, which
appear at the caret, a second between two.
