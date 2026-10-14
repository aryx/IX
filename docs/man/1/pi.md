\title{pi}{1}

# NAME
pi – a Raspberry Pi kernel built and booted

# SYNOPSIS
**pi** \[ **-gwqdnvP** ] \[ **-c** *n* ] \[ **-p** *pixels* ] *kernel*

# DESCRIPTION
*Pi* builds a kernel, its card and the emulator, then boots the kernel
under \man{qemu}{1}, or under QEMU with **-q**, with the command line each
kernel wants. It is a script of ix's tree, for Linux, not a program of
ix's own system. With no *kernel*, it lists them.

ix's kernels, on the Pi 1; a `4` after the name is the same on the Pi 4
(`mini-9pi4`, `mini-oberon4`), and `mini-9pi2` is mini-9pi on the Pi
2's four cores:

`mini-9pi`
:    Plan 9's kernel in OCaml, with ix's programs, to rc's prompt; its SD
     card is ix's own, mounted on `/root`.

`mini-xv6-pi1`
:    xv6 in OCaml, with xv6's `fs.img`.

`mini-oberon`
:    The Oberon system in OCaml; it draws.

`mini-squeak`
:    Squeak on the bare Pi 4; it draws.

`mini-singularity`
:    Singularity's processes, isolated by the language and not by the
     memory's hardware; a console, no graphics.

The kernels of others, and ix's with others' programs:
`mini-9pi-principia` (mini-9pi with principia's programs and card),
`9pi` (principia's), `xv6`, `xv6-pi1` and `xv6-pi4`.

**-g**
:    A window: the framebuffer, and a USB keyboard and mouse. A click takes
     the mouse, Control-Alt-G gives it back.

**-w**
:    The SD card's image written; by default its writes are lost at the end.

**-q**
:    QEMU, with the same arguments, to compare.

**-d**
:    The emulator's log of memory not mapped and instructions not known.

**-n**
:    Nothing built: the emulator and the kernel as they were last built.

**-v**
:    Each step's output and its time, and every 2 seconds where the board is.

**-p** *pixels*
:    mini-9pi's drawing: `ocaml` (the default) or `c`, principia's.

**-P**
:    mini-9pi2's cores each on a core of the host's (\man{qemu}{1}'s
     **-cores-parallel**).

**-c** *n*
:    xv6-pi4's cores, 1 to 4: 1 when not said.

Control-A then `x` ends it, or the window closed.

# EXAMPLES
```
./mini-pi mini-9pi
./mini-pi -g mini-9pi
./mini-pi -q -g mini-oberon
```

# FILES
`$XV6`, by default `~/xv6`: xv6's ports, built. `$PRINCIPIA`, by
default `~/principia`: 9pi built, its card.

# SEE ALSO
\man{qemu}{1}
