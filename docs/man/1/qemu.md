\title{qemu}{1}{emulators}

# NAME
qemu – a Raspberry Pi, emulated

# SYNOPSIS
**qemu** **-M** *board* \[ *option* ... ]

# DESCRIPTION
*Qemu* is a Raspberry Pi in a program: its processor (ARM, 32 bits for
the Pi 1 and 2, 64 for the Pi 4), its memory, timer, interrupts, UARTs,
SD card, framebuffer, USB and sound, enough of each for the kernels ix
runs on it (mini-9pi, mini-xv6, xv6, Plan 9, Oberon). It is started as
QEMU is, with the options QEMU takes for a Pi, so that one command line
runs either. The UART is the terminal, raw: Control-A then `x` ends it.

**-M** *board*
:    `raspi1ap`, the Pi 1; `raspi2b`, the Pi 2; `raspi4b`, the Pi 4.

**-kernel** *image*
:    The kernel, put where the board's firmware puts it.

**-device** `loader,file=`*f*`,addr=`*a*
:    The file *f* put at the address *a*, and run from there. `cpu-num=`*n*:
     where the Pi 2's core *n* starts.

**-bios** *f*
:    The file put at 0x8000.

**-drive** `file=`*f*`,if=sd`
:    The SD card's image; `snapshot=on`, what it writes kept in memory and
     lost at the end.

**-m** *size*, **-smp** *n*
:    The memory, and the cores: of the Pi 2's four, one runs unless said.

**-nographic**
:    No window. With one, the framebuffer is drawn in it, and the keyboard
     and mouse are USB devices if `-device usb-kbd` and `-device usb-mouse`
     say so; `-display none` is **-nographic**.

**-device** `usb-net`
:    A network, QEMU's user network: the board's connections made by the
     host's.

**-serial** *s*
:    `stdio`, `mon:stdio` or `null`: where the first UART, then the second,
     writes.

**-audiodev** `wav,path=`*f*
:    What the Pi 1's jack plays, written as a WAV file at the end, and
     played in a window.

**-qmp** `unix:`*path*`,server,nowait`
:    QEMU's machine protocol, on a socket: the state, the screen as a PPM
     file, keys sent, the end. What the tests use.

Its own options, which say what they find on the standard error:

**-ips** *n*
:    Instructions run in a microsecond of the board's: 30 when not said. 200
     is a real board's pace for a game.

**-cores-parallel**
:    The Pi 2's cores each on a core of the host's, when built by OCaml 5;
     else they take turns, and a run is the same each time.

**-d**
:    Memory not mapped and instructions not known, said.

**-trace** *n*, **-prof** *f*, **-status** *n*, **-symbols** *elf*
:    The Pi 4's first *n* instructions; the program counter counted into
     *f*; where the board is, every *n* seconds, its functions named from
     *elf*.

**-meters** \[ `on` | `off` ]
:    The processor and the network watched: in the window, graphs under the
     screen; without one, a line a second.

`-cpu`, `-monitor`, `-append`, `-netdev`, another `-display`,
`-no-reboot` and `-S` are taken and not looked at.

# EXAMPLES
```
qemu -M raspi1ap -kernel kernel.img -nographic
qemu -M raspi1ap -device loader,file=kernel-pi1.img,addr=0x8000 -nographic
qemu -M raspi4b -cpu cortex-a72 -m 2G -smp 1 -kernel kernel -nographic
```

# SEE ALSO
\man{pi}{1}, \man{5i}{1}
