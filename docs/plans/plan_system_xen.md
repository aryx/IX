# Plan: mini-xen, a hypervisor in OCaml on the Pi 4, its guests ix's own kernels (`kernel/xen/`)

The author (2026-10-07), after [`plan_system_l4.md`](plan_system_l4.md),
of the second answer to "what else could we add?": "ok, what about
mini-xen? What would it provide? Could it help to run one OS under
another?"; then: "let's write a plan document for mini-xen, I like it!
And would be great to run both mini-9pi and xv6 at the same time,
possibly with different screen parts :)". What he said of Oberon holds
([`plan_system_oberon.md`](done/plan_system_oberon.md)): not an exact
twin, a system "given a place here, adapted to OCaml, and reusing some
of the existing code in ix", its look, feel and approach kept, and the
code "only in" its directory, the rest by symbolic links.

mini-xen is **a kernel whose processes are whole kernels**. Each
guest believes it has a Pi 4 to itself: its memory from address 0,
its interrupt controller, its timer, its UART, its screen, its
keyboard. mini-xen is under them, at the processor's second exception
level, and shares the one real board among them, as mini-xv6 shares a
board among processes. It is written in OCaml and runs on the bare
Pi 4.

**The picture to reach**: mini-xv6 and mini-9pi running at the same
time, each **as the image it is today, not one byte changed**, each
drawing in its own part of the one screen, the keyboard going to the
part the mouse is over.

It has a place in ix for the one idea the other kernels lack: they
make a virtual memory and a virtual processor for a program; this one
makes **a virtual machine**. And ix has, for once, almost everything
on both sides already: the guests, and the Pi 4's devices written a
second time as OCaml, in mini-qemu.

What is kept, and what is free:

- **Kept: the approach.** A small hypervisor that owns the processor,
  the memory and the interrupts, and nothing it need not. **Domains**:
  a guest is a domain, with an identity, its memory, its virtual
  processor, a state (running, blocked, paused, crashed). A second
  translation of addresses under each guest's own. What a guest does
  that it may not (a device's register, a wait, an interrupt) comes to
  the hypervisor as a trap and is answered there.
- **Kept: the feel**, which for Xen is its console: its banner, the
  serial line that is the hypervisor's or one domain's and changes by
  Ctrl-A three times, and the toolstack's words (`xl list` with its
  columns Name, ID, Mem, VCPUs, State, Time; `xl pause`, `unpause`,
  `destroy`, `create`, `console`).
- **Free: what is under**, and two things of Xen's that are not
  under, to say at once:
  - **Xen's first idea was paravirtualization** (2003: the guest's
    kernel is changed to ask the hypervisor in place of touching the
    machine, because the x86 of its day could not be virtualized). The
    Pi 4's processor can be, and the picture above wants guests that
    are not changed. So mini-xen is first what Xen calls an HVM
    domain's host; a guest that asks is a later stage, and then a
    measure (stage 9).
  - **Xen keeps the devices out of the hypervisor**: the drivers and
    the devices' models are in a privileged guest, domain 0, whose
    models are QEMU's. Here the models are mini-qemu's (decision 3),
    **in the hypervisor**, with the two drivers the screen's parts
    need. No domain 0: the domains are made at the boot from a list,
    which Xen on ARM has too, as "dom0less". Smaller, and the wrong
    side of Xen's own rule.

**Status**: the survey done and this plan written (2026-10-07);
nothing else is. The decisions are mine to propose, the author's to
take.

## The survey (2026-10-07, checked by `kernel/xen/survey.sh`)

Three references. **Xen** (`github.com/xen-project/xen`, 4.23-unstable
of 2026-09-22). **Bao** (`bao-project/bao-hypervisor`), which only
partitions a board among guests, each with its cores and devices,
never scheduled. **raspvisor** (`matsud224/raspvisor`), a hobby's
hypervisor for the Pi 3, the nearest to what is wanted: stage 2, the
board's devices emulated, virtual interrupts, WFI trapped, the UART
changing hands by a key.

What I read today: their files by their sizes, raspvisor's README;
nothing line by line. The papers (Barham and others, "Xen and the Art
of Virtualization", 2003; Popek and Goldberg, 1974; Dall and Nieh,
"KVM/ARM", 2014) and ARM's architecture for EL2 (stage 2, the
syndrome of a trapped access, the virtual interrupt) I know from
before and **did not read again**: to do before the stage that needs
each.

**The licences**: Xen is GPL 2 only, Bao Apache 2, raspvisor MIT. ix
is LGPL 2.1. As for seL4 and Singularity: **read, never copied**.

| Xen | lines | what |
|---|---:|---|
| `xen/` | 560,013 | the hypervisor: C and assembly |
| `xen/arch/x86` | 206,937 | |
| `xen/arch/arm` | 80,934 | |
| `xen/common` | 91,074 | of which its schedulers 16,136 |
| `xen/drivers` | 63,731 | the few it keeps (serial lines, the IOMMUs, ACPI) |
| `tools/` | 262,366 | the toolstack, of which `xl` 14,463 |
| the hypercalls | 54 | what a guest, or domain 0, may ask |

In `xen/arch/arm`, what a guest that is not changed needs, 14,726
lines: the traps (`traps.c` 2,347, `arm64/entry.S` 678), stage 2
(`mmu/p2m.c` 1,853, `p2m.c` 617), a device's access trapped and
decoded (`io.c` 287, `decode.c` 240), the virtual interrupt controller
(`vgic.c` 978, `vgic-v2.c` 766, over `gic-v2.c` 1,408 and
`gic-vgic.c` 471), the virtual timer (`vtimer.c` 413), a virtual
PL011 (`vpl011.c` 794), a domain and its making (`domain.c` 1,243,
`domain_build.c` 2,012, `dom0less-build.c` 480).

| the small ones | lines | |
|---|---:|---|
| Bao's `src/` | 37,682 | its core 5,914, ARMv8 10,144, RISC-V 6,991 |
| raspvisor's `src/` | 3,362 | of which the SD card, FAT and printf 1,148; the board's devices emulated, `bcm2837.c`, 467; the traps, `sync_exc.c` and `entry.S`, 359 |

So a hypervisor for one board and guests that are known is **two
thousand lines of C**, on a Pi 3, six years ago.

What ix has (the same script):

| a hypervisor needs | ix | |
|---|---|---|
| guests | mini-xv6's and mini-9pi's images for the Pi 4 (mini-9pi's 2.8 MB). Entered at EL2 **or at EL1**, they go on (`kernel/lib/pi4/l.s` reads `CurrentEL`): started at EL1, nothing of them need change | there |
| what they touch | the virtual timer (`CNTV`: the one made for guests), the GIC-400 at `0xFF841000` and `0xFF842000`, the PL011, the mailbox (the framebuffer), the DWC2 (USB); mini-9pi also the SD card's controller. Their screens: mini-xv6 1024 by 768, mini-9pi 640 by 480, both 16 bits a pixel | a known, short list |
| those devices as code that answers a read and a write | mini-qemu's (`raspberry/`): `Gic` 167, `Pl011` 52, `Devices` 117 (the mailbox), `Framebuffer` 43, `Dwc2` 167 and `Usb` 497 (a keyboard and a mouse behind the hub), `Sdhost` 178, `Dma` 73; none names the host's system | there, by links (decision 3) |
| drivers of its own for the real screen, keyboard and mouse | mini-xv6's: the mailbox's call, `Usbhost` 178 over `usb.c` 151 | there, by links |
| an OCaml program on the bare Pi 4 | `kernel/lib/pi4` | there, **but at EL1**: its boot leaves EL2 at once |
| the second exception level in the emulator | mini-qemu's `Arm64` knows twelve registers of EL2 and starts a raw image there, as the firmware does; an exception never goes to EL2 (`let target = max 1 st.el`), and there is one stage of translation, none of stage 2's registers | **to add** (decision 9) |
| the same in QEMU | its `raspi4b` starts a raw image at EL2 | there, I believe: not tried |

## The rule: one directory, and what cannot be in it

As the other systems: the hypervisor, its tests and its small guests
are in `kernel/xen/`; what is shared is there as a symbolic link, one
a file. Two things are outside by their nature:

- **the guests' images**: they are the other kernels', built where
  they are and only named here; that they are not changed is the
  point;
- **EL2 in mini-qemu** (`machine/Arm64.ml`, `machine/Mmu64.ml`,
  `raspberry/Pi4.ml`): the emulator must have the processor's part
  the hypervisor runs on.

The layout I propose:

    kernel/xen/
      mkfile  survey.sh  numbers.sh  README.md
      Domain.ml       a domain: its memory, its registers when it does not run,
                      its state, its devices
      P2m.ml          stage 2: a guest's physical addresses to the machine's
                      (Xen's name for it)
      Trap.ml         why a guest came to EL2: a device's register, a wait,
                      a hypercall, an interrupt, a fault that is its end
      Vgic.ml Vtimer.ml   the guest's interrupts and time
      Sched.ml        whose turn
      Display.ml      the guests' screens put on the real one
      Input.ml        the real keyboard and mouse given to the domain in focus
      Console.ml      the serial line, its switch, the banner
      Xl.ml           the commands: list, pause, unpause, destroy, create, console
      Config.ml       the domains made at the boot: image, memory, where on the screen
      Main.ml
      machine/        links (Machine, the Pi 4's machine.c...), and its own
                      el2.s: the vectors of EL2, a guest's registers saved
                      and given back
      devices/        links to mini-qemu's: Gic, Pl011, Devices, Framebuffer,
                      Dwc2, Usb, Memory
      drivers/        links to mini-xv6's: Usbhost, usb.c
      guests/         hello, rogue...: guests of a few lines, for the tests
      tests/

## Decisions to take (the author's; my proposals)

0. **The name: mini-xen**, the author's word. By its mechanism (the
   hardware's support, guests not changed, the models in the
   hypervisor) it is as near to KVM with QEMU; Xen is kept for the
   domains, the console and `xl`, and for stage 9.
1. **The Pi 4 only.** The Pi 1's ARMv6 has no second level; a guest
   there must be changed, or every instruction of its kernel looked
   at. The Pi 4's firmware starts `kernel8.img` at EL2, which is all
   that is asked of it.
2. **Guests are the images as they are, started at EL1.** A domain's
   memory is a piece of the board's, seen by the guest from address 0
   through stage 2, so both are loaded at `0x80000` as they were
   linked. The images are in the hypervisor's image, as
   mini-singularity's programs are in its kernel's.
3. **The devices' models are mini-qemu's, linked.** A guest's access
   to a device's address has no page in stage 2 and traps; the
   processor says which register of the guest, how wide, read or
   written; `Trap` calls the model (a `Memory.device`: a read, a
   write, by offset) and steps over the instruction. One instance of
   each model a domain. **The same OCaml is then a device under
   mini-qemu and under mini-xen**, and a fault in a model is found
   twice. An access the processor does not describe (it does for
   plain loads and stores) ends the domain with a message, until a
   guest needs more (Xen's `decode.c`).
4. **Interrupts by the virtual line, the simple way.** A guest's GIC
   is `Gic`'s model whole, distributor and processor's interface; when
   it says the line is up, the hypervisor sets the processor's virtual
   interrupt (one bit) before the guest runs. Every acknowledge and
   end of interrupt is then a trap. The GIC-400's own help for this
   (a guest's interface in hardware, no trap) is the optimization, a
   later stage, apart and switchable, once the traps are counted.
5. **Time: the guest's timer is the virtual one, as it is.** Its
   interrupt comes to EL2 and is made pending in the domain's `Gic`.
   Whether a domain's clock runs while another has the processor
   (the virtual counter's offset) is to decide at stage 2: stopped is
   deterministic and lies to the guest about the day.
6. **One core, a turn each, by the hypervisor's timer; a wait gives
   the turn away.** A guest's WFI traps and the next domain runs; all
   waiting, the hypervisor waits. Xen's schedulers (16,136 lines) are
   not here. The Pi 4 has four cores and mini-qemu models them: a
   core a domain, Bao's way, with nothing to schedule, is a later
   stage.
7. **The screen: a rectangle a domain, copied.** A guest asks the
   mailbox for the screen it wants and gets memory of its own; the
   hypervisor asks the real board for one large enough (mini-9pi's 640
   by 480 beside mini-xv6's 1024 by 768: 1664 by 768) and copies each
   guest's pixels to its rectangle, with a border and the domain's
   name. Copying it all at each tick is the simple way, and dear under
   mini-qemu (2.2 MB a pass). The optimization, apart: stage 2 says
   which of a guest's screen pages were written since the last pass.
   No copy at all would need each guest to take the real screen's row
   length as its own, and mini-9pi's console does not ask for it.
8. **The keyboard and the mouse: the hypervisor's, lent to the domain
   the pointer is over.** The hypervisor drives the real DWC2 with
   mini-xv6's driver; each domain has mini-qemu's model of one, with a
   keyboard and a mouse behind its hub, and is given the keys and the
   pointer's moves while it has the focus (the pointer's place made
   its rectangle's). The serial line is apart: the focused domain's or
   the hypervisor's, changed by Ctrl-A three times as Xen's (mini-qemu
   itself takes Ctrl-A x: to settle), where `xl`'s commands are typed.
9. **mini-qemu learns EL2; QEMU is the first judge.** In `Arm64`: an
   exception's way to EL2 (the hypervisor's configuration register's
   bits for interrupts, WFI and the virtual line; `hvc`), stage 2 in
   `Mmu64` with its registers, the syndrome of a trapped access, the
   hypervisor's timer. A guess: 300 to 500 lines, the plan's largest
   piece outside its directory. Until then the stages are checked
   under QEMU, which has EL2, the other way round from ix's habit.
10. **The SD card and the network: not at first.** mini-9pi is run in
    the form that needs no card. After: the real controller given
    whole to one domain (its registers mapped straight, its
    interrupt passed on: Xen's "passthrough"), which is the instructive
    way and costs no model.
11. **The hypervisor is an OCaml program at EL2 with no process.**
    `kernel/lib/pi4`'s C and its run-time system's side by links, less
    what is for processes; the boot and the vectors are its own
    (`el2.s`): it stays where the others leave. Like the other
    kernels, it is never interrupted itself.

## What is checked

- **Each guest's own check, not changed.** mini-xv6's session at its
  shell and mini-9pi's, typed to a domain under mini-xen, must print
  **the lines their own `expected` files have for the bare board**,
  under mini-qemu and under QEMU. This is the system's claim, whole.
- **Both at once**: the two sessions typed in turn, the focus
  changed between; each still its own lines. The screen dumped: each
  rectangle is that guest's screen on a board of its own.
- **The isolation's own tests** (`guests/`): a guest that writes past
  its memory is a crashed domain and the other goes on; one that
  spins with its interrupts masked takes its turns and no more; a
  domain destroyed and made again starts fresh; a guest's write to
  another's part of the screen is not possible (it has no page
  there).
- **The numbers** (`numbers.sh`, under mini-qemu, in instructions): a
  guest's boot to its prompt and its session, **bare and as a
  domain**: the tax, as a ratio; a device's access trapped and
  answered; a change of domain; an interrupt given to a guest; and
  **a session's traps counted by their kind**, which says what the
  optimizations of decisions 4 and 7 are worth before they are
  written.
- **What the instructions do not say**, as in `plan_system_l4.md`:
  two stages of translation cost cycles (a miss walks both tables),
  not instructions. The honest tax is on the board, by its cycle
  counter.

## The stages (each checked before the next)

0. **The ground: an OCaml program that stays at EL2**, on QEMU's
   `raspi4b`, printing Xen's banner's kin. Settles: `el2.s`, what of
   `kernel/lib/pi4` holds at EL2, and that QEMU's board has what is
   needed.
1. **A guest of ten lines** (`guests/hello`): stage 2, the world
   entered and left, one trap: a hypercall that prints. Then a write
   to the PL011's address trapped and answered by `Pl011`'s model:
   decision 3's mechanism, whole, on one register. The plan's first
   risk: mini-qemu's device modules compiled by mini-ml and linked in
   a kernel.
2. **mini-xv6 as a domain, on the serial line**: the GIC's model, the
   virtual line, the virtual timer; its shell's prompt, then its
   session with its own expected lines.
3. **EL2 in mini-qemu**: the same two stages under it. (Sooner, if
   QEMU alone proves slow to work with.)
4. **Two domains**: `Sched`, the wait trapped; two mini-xv6 first,
   then mini-9pi beside it (its programs run in AArch32 under its
   arm64 kernel, which a guest may do). `Console`'s switch, `Xl`.
5. **The screen's parts**: the mailbox's model, `Display`. The picture
   without the keyboard.
6. **The keyboard and the mouse**: the real DWC2 driven, the models'
   keyboards fed, the focus. **The picture.**
7. **The numbers**, and the first optimization they point at.
8. **The board itself**: the Pi 4, its HDMI screen and a USB keyboard.
9. Later, each to be decided: **a guest that asks** (a console and an
   interrupt controller by hypercalls in a second `kernel/lib/pi4`,
   and Xen's 2003 comparison made here: changed against not changed);
   the SD card passed to a domain; a core a domain; the devices' models
   moved out to a domain 0, as Xen has them; mini-oberon, mini-l4 and
   mini-singularity as domains (they should come free: the same
   machine layer); **a virtual Pi 1** (an arm32 guest at EL1, the
   BCM2835's models at their addresses: the Pi 1's images on a Pi 4);
   riscv64 (below).

## The size

A guess, to be held against what is written. The hypervisor's OCaml
**1,200 to 1,800 lines** with its interfaces (raspvisor's is some two
thousand of C with its models in; Xen's part for ARM named above is
14,726); its own assembly and C **300 to 500** (EL2's vectors, a
guest's registers and its kernel's system registers saved and given
back). By links, not written: the models **1,043** and `Memory`,
the drivers **329**. In mini-qemu **300 to 500**. The small guests and
the tests **200 to 300**.

## riscv64, and the author's Orange Pi RV2

The author (2026-10-07): "if we add riscv64 support at some point,
does the orange pi rv2 has also virtualization support?". By Linux's
device tree for its processor (the SpacemiT K1; the script fetches the
line), **no**: the hypervisor extension is the letter `h` of the
processor's ISA string, and it is not there. QEMU's `virt` has it. So
with [`plan_riscv.md`](plan_riscv.md) done, a mini-xen for riscv64
would run as here under the emulators, and on the RV2 only the older
way: the guest's kernel run in user mode, each privileged instruction
of it trapped and done for it. Not in this plan.

## Not checked yet

- the papers and ARM's architecture for EL2: not read again (above);
  the three references looked at by their sizes. Nothing was built or
  run;
- **that QEMU's `raspi4b` gives a raw image EL2 with stage 2** (it
  starts one at EL2, by mini-qemu's own notes of it); stage 0 says;
- **stage 1's risk**: `raspberry/`'s modules and `machine/Memory`
  under mini-ml in a kernel (they name nothing of the host; what they
  ask of the standard library, and of `Int64`, not looked at);
- that every access of the two guests to a device is a plain load or
  store the processor describes (three compilers made them: mini-cc,
  mini-ml's run-time system's C, and for the reference build gcc);
- the list of the kernel's system registers to save at a change of
  domain, and whether the guests' drop from EL2 (they write five
  registers of EL2 only when entered there) is truly skipped at EL1;
- what the guests believe of the memory's size and of the
  framebuffer's address (the model answers as QEMU's board; a domain's
  memory must hold it);
- which image of mini-9pi needs no card, and whether its USB driver
  and mini-xv6's are content with the model's hub when the keys come
  from a real one, with its delays;
- the real screen at 1664 by 768: whether the board's firmware gives
  it, on the author's display;
- mini-xv6's image by ix's tools was not in `_mk` when the script
  ran: only mini-9pi's size is above;
- Xen's console's exact words and `xl list`'s columns: from memory;
- the licence's reading above.
