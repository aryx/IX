# t-ix: a programmer's manual

t-ix is the tiny half of ix (`tiny/`): a machine of our own design,
its assembler, a C and an ML compiler for it, and kernels that run on
it. This manual is the reference for someone writing a program or a
kernel for that machine: its registers, its devices and their
addresses, how a program is built and where it is loaded. It gathers what the
programs' headers say (`TinyMachineCPU.ml`'s, `TinyMachine.ml`'s,
`TinyKernel.ml`'s): they are the first source, and where this manual
and a header differ, the header is right. Each
program's header says how it works and why
([`tiny/README.md`](../../tiny/README.md) lists them); the plans say
how each was decided ([plan_tiny_os.md](../plans/plan_tiny_os.md),
[plan_tiny_windows.md](../plans/done/plan_tiny_windows.md),
[notes_tiny_kernel.md](../notes_tiny_kernel.md)).

The other tiny programs (tiny-shell, tiny-utils, tiny-editor,
tiny-prof, tiny-db, tiny-vcs, tiny-build) run on the host and on
tiny-kernel, the same file built by OCaml and by tiny-ml (`rc`, the
utilities, `ed`, `prof`, `db`, `vcs`, `build` in its `/bin`), and are
not covered here beyond that; so does the toolchain (`cc`, `ml`, `as`,
`ld` there), each making the host's files byte for byte
([plan_tiny_self_hosting.md](../plans/done/plan_tiny_self_hosting.md),
step 7; tiny-cpu stays the host's).

## 1. The quick way

    ./tiny-machine tiny-kernel    # TinyKernel.ml, a kernel in ML: a shell on the console
    ./tiny-machine -window tiny-kernel    # and its screen in a window: paint draws there
    ./tiny-machine t6             # t6, a step before it: a kernel in C, with its disk
    ./tiny-machine v0             # v0, the first step: a page of assembly and four programs
    ./tiny-machine kernel.tm a.tm # a kernel of yours, and its programs

`-l` prints the kernel's listing instead of running it, `-n` skips the
build, `-w` keeps t6's writes to its disk. Ctrl-D ends the
shell and the machine, Ctrl-\ quits at once, Ctrl-C goes to the kernel.

The script builds the tools with dune and calls them. By hand:

| tool | what it does |
|---|---|
| `tiny-c -o f.tm f.c` | C to the machine's assembly |
| `tiny-ml -o f.tm f.ml` | ML to the machine's assembly |
| `tiny-assembler f.tm` | the assembly to an object, `f.o` (`tiny/TinyAssembler.ml`; its `.mli` has the object's format) |
| `tiny-linker [-a n] [-map] -o out f.o...` | objects to an image, the first at 0 (`-a n`: an a.out for tiny-kernel that asks for n MB; `-map`: `out.map`, each label's address) |
| `tiny-cpu image` | runs a program alone, the host answering its three system calls |
| `tiny-machine image` | the same with the machine around the CPU: the image is a kernel's |
| `tiny-mkfs` | t6's disk image (`tiny/TinyKernel/steps/t6/TinyMkfs.ml`) |
| `tiny-prof p -k k.map -u p.map` | where the instructions went, by function, from a profile written by `tiny-cpu -prof p` or `tiny-machine -prof p` and the maps of the links (`tiny/TinyProfiler.ml`; its `.mli` shows how it found what made `www`'s scrolling slow) |

`tiny-cpu -h` and `tiny-machine -h` show each option on an example.

tiny-kernel's graphical programs also run on the host, in a window of
their own, with no machine: `tiny-office file`, `tiny-www OCaml`,
`tiny-emacs file`, `tiny-calc`, `tiny-tetris`; and `tiny-troff [-h |
-p] file` prints a document (§7.10).

## 2. How t-ix is put together

![Who builds what in ix](../pics/toolchains.svg)

The picture is all of ix's: t-ix is its right half. The rest of this
section is that half in words.

### 2.1 Two worlds

A tiny program is either the host's or the tiny machine's.

    the host (OCaml, built by dune or by ix's own tools)
      tiny-c, tiny-ml          compilers: C and ML to .tm assembly
      tiny-cpu, tiny-machine   the assembler, the linker and the machine
      tiny-mkfs                disk images
      tiny-machine-window      the screen in a window (SDL)
            |
            |  .tm files, linked to an image
            v
    the tiny machine (assembly, C and ML, built by the programs above)
      TinyCRuntime/              the C runtime
      TinyKernel.ml            a kernel in ML, and its programs
      TinyKernel/steps/v0, t6  the steps before it, in assembly and C
      TinyMLRuntime/core.c            the ML runtime, in C

`TinyKernel.ml` is in `tiny/` beside the host's programs but is not
one of them: OCaml never compiles it, tiny-ml does.

### 2.2 What a host program needs outside `tiny/`

Each is one file, but not all stand alone. From `tiny/dune` (and
`tiny/TinyKernel/steps/t6/dune`, tiny-mkfs's):

| program | outside `tiny/` |
|---|---|
| tiny-cpu, tiny-mkfs | `lib_core/`, `fpath`, `caps` |
| tiny-machine, tiny-shell, tiny-utils, tiny-editor, tiny-prof, tiny-db, tiny-c, tiny-ml, tiny-assembler, tiny-linker | `lib_core/`, `fpath`, `caps`, `unix` (the tools through the host's `TinyLibSystem`, `TinyKernel/host/`) |
| tiny-vcs, tiny-build | the same, and `lib_crypto/` (SHA-1; TinyLibCore's `Sha1` under tiny-ml) |
| tiny-machine-window | SDL by `tsdl` (`TinyMachine/TinyMachineSDL.ml`; mini-qemu has its own, `raspberry/video/Sdl_display.ml`) |
| tiny-machine-fetch | `lib_networking/` (DNS, TLS 1.3, HTTP), `lib_graphics/images/` (PNG, JPEG, GIF), `lib_compression/`, `lib_crypto/` |

Inside `tiny/`, two libraries are shared: `TinyMachineCPU.ml` (tiny-cpu
and tiny-machine) and `TinyMachineDevices.ml` (tiny-machine's machine without a host: the
terminal's program, `TinyMachine.ml`, and a web page's,
`TinyMachineWeb.ml`, built by OCaml and js_of_ocaml only:
`./tiny-machine -web dir tiny-kernel` makes the page's directory).

What they take from `lib_core/` is its `commons/`: `FS` (a file read
or written whole), `Console` (printing), `Procs` (children and
pipes). `caps` gives the capabilities each `main` takes (`Cap.stdin`,
`Cap.open_in`...), `fpath` the paths.

### 2.3 Two ways to build the host's programs

- **By dune** (`make`, or `dune build`): OCaml 4.14 with its standard
  library, and `caps`, `fpath` and `tsdl` from opam. The executables
  are `_build/default/tiny/TinyXxx.exe`, installed as `tiny-xxx`.
- **By ix's own tools** (`tiny/mkfile`, read by mini-mk): mini-ml
  compiles each file and mini-ld links it, with ix's standard library
  (`lib_core/`, where `Cap`, `Fpath` and `Unix` are ix's own). No C
  library is linked. All the programs of 2.2 are built so, but
  tiny-machine-window.

So a tiny program is written in what both accept, and ix's library
is the smaller one: it has no `Scanf`, for example, and its
`Option.value` takes no label.

### 2.4 How the tiny machine's programs are built

By Makefiles that call the host's tools, taken from the `PATH` or
from ix's `bin/`:

| Makefile | what it builds |
|---|---|
| `tiny/TinyKernel/steps/Makefile` | `libc.tm` (from `tiny/TinyCRuntime/`), `hello`, then each step |
| `tiny/TinyKernel/steps/t6/` | `kernel.img`, the user programs, `fs.img` (tiny-mkfs) |
| `tiny/TinyKernel/Makefile` | `kernel.img`, the user programs, `boot.img` |

Each writes what it builds in a `_make/` of its own directory, and
nowhere else (as dune's `_build/` and mini-mk's `_mk/`): the
directories show the sources, `make clean` removes `_make/`.

The steps are always the same three:

    tiny-c -o x.tm x.c          # or tiny-ml, for ML
    tiny-assembler -o x.o x.tm  # each .tm, the runtime's too
    tiny-linker -o kernel.img entry.o ... x.o              # a kernel: linked at 0
    tiny-linker -o prog start.o udivmod.o libc.o prog.o    # a program

TinyKernel.ml has no disk: `boot.img` is `kernel.img` followed by
its files, each a name, a size and its bytes, which the kernel reads
at its start. A line `link utils` in place of the size makes a hard
link instead, as the `link` call does: the name is given the same file
as `utils`, with no bytes of its own. That is how one program, `utils`
(`tiny/TinyUtilities.ml`, by tiny-ml), is `cat`, `ls`, `wc` and the 18
other utilities. At the prompt, `ln` makes one the same way.

### 2.5 What runs what

    ./tiny-machine tiny-kernel
      -> dune builds the host's tools
      -> make -C tiny/TinyKernel                (tiny-ml, tiny-c, tiny-assembler, tiny-linker)
      -> tiny-machine tiny/TinyKernel/_make/boot.img
           the kernel at 0, in supervisor mode
           -> /bin/sh in a partition, in user mode
                -> the programs it runs, each a process

## 3. The CPU (`TinyMachineCPU.ml`)

- **16 registers of 32 bits**, `r0` to `r15`. `r0` is always 0. By
  convention `sp` is `r14` and `lr` is `r15`.
- **No flags.** A branch compares two registers; `slt` makes a
  comparison a value.
- **One format**, 4 bytes an instruction: an 8-bit opcode, two 4-bit
  registers `d` and `a`, a 16-bit immediate whose low 4 bits name the
  third register.

| instructions | meaning |
|---|---|
| `add sub mul div rem and or xor shl shr sar slt sltu` | `d = a op b` |
| `addi andi ori xori shli shri sari slti sltiu` | `d = a op imm` |
| `lui` | `d = imm << 16` |
| `ldw ldb stw stb` | `d, imm(a)`: a word or a byte loaded or stored |
| `beq bne blt bge bltu bgeu` | `d, a, label` |
| `jal jalr` | a jump, `d = pc + 4` |
| `sys n` | a system call, its number `n` |

The assembler adds `li`, `la`, `mov`, `call`, `ret`, `j` and `nop`,
and the directives `.word`, `.byte`, `.ascii`, `.asciz`, `.space` and
`.align`. A comment starts with `;`.

Every case is defined: a division by 0 gives -1, a shift takes its
amount modulo 32, an address is taken modulo the memory's size, and a
word's two low address bits are ignored.

**Why `-16(r0)` is a device.** Since `r0` is 0 and addresses wrap, a
negative offset from `r0` is an address counted down from the top of
memory. The devices are there (section 5), so any instruction reaches
one without setting up a register: `stb r3, -16(r0)` prints a byte.

## 4. The machine (`TinyMachine.ml`)

The CPU with what a kernel needs. 128 MB of memory (16 MB until
2026-10-15). It starts at
address 0 in supervisor mode, with `sp` just below the devices.

### 4.1 Modes and traps

Two modes, supervisor and user. One way in: a trap saves the pc in
`epc`, the reason in `cause`, a detail in `tval`, enters supervisor
mode with interrupts off, and jumps to `tvec`. One way out: `eret`.

| `cause` | reason | `tval` | `epc` |
|---:|---|---|---|
| 1 | `sys n` | `n` | after the `sys` |
| 2 | an illegal instruction | the word | on it |
| 3 | a fault (an address not allowed) | the address | on the instruction |
| 4 | an interrupt | its sources, a bit each | on the instruction not yet run |

### 4.2 The registers of control

Read by `csrr d, name`, written by `csrw name, a`, both at once by
`csrrw d, name, a`. All three, and `eret`, are illegal in user mode.

| name | what |
|---|---|
| `status` | bit 1 supervisor mode, 2 interrupts on, 4 and 8 those two as they were before the trap, 16 the window relocates |
| `epc`, `cause`, `tval`, `tvec` | the trap's (above) |
| `time` | the instructions run so far (read only) |
| `timecmp` | the timer interrupts when `time` reaches it |
| `base`, `bound` | the window (4.4) |
| `satp` | the pages' root; its top bit turns pages on (4.4) |
| `ip`, `ie` | the interrupts pending (read only) and enabled, a bit a source |
| `hartid` | the core's number, 0 (read only) |
| `scratch` | a word for the kernel |
| `rate` | the machine's speed, in instructions per second (read only) |

The time is the count of instructions, not the host's clock, so the
same image with the same input runs the same every time. The `rate`
register says how many of those instructions make a second: 8 million
by default, or what `tiny-machine -rate n` asks for. A kernel reads it
to turn instructions into seconds.

One more instruction, legal in both modes: `amoswap d, a, (b)`, the
word at the address in `b` swapped with `a` in one step, for a lock.

### 4.3 Interrupts

An interrupt is taken when `status` has interrupts on and a source is
both pending and enabled. `tval` then holds the sources.

| bit | source | pending until |
|---:|---|---|
| 1 | the timer | `timecmp` is moved past `time` |
| 2 | the console's input | its bytes are read |
| 4 | the disk | its status word is written |
| 8 | the mouse | its word is read |

Only the timer is enabled at the start.

### 4.4 Protection: a window, or pages

In user mode, with pages off, an address must be inside the window.

- **Plain** (v0): `base <= address < bound`. A program is assembled
  where it runs.
- **Relocating** (`status` bit 16; t6, TinyKernel.ml): the address
  must be below `bound`, and `base` is added to it. Every program is
  assembled at 0.

With `satp`'s top bit set (no kernel of ix does since v6 was removed; `tiny/tests/TinyMachine_tests/paging.tm` does), addresses go through two-level page
tables instead, RISC-V's Sv32: 10 bits of index in the root table, 10
in the next, 12 in a 4 KB page. An entry's flag bits are 1 valid, 2
read, 4 write, 8 execute, 16 user. Supervisor mode reaches every
valid page.

## 5. The devices

Sixteen words at the top of memory, outside any window, so only a
kernel reaches them (two of them unused).

| address | | device |
|---|---|---|
| `-56(r0)` | `0x7ffffc8` | the date at the boot, read: seconds since 2000-01-01 (the host's clock, or tiny-machine's `-date`) |
| `-52(r0)` | `0x7ffffcc` | the speaker (5.6): written, its ring's address (0 off); read, the samples played |
| `-48(r0)` | `0x7ffffd0` | the network (5.5): a memory address |
| `-44(r0)` | `0x7ffffd4` | the network: a length; read, the length of the packet that waits, 0 if none |
| `-40(r0)` | `0x7ffffd8` | the network: the command, 1 send, 2 receive |
| `-36(r0)` | `0x7ffffdc` | the network: reads 1 when there is a wire |
| `-32(r0)` | `0x7ffffe0` | the disk: a block's number |
| `-28(r0)` | `0x7ffffe4` | the disk: a memory address |
| `-24(r0)` | `0x7ffffe8` | the disk: the command, 1 read the block into memory, 2 write it from memory |
| `-20(r0)` | `0x7ffffec` | the disk: reads 1 when a transfer is done; a write ends its interrupt |
| `-16(r0)` | `0x7fffff0` | the console's output: a byte stored is printed |
| `-12(r0)` | `0x7fffff4` | the halt: the value stored is the machine's exit status |
| `-8(r0)` | `0x7fffff8` | the console's input: the next byte; `0xffffffff` none yet, `0xfffffffe` the input's end |
| `-4(r0)` | `0x7fffffc` | the mouse (5.2) |

The disk is a file given by `-d`, in blocks of 1 KB. A transfer is
done at once, and the file is written back when the machine halts.

### 5.1 The screen

640 by 480 pixels, one byte each, row after row from `0xf00000`. It
is memory like any other: `stb` stores a pixel, and a kernel that has
no use for a screen may use that megabyte as memory.

A byte is a colour in Plan 9's table of 256 (its `m8` pixels): 0 is
black, 255 white, `0xf0` red, `0x36` blue, `0xaa` a grey.

    tiny-machine -window kernel.img          # the screen in a window of the host's
    tiny-machine -screen out.ppm kernel.img  # the screen written at the halt, a PPM

### 5.2 The mouse and the keys

The mouse is one word: x in bits 0 to 11, y in bits 12 to 23, the
buttons from bit 24 (1 left, 2 middle, 4 right). Its interrupt is
pending from a change until the word is read.

The keys have no register of their own: they are the console's input,
`-8(r0)`. Without a window they come from the terminal or a pipe.
With `-window` they are typed in the window; the arrows are the bytes
128 to 131 (up, down, left, right).

### 5.3 A session replayed: `-events`

    tiny-machine -events session.txt -screen out.ppm kernel.img

The mouse and the keys come from a file, a line an event, each with
the time (in instructions) it happens at:

    2000000 m 50 50 0        the mouse at 50, 50, no button
    2100000 m 300 150 1      there, the left button down
    2300000 k ls\n           these keys typed

In a `k` line, `\n` is a new line and `\` with three digits a byte
(`\003`). The input ends after the last event. As the time is the
instructions counted, the screen at the halt is the same on every
run: this is how a program with a mouse is tested
(`tiny/tests/TinyMachine_tests/screen.tm`).

### 5.4 The window is another program

`tiny-machine -window` runs `tiny-machine-window`
(`TinyMachineWindow.ml`) as a child. It sends it the screen, a PPM
each time it changed, about thirty times a second, and reads back
event lines, section 5.3's without their times; a step of the mouse's
wheel (or of two fingers on a trackpad) comes as an arrow key, up or
down. When a program changes the mouse's look (it writes the mouse's
word: 0 the arrow, 1 a hand, as `www` does over a link), it sends the
line `C n` between two pictures. tiny-machine itself links no C
library, so ix's own tools build it; the window is the one tiny
program that needs SDL, by `TinyMachineSDL.ml`.

### 5.5 The network

A wire with two ends, the machine at one
([plan_tiny_network.md](../plans/done/plan_tiny_network.md)); tiny-kernel
uses it (`ping`, `get`, and `dial` among its calls). A packet is at most 2,048 bytes.

- **To send**: the packet's address at `-48(r0)`, its length at
  `-44(r0)`, then 1 at `-40(r0)`.
- **To receive**: the network's interrupt (source 16) is pending
  while a packet waits; `-44(r0)` reads its length. A buffer's address
  and size written as for a send, then 2 at `-40(r0)`: the packet is
  copied (no more than the size) and the next one waits.
- At most 64 packets wait; one more is lost.

What is at the other end is the host's choice:

    tiny-machine -net dir kernel.img         # tiny-machine itself, at 10.0.0.1 (the machine is 10.0.0.2)
    tiny-machine -net dir -net-trace kernel.img   # and each packet said on the standard error
    tiny-machine -net dir -net-lose 3 kernel.img  # and its third packet is lost
    tiny-machine -net dir -net-pcap f kernel.img  # and the packets written in f at the halt (tcpdump -r f, Wireshark)
    tiny-machine -net dir -net-out kernel.img     # and it is the way to other machines
    tiny-machine -net dir -net-forward 8080:80 kernel.img   # and the host's port 8080 is the machine's port 80
    tiny-machine -net-loop 100 kernel.img    # the wire itself: each packet sent comes back 100 instructions later

With `-net` the other end is `TinyKernelNetwork.ml`, the file tiny-kernel
has for its own stack, run by the host (`TinyMachinePeer.ml`). A packet
of its lands 5 ms of the machine's time (40,000 instructions at 8
million a second) after
it was sent. It answers a ping; and on port 70, over IL, it reads a
line, a name, and sends `dir`'s file of that name (no path), in
messages of 1,024 bytes, then closes: `get hello.txt` in tiny-kernel,
with `tiny/tests/www` as `dir`. The other way, `put file [name]` sends
a line `put name size` then the file's bytes, and the peer writes them
into `dir` and answers `ok`: tiny-kernel's files are in its memory and
go with the machine, what is put stays. An empty line (`get ''`,
Gopher's menu) lists `dir`, so a new boot brings it all back with
``for(f in `{get ''}) get $f > $f``. The web page keeps what is put in
the browser's `localStorage`. A trace's line is the machine's time,
the direction (`>` from the machine, `<` to it, `x` to it and lost)
and the packet:

        856.2 ms  > echo? 1, 4 bytes, from 10.0.0.2 to 10.0.0.1
        856.2 ms  < echo! 1, 4 bytes, from 10.0.0.1 to 10.0.0.2

A line that starts with `www` asks for a web page, for tiny-kernel's
browser (`docs/plans/done/plan_tiny_browser.md`). The other end sends the
page's bytes as the site sent them, then closes. The rest of the line
is an address: a bare title such as `OCaml` or `Plan 9 from Bell Labs`
is an English Wikipedia article, and an article's address is changed
to its REST HTML (the article without the site's menus;
`TinyMachinePeer.www_address`). With `-net-out` the page is fetched by
`tiny-machine-fetch` (`TinyMachineFetch.ml`), a program apart that links
ix's own TLS and HTTP, as `tiny-machine-socket` links the sockets.
Without `-net-out`, or when the fetch fails, a kept copy of a Wikipedia
article in `dir` answers (`tiny/tests/www/OCaml.html`); otherwise the
answer is one line that starts with `www:` and says why. In
tiny-kernel, `rc`, then `get 'www OCaml' | wc`, shows the page's 257,035
bytes. A line `img w h address` asks for a picture of a page: the
answer is a line `0 w h`, then a row of pixels a message, which www
paints as it arrives, the picture decoded and made w by h in the screen's colours by
`tiny-machine-fetch -picture`, from the address with `-net-out`, or
from a kept copy in `dir` named by the address's last part.

**On Linux**, the machine meets programs that are not ours, with no
root. With `-net-out` the other end is a gateway: a connection
tiny-kernel asks for to any other address is made by the host, over
TCP, and the messages pass both ways (a message to the world is its
bytes; the bytes from the world are cut in messages where they
happened to arrive). Its port 53 answers a name by its address, so a
host may be a name: `get / gopher.floodgap.com` is Gopher, and
`get / example.com 80` is the web as it was in 1996 (no https). With
`-net-forward 8080:80` a connection to the host's port 8080 is one to
the machine's port 80: `httpd` in tiny-kernel, then
`http://localhost:8080/` in a browser, is a page that lists
tiny-kernel's files, each a link, a directory's to its own page
(`/bin/`, `/dev/`, `/examples/`). The host's sockets are in a program
apart, `tiny-machine-socket` (`TinyMachineSocket.ml`), run once for
each connection with two pipes, as the window is:
tiny-machine itself has none. `./tiny-machine tiny-kernel` gives all
three.

In the page (`TinyMachineWeb.ml`) the other end is the same, its
documents the page's: a name is a file of `www/` beside the image, and
`wiki words` asks Wikipedia (a search, the first article's sentences
and its picture, which the browser reads and the page reduces to the
screen's colours); `www` fetches the page itself (Wikipedia allows it;
a site that does not allow other pages to fetch it cannot be reached
from the page), or a kept copy beside the page; the wire is drawn under the console, a dot a
packet, and a button loses the next one. `./tiny-machine tiny-kernel`
in a terminal gives the machine its wire with `tiny/tests/www`.

A trace's line has, of IL's, its kind, its number, the last number its sender
received, its message's length (`TinyKernelNetwork.mli` has a conversation
with a packet lost):

       1325.4 ms  < data id 5001 ack 1001, 1024 bytes, from 10.0.0.1 to 10.0.0.2

A packet arrives at a time counted in instructions, so a run with
the network is the same every time
(`tiny/tests/TinyMachine_tests/net.tm`). Without a wire `-36(r0)`
reads 0, a send is lost and nothing arrives.

### 5.6 The speaker

The speaker is memory, as the screen is
([plan_tiny_audio.md](../plans/plan_tiny_audio.md)): a ring of 8,192
samples, a byte each, signed (0 is silence), wherever the kernel says
by writing its address at `-52(r0)`. From then on it plays the ring,
8,000 samples a second of the machine's time (one every `rate` / 8,000
instructions), and makes each sample it played 0 again: a ring that
nobody writes is silent, not the last second over and over. Read,
`-52(r0)` is the samples played since the ring was given, modulo
2^30; the kernel writes ahead of that place. It has no interrupt: a
kernel fills the ring up to a second ahead, and looks again at its
clock's ticks.

The samples due are played when somebody looks, the kernel by reading
the word or the host by taking them, so the speaker costs no
instruction of its own and a run is the same every time:

    tiny-machine -audio a.wav kernel.img     # the samples as a WAV (8 bits, 8,000 Hz), at the halt
    tiny-machine -window kernel.img          # the window plays them

The window gets them as a line `A n` and `n` bytes, about thirty times
a second, and gives them to SDL's queue: a tenth of a second of
silence first when the queue ran empty (a margin for the host's late
frames), and what comes past half a second queued dropped. The web page
has no sound yet.

## 6. Programs

### 6.1 The link, and an image

Each `.tm` file is assembled alone, to an object: its words, its
labels, and the places where a label's address goes (`reloc` lines,
`tiny/TinyAssembler.mli`). tiny-linker puts the objects one after the
other, their labels in one namespace, the first at address 0, where
the machine starts, and fills the places: the image is the memory's
first bytes, with no header.

### 6.2 C: `tiny-c`

The arguments are on the stack, at `0(sp)`, `4(sp)` and so on; the
result is in `r13`; the callee may change any register but `sp`.

A program is linked after its runtime (`tiny/TinyCRuntime/`):

    tiny-c -o prog.tm prog.c
    for f in start udivmod libc prog; do tiny-assembler $f.tm; done
    tiny-linker -o prog start.o udivmod.o libc.o prog.o
    tiny-cpu ./prog one two

`start.tm` calls `main` and exits with its result. `libc.h` declares
`write`, `exits`, `print`, `sprint`, `malloc`, `free`, `strlen`,
`strcpy`, `strcmp`, `memset` and `atoi`.

### 6.3 ML: `tiny-ml`

A file is a module, compiled alone or with the others: its names are
`M.x` in the modules after it, or `x` after `open M`; its types and
constructors are the program's, one name space. Integers are 31 bits (a value is `2n+1` or a
pointer), so a constant beyond them is refused. The runtime is
`TinyMLRuntime/core.c`, compiled by `tiny-c`, with a `main` that gives
it its memory. A C or assembly function is called as an `external`,
with C's convention and ML's values. The standard library,
`TinyLibCore/`'s modules, is compiled once (`tiny-ml -c -nostdlib`, each
module after the ones before it); tiny-ml reads its interfaces from
`/lib/ml` (`-L` another directory), and a program is linked with its
objects.

    tiny-ml -c a.ml             # a.tm, and a.tmi, its interface
    tiny-ml -c a.tmi b.ml       # b.tm and b.tmi, after a
    tiny-ml -o main.tm a.tmi b.tmi   # each unit's init, the library's first, ml_start
    tiny-ml -o prog.tm a.ml b.ml     # or all at once: the units and their main

tiny-kernel's programs are made the first way (`tiny/TinyKernel/Makefile`:
the library in `_make/lib/`, each unit once in `_make/ml/`, the main of
each program in `_make/main/`), and linked with what was not tiny-ml's;
tiny-linker leaves out the functions nothing calls.

### 6.4 A system call

`sys n` with the arguments in `r1` to `r3` and the answer in `r1`.
What the numbers mean is up to who answers:

- under tiny-cpu, the host: 0 exit, 1 write, 2 read;
- under tiny-machine, the kernel that the trap enters (section 7).

## 7. The kernels

| kernel | language | protection | files |
|---|---|---|---|
| v0 (`tiny/TinyKernel/steps/v0/`) | assembly | a plain window | none |
| t6 (`tiny/TinyKernel/steps/t6/`) | C | a relocating window | on a disk, a FAT |
| TinyKernel.ml (`tiny/TinyKernel.ml`) | ML | a relocating window | ML values in memory |

### 7.1 TinyKernel.ml's memory

| addresses | what |
|---|---|
| from 0 | the kernel's image, then the files it carries (10 MB at most) |
| `0xa00000` | the file system's buffers and its map of the disk's blocks |
| `0xb00000` | the ML runtime's stack of values |
| `0xb40000` | the processes' frames: 17 words each, their registers and pc |
| `0xb50000` | a packet's place, on its way to or from the network's device |
| `0xc00000` | the speaker's ring |
| `0xd00000` to `0xf00000` | the images a program made (`TinyKernelGraphics.ml`'s free blocks) |
| `0xf00000` | the screen, 640 by 480 bytes; then images again |
| `0x1000000` to `0x2000000` | the ML heap, two halves of 8 MB: the files written live there |
| `0x2000000` to `0x7ff0000` | the processes' partitions, found first-fit when a program starts |
| the last 48 bytes | the devices, which the kernel reaches by negative addresses (-16 is the console) |

A process sees its partition as addresses from 0 to its size: its
program is loaded at 0, its stack starts at the top. The size is 1 MB,
unless the program is an a.out (`tiny-linker -a n`) whose header asks for
n MB: its three words are a magic number (`0x7a0ce5`), the image's size
and the memory wanted. A child of `fork` gets its parent's size. An ML
program's heap grows up to what its partition leaves (`libml/mlsys.c`);
`bigmem`, a test, keeps 3 MB alive in 8 MB.

### 7.2 TinyKernel.ml's system calls

| n | call | n | call |
|---:|---|---:|---|
| 0 | `exit(status)` | 8 | `close(fd)` |
| 1 | `write(fd, buf, n)` | 9 | `pipe(fds)` |
| 2 | `read(fd, buf, n)` | 10 | `dup(fd)` |
| 3 | `fork()` | 11 | `mkdir(path)` |
| 4 | `exec(path, argv)` | 12 | `unlink(path)` |
| 5 | `wait(&status)` | 13 | `chdir(path)` |
| 6 | `getpid()` | 14 | `kill(pid)` |
| 7 | `open(path, mode)` | 15 | `ready(fds, n, until)` |
| 17 | `box(fds)` | 16 | `ticks()` |
| 18 | `dial(address, port)` | 19 | `listen(port)` |
| 20 | `getcwd(buf, n)` | 21 | `link(old, new)` |
| 22 | `rawcons(on)` | 23 | `trace(pid)` |
| 24 | `seek(fd, n, whence)` | 25 | `time()` |
| 26 | `stat(path, entry)` | | |

`seek` sets a file's offset at `n` from its start (`whence` 0), from
where it is (1) or from its end (2), as Plan 9's, and gives the new
one: `db`'s file is read and written at any place, and `>>` is an
open, then a seek to the end.

`time` is the date, in seconds since 2000-01-01: the machine's at the
boot, then the kernel's ticks (a 31-bit integer of tiny-ml's holds it
until 2034, where Unix's seconds since 1970 would not fit). `stat`
writes a path's entry at `entry`, as its directory has it (80 bytes,
`user.h`'s `dirent`: a name of up to 64 bytes, the type, the links, the
size, the date of the last write), or gives -1. A file on the disk has
its date in its inode; one in memory its last write's; the image's
files 0.

`rawcons(1)` gives the console's ^C to the calling process as a byte
it reads, while it lives, instead of killing every process but the
first: emacs's C-x C-c (Plan 9's `rawon`); and its ^D, which otherwise
ends a read of the console with nothing read, the end of the input
for `cat` or `db`. `rawcons(0)` gives them back.

`trace(pid)` gives a descriptor on another process, for a debugger
([plan_tiny_debugger.md](../plans/plan_tiny_debugger.md)). A write is a
command, the numbers in decimal: `b addr` a breakpoint (the word there
kept, 0 written in its place), `d addr` the breakpoint removed, `r` the
registers, `c` the stopped process resumed. A read is a line: a
command's answer (`ok`, the registers), or the process's stop
(`stopped pc break`, `illegal word`, `fault addr` or `exec`) or its end
(`exited status`); 0 after its end. A traced process that faults
is stopped, not killed. `trace(0)` makes the caller traced by its
parent, stopped at its next `exec`: how a debugger starts a program.

`dial` gives a descriptor on a connection to another machine, by its
address as text (`"10.0.0.1"`: the wire's other end) and a port; -1
without a network, or when nothing listens there or nothing answers
(six tries, 6.3 seconds). The connection is IL's (`TinyKernelNetwork.mli`):
a write is a message, 1,024 bytes at most, which arrives once and in
order, the write waiting when 20 are not yet read at the other end; a read
gives one message, whole (what is over the buffer is lost), and 0
when the other end is done; the last descriptor's close says the end,
after what was written has arrived. `get` is these three calls.
`listen(port)` is the other side: it waits for the next connection
another machine makes to that port of this one and gives its
descriptor; a server is that call in a loop (`httpd`). Port
0 is the echo and not IL: a write is a question sent there, a read an
answer's bytes; `ready` waits for one with a limit, as `ping` does
(three questions, each waited for a second).

A call that fails answers -1. Its C programs are in
`tiny/TinyKernel/user/`; what they are linked with, `user.h` and
`sys.tm`, is in `tiny/TinyKernel/libc/`, and an ML program's side of
the kernel in `tiny/TinyKernel/libml/`.

`ready` answers the first of `n` descriptors that a read would not
wait on, or -1 when the clock reaches `until` (0: no limit; with no
descriptor it is a sleep). `ticks` is the clock: the timer's
interrupts since the boot, one every 2.5 ms of the machine's time
(the `rate` register divided by 400: 20,000 instructions at 8 million
a second). `box` makes
a box, a pipe that keeps only what was last written: `fds[0]` reads it
(a read waits for a write since the last read), `fds[1]` writes it and
never waits. A process has 32 descriptors.

The files are a tree of ML values in the kernel's heap, made at the
boot from what the image carries after the kernel:

    /bin        the programs (sh, rc, the utilities by their names, emacs, office, play, prof, db, vcs, build...)
    /dev        the devices: console, draw, mouse, audio (7.3)
    /examples   files to look at: sources, a page of the office's, a WAV

A command without a `/` is a program of `/bin`, for `sh` and for `rc`
(its `PATH`); the shell starts at `/`, where what is made goes until a
`cd`. Nothing is kept across a stop but what `put` sent away (5.5).

### 7.3 TinyKernel.ml's screen, mouse and speaker

The kernel has the pixels (`tiny/TinyKernel/TinyKernelGraphics.ml`, compiled with it);
a program says what to draw. **A program is given five descriptors**:
0, 1 and 2 its text, 3 where it draws (messages, below), 4 its mouse (a
box: a read gives x, y and the buttons, a word each, when they
changed). The first shell's are the console, the screen and the
machine's mouse, and its programs inherit them; a window system gives
a window's shell pipes and a box instead (7.4), so a program does not
know which it has. The same three as files of `/dev`, for a program
that wants the screen itself, and the speaker:

| file | a read | a write |
|---|---|---|
| `/dev/console` | the keys typed, as they come | the terminal |
| `/dev/draw` | | messages, whole; a bad one is said on the console and the write answers -1 |
| `/dev/mouse` | waits until the mouse changed, then 12 bytes: x, y, the buttons (1 left, 2 middle, 4 right), a word each | |
| `/dev/audio` | | sounds and samples, messages (below), whole; waits until they fit a second ahead; a bad one answers -1 |

A connection (descriptor 3, or an open of `/dev/draw`) has its images by
numbers of the program's, 0 the one it was given, freed when its last
descriptor is closed. A
message is a letter, then numbers of 16 bits, the low byte first,
signed:

| message | what |
|---|---|
| `a id x0 y0 x1 y1 repl colour` | an image made, of that rectangle, filled with a colour's byte (the one that had this number is freed); `repl` 1: it repeats (a colour is an image of one pixel that does) |
| `f id` | freed |
| `d dst src mask x0 y0 x1 y1 px py` | draw: `dst`'s rectangle is `src`'s pixels from (px, py) on, where `mask`'s are not 0 (-1: no mask) |
| `l dst src x0 y0 x1 y1` | a line, both ends drawn |
| `s dst src x y n`, then `n` bytes | a text, its top left corner at (x, y); a character is 8 by 16 |
| `t dst src x y n style`, then `n` bytes | a text in a style: bold 1, italic 2, underlined 4, large 8 (16 by 32); or 16, fat pixels, a byte a colour, a square of 4 by 4 (tiny-office's words and paints, www's) |
| `p dst x y n`, then `n` bytes | a row of pixels, a byte each, its left end at (x, y): how a picture that comes from elsewhere is drawn (www's) |

A colour's byte is an index of Plan 9's table of 256 (0 black, 255
white).

**The kernel has the samples too.** A program does not write samples
to `/dev/audio`: it writes sounds, each a message `s wave hz to_hz ms
volume` (the letter, then five numbers of 16 bits), and the kernel
makes them into the speaker's ring
(`tiny/TinyKernel/TinyKernelAudio.ml`): a wave (0 a square, 1 a
triangle, 2 a sawtooth, 3 noise), a pitch sliding from `hz` to `to_hz`
(4,000 at most), `ms` milliseconds (1,000 at most), a volume from 0 to
127 that falls to nothing at the end. What is no recipe is samples:
a message `p n` and the `n` bytes (8,000 a second, signed, 8,192 at
most), as `/dev/draw`'s row of pixels. Each open of `/dev/audio` is a voice:
its sounds follow one another, and what it makes is added to what the
other voices made, so two programs are heard at once. The speaker
plays on after a program ends, up to the second it was ahead.

`play file.wav` (`tiny/TinyPlay.ml`) plays a WAV file: 8 or 16 bits,
one channel or more, any rate up to 96,000, made the speaker's by
taking the file's frame at each sample's time (exactly, Bresenham's
way, no division a sample), the mean of two channels, its top byte; a
block of 2,048 samples written when the last was taken, so the first
is heard after a block.

    play /examples/korobeiniki.wav      # tetris's tune, four bars, made by m-ix's mini-play

For C, `libc/draw.h` and `draw.c` gather the messages
(`d_fill`, `d_text`, `d_flush`...); `examples/paint.c` is a program of a
page that waits for the mouse, the keys and the clock at once. For ML,
`tiny/TinyLibDraw.ml` makes them.

    ./tiny-machine -window tiny-kernel
    $ paint

### 7.4 tiny-windows

`tiny/TinyWindows.ml`, a program of TinyKernel.ml's in ML (compiled by
tiny-ml after `TinyLibDraw.ml`; `libml/mlsys.c` is an ML program's
runtime and system calls), is the window system:

    ./tiny-machine -window tiny-kernel
    $ windows

| the mouse | what |
|---|---|
| the right button | the menu: New, Move, Delete, Exit; let go on an item |
| then the left button | New: a rectangle swept, a shell in it; Move: a window dragged; Delete: a window pointed at |
| the left button on a window | it comes to the front, and has the keys |

A window is a text until a program draws in it: what is printed is
shown and scrolled, a line typed is edited and given at the Enter,
Control-D ends the shell's input, and the window with it. When a
program draws (`paint`), the window is its picture: the keys go to it
as typed and the mouse in the window is its mouse, until something is
printed again. A window's program is given three pipes and a box as
its five descriptors; tiny-windows reads what it draws, changes its
images' numbers and sends the messages on, the kernel keeping every
pixel. `windows` typed in a window runs there, with windows of
its own.

### 7.5 A game: TinyLibPlayground.ml

A game is a value of `tiny/TinyLibPlayground.ml`'s type `game`: the size
of its picture, its first model from a seed (`init`), the model as
shapes (`view`), the model after a key (`key`: its byte, the arrows
128 to 131) and after a frame (`frame`: thirty a second of the
machine's time), the sounds of a change (`sound`: given the model
before and the model after, a list of sounds, each `{ wave; hz; to_hz;
ms; volume }`, 7.3's message), and the tune the model wants playing
(`music`: `Some { pace; parts }` or `None`; a part is a wave, a volume
and notes, each a pitch in Hz, 0 a rest, and a length in units of
`pace` milliseconds). The library has the loop, the drawing and the
speaker: a picture is drawn when its shapes are others than those
shown, off the window and then on it at once; a change's sounds are
written to `/dev/audio`; a tune's parts, a voice of `/dev/audio` each,
are given their next notes half a second ahead at each turn of the
loop (another tune, a faster pace, goes on from the same notes;
`None` stops it, and the next starts at its beginning).

| shape | what |
|---|---|
| `Rect (colour, width, height)` | a rectangle; a colour is a byte of the table |
| `Words (colour, text)` | a text, in the one font, 8 by 16; its colour's high bits a style (§7.7) |
| `Group shapes` | shapes together, the first under the next |
| `Move (right, down, shape)` | a shape moved; y goes down from the top left corner |

`random s` is the next state of a generator of the model's. A game is
several files given to tiny-ml as one program (TinyKernel's
Makefile: `libml/TinyCalls.ml`, `TinyLibDraw.ml`, `TinyLibPlayground.ml`, the
game, and a last file that says `let () = run game`); the same files
are OCaml's, where a game's model and picture are tested with no
machine. `square` is one of a page
(`tiny/tests/TinyLibPlayground_tests/Square.ml`): type it at the screen's
shell or in a window; `q` quits. `tetris` is `tiny/TinyAppTetris.ml`:
the arrows move the piece (up turns it, down is a row), the space
drops it, `m` turns the music off and on, `q` quits; after a game
over, the space starts another. It is heard: a piece that lands, rows
that go (four at once, a level), the game over, and Korobeiniki, m-ix's
theme, a tenth faster each level.

### 7.6 A program with buttons: TinyLibGUI.ml

A program with widgets is a value of `tiny/TinyLibGUI.ml`'s type `gui`:
its first model (`init`), the model as widgets (`view`), the model
after a message (`update`), and the messages of a key when no field
has the keys (`key`). The library has the loop, the layout, the mouse,
the keys and the drawing: a button the mouse goes down in and comes up
in sends its message, the field last clicked in has the keys, and
only the widgets that are others than those shown are drawn.

| widget | what |
|---|---|
| `Label text` | a text |
| `Field text` | a text in a white box, at its right; not typed in |
| `Input (text, message of a text)` | a field typed in: a key sends the text with the character more, a backspace with one less; its caret is at the end |
| `Button (text, message)` | a button, and what it sends |
| `Row widgets` | side by side, the same width each |
| `Col widgets` | one under the other, the column's width each |

It is given to tiny-ml after the playground, whose shapes it draws by
(TinyKernel's Makefile: `libml/TinyCalls.ml`, `TinyLibDraw.ml`,
`TinyLibPlayground.ml`, `TinyLibGUI.ml`, the program, and a last file that
says `let () = run calculator`). `calc` is `tiny/TinyAppCalculator.ml`:
the mouse on its buttons, or the keys (the digits, `+ - * /`, `=` or
the Enter, `c` clears); `q` quits. Whole numbers of nine digits, an
operation done when the next one is asked (`2+3*4=` is 20). `temp` is
`tiny/TinyAppTemperature.ml`: click in a field and type a temperature,
the other field has it in the other scale, to the nearest whole
number; the Escape quits (or `q`, before a field is clicked).

With `-window` the machine runs at a fixed speed, 20 million
instructions a second unless `-rate n` says otherwise (n in millions),
so that a game's time is the same on every host that can keep up, and
a key held is typed again. Without a window the machine does not wait,
and its speed (8 million by default) only says how long its second is.
The kernel reads the speed, so the programs that count ticks (the games,
`ping`, IL's timers) keep their pace at any speed, while those that
compute finish sooner. The web page runs at 8 million.

### 7.7 A program that draws its whole window: `run_canvas`, the menus

A program that draws its window itself (emacs, the office) is a value
of `TinyLibGUI.ml`'s type `canvas`: its first model given the window's
size (`first`), its picture as shapes (`picture`, the first one the
ground under all), the model after a key (`typed`) and after the mouse
(`moved`), each `None` to end. `run_canvas` has the loop: the window's
size (an ENQ to the console, which tiny-windows answers in the mouse's
box), the raw console (`rawcons`: ^C a key), and the picture drawn
where it changed, each shape's leaves compared with the old ones at
their place. A program's own file in `TinyKernel/user/` is then a few
lines (`office.ml`, `emacs.ml`).

`TinyLibGUI.ml` has pull-down menus for such a program: a bar of
titles, each a menu of items and their messages (`menu_view`, drawn
over the picture), and `menu_mouse`, which says whether the mouse was
the menus' and the item chosen. A press on a title and a release on
an item chooses it, and so does a click on the title then one on the
item. The menus' state is below the model, as the widgets' mouse is.

A word's colour may carry a style in its high bits (`TinyLibPlayground`'s
`bold`, `italic`, `underlined`, `large`), drawn by the kernel's `t`
message (§7.3), and `fat_pixels`, a row of a paint: each character a
colour's letter, a square of 4 by 4.

### 7.8 tiny-office: `office`

`tiny/TinyOffice.ml` (`TinyKernel/user/office.ml` around it) is an
office suite of one program: a document of pages, each page boxes
(the "parts"), each box a kind of document whose data is text.

| part | made by | edited |
|---|---|---|
| text | Insert's Text, C-o | as it is shown: a click puts the cursor, a drag selects; Format's Bold, Italic, Underline, Large, Plain (C-b, Tab, C-u, C-l) on the selection or what is typed next; Edit's Cut, Copy, Paste (C-w, C-y) |
| sheet | Insert's Sheet, C-x t | a cell chosen by a click or the arrows, what is typed shown in the status line, Enter puts it; numbers, text, formulas after `=` (`+ - * /`, parentheses, cells, `sum(b1:b3)`); errors in the cell (`#SYNTAX`, `#REF`, `#TEXT`, `#DIV0`, `#CYCLE`); the Sheet menu names it, or makes a chart of a column |
| drawing | Insert's Drawing, C-x d | the left button drags a box or an arrow, or places a text (Draw's tools, Tab); what is typed is the last shape's label |
| paint | Insert's Paint, C-x p | the left button paints, thin or thick; Paint's ten colours, or a digit; Clear |
| chart | a sheet's Chart of this column | bars of the sheet's cells, its values at each view: it follows its sheet |

A box's tab, above it, moves it; the square at its corner resizes it
(the left button; the right button too). Edit's Undo (C-_) takes the
document back a change; File's Save and Quit are C-x C-s and C-x C-c.
A page not saved is not left at the first Quit: the status line says
so, and a second Quit (or C-x C-c) leaves it.
The Page menu, last in the bar, shows the next page or the one before
(C-x ], C-x [), makes a page after the one shown, or deletes it; the
status line says which page is shown.

The file is in mini-troff's format (`docs/plans/plan_typesetting.md`):
Markdown's lines, and `\name[options]{text}` for the rest. Each box is
a `\box[x y w h]{` line, its content and a line `}`; a sheet's name
follows its numbers. A text is Markdown (`**bold**`, `*italic*`, a
line `# ` large, `\u{}` underlined, `\large{}` large inside a line); a
sheet is a Markdown table, its header the columns' letters; a drawing,
a paint and a chart are fences of their lines (```` ```drawing ````,
```` ```paint ````, ```` ```chart ````); `\newpage` separates two pages.
So emacs edits a document as text, and a Markdown file with no `\box`
opens as one text box. A document of two pages, a text and a sheet on
the first, a chart of the sheet on the second (`/examples/report.ixd`
is one of a page, with a drawing and a paint):

    \box[16 40 300 120]{
    # A **report**

    What tiny-office makes, and tiny-troff prints: *text* in its styles.
    }

    \box[16 170 170 86 budget]{
    | a     | b      |
    |-------|--------|
    | Rent  | 500    |
    | Food  | 300    |
    | Total | =b1+b2 |
    }

    \newpage

    \box[16 40 200 120]{
    ```chart
    bars budget b1:b2 a1:a2
    ```
    }

### 7.9 tiny-troff: `troff`

`tiny/TinyTroff.ml` (`TinyKernel/user/troff.ml` around it) prints a
document of the office's, or a Markdown file, reading it with the
office's own functions:

    troff file        its text, 72 columns: each line filled, a large line underlined by =,
                      a sheet's values in columns, a drawing in characters, a form feed between pages
    troff -h file     a web page: each part at its place, <b> <i> <u> <h1>, a sheet a <table>,
                      a drawing, a paint and a chart in SVG; the pages one under the other
    troff -p file     PDF: a page each, the text in Courier (a font every reader has: at 13.33
                      points 8 a character, the office's 8 by 16), laid out as the office lays it out

`troff -p page > page.pdf; put page.pdf` publishes a document: `put`
keeps it at the wire's other end (§5.5).

### 7.10 On the host: `tiny/sdl/`

A program on these libraries asks the kernel nothing but through
`TinyCalls` (`u_write`, `u_read`, `u_ready`, `u_open`, `u_close`,
`u_ticks`, `u_rawcons`, `u_dial`, `u_argc`, `u_arg`). On tiny-machine
they are the system calls (`TinyKernel/libml/TinyCalls.ml`); built by
OCaml, `TinyCalls` is a virtual library of dune's
(`TinyKernel/host/TinyCalls.mli`) with two implementations: the
tests' stub (`TinyKernel/host/stub/`), and a window's
(`tiny/sdl/TinyCalls.ml`). In the window's, what a program draws is
done by the kernel's own `TinyKernelGraphics.ml` in a screen of host
memory and shown by SDL; the mouse and the keys are the window's; files
and the clock are the host's; a dial to the wire's other end (port 70)
is answered as tiny-machine answers it, a web page fetched by
`tiny-machine-fetch`; a sound written to `/dev/audio` is made by the
kernel's own `TinyKernelAudio.ml` and played by SDL (one after the
other, not mixed; a write waits while a quarter of a second is queued,
and the program's end until all is heard). The programs' own few lines in
`TinyKernel/user/` are compiled there as they are:

    tiny-office file      tiny-emacs file      tiny-calc      tiny-tetris
    tiny-www OCaml        tiny-troff [-h | -p] file          tiny-play file.wav

`TINY_SCREEN=f` writes the window's screen to `f` (a PPM) when the
program ends, and `SDL_VIDEODRIVER=dummy` runs one with no window;
`TINY_WWW=dir` gives `tiny-www` pages kept in `dir` when it cannot
fetch them. `make loc` does not count `tiny/sdl/`.

## 8. Tests

| what | how |
|---|---|
| the CPU | `tiny/tests/TinyCPU_test.sh` |
| the machine, v0, the devices, the screen | `tiny/tests/TinyMachine_test.sh` |
| t6 | `make -C tiny/TinyKernel/steps/t6 check` |
| TinyKernelGraphics.ml, on the host and on the machine | `tiny/tests/TinyKernelGraphics_test.sh` (`-window`: its picture shown) |
| TinyKernelAudio.ml, sounds made into a ring (their crossings of zero, two at one place, the ring going round) and messages read, on the host | `tiny/tests/TinyKernelAudio_test.sh` |
| TinyKernelFS.ml, files and directories on a disk of bytes, a file with a double indirect block, a crash before a commit, snapshots, a full disk emptied, on the host | `tiny/tests/TinyKernelFS_test.sh` |
| TinyPlay.ml, WAV files made into the speaker's samples (the example, 8 bits in two channels, a chunk skipped, rates above and below, in blocks and at once), and files it does not play | `tiny/tests/TinyPlay_test.sh` |
| TinyLibPlayground.ml, a game's model and picture on the host | `tiny/tests/TinyLibPlayground_test.sh` |
| TinyAppTetris.ml, its rules and its sounds by scripts of keys, and its picture, on the host | `tiny/tests/TinyAppTetris_test.sh` |
| TinyLibGUI.ml, TinyAppCalculator.ml and TinyAppTemperature.ml, the arithmetic by keys, the buttons by a mouse, the fields by clicks and keys, the picture, on the host | `tiny/tests/TinyLibGUI_test.sh` |
| TinyOffice.ml, a document worked at by keys and the mouse (each part, the menus, the styles, the pages, the file), on the host and on tiny-cpu | `tiny/tests/TinyOffice_test.sh` |
| TinyTroff.ml, a document as text, HTML and PDF, on the host and on tiny-cpu | `tiny/tests/TinyTroff_test.sh` |
| TinyBrowser.ml, pages read into lines, however they are cut, on the host and on tiny-cpu | `tiny/tests/TinyBrowser_test.sh` |
| TinyKernel.ml; paint, tiny-windows, tiny-windows in a window, square, tetris, calc and temp in a window, emacs, the office (a page, a sheet and its chart, a drawing, a paint), www (the OCaml article, its links and pictures), each with a recorded mouse and keys; tetris's sounds and play's, a WAV's sum each; troff's text, HTML and PDF | `make -C tiny/TinyKernel check` (a few minutes) |

On macOS they need GNU's coreutils first in the `PATH` (`stat -c`,
`wc`).
