# Plan: TinyTronscroll on two boards, by a cable: what remains (`games/arcade/`, `lib_networking/netcode/`, `kernels/9pi/network/`)

The author (2026-10-13): "let's add tronscroll from the playground
(itself coming from a game I made 20 years ago) in ix, and it could be
a good test for the networking support in ix! we could connect my Pi1
and Pi2 together via an rj45 cable and play together". Then, the game
committed (`ddb60eef`): "let's save what remains in a
plan_tronscroll_network document".

The game is in ix and plays over UDP between two programs on Linux,
between mini-9pi under QEMU and Linux, and between two mini-9pi guests.
**It has not run on a board**, and the boards' own Ethernet, which is
what the cable is plugged in, has a driver that no machine has run:
that is most of what remains, and it is the author's to try first,
no emulator here having the chip.

## What is done (`ddb60eef`, 2026-10-13)

- `games/arcade/TinyTronscroll.ml`, the playground's, on
  `lib_playground/apis/Multiplayer` and `lib_networking/netcode/`
  (`Wire`, `Inputs`, `Lockstep`, `Rollback`, `Checksum`, `Sim_net`,
  `Transport`); built by dune and by mini-mk; `tronscroll` on the
  card; `games/arcade/sdl/` on Linux.
- `lib_networking/tcp/Udp`'s `host`, `join`, `send`, `arrived`: a
  socket on Linux, a conversation of `/net/udp` on Plan 9 read by a
  process of its own (`Source`).
- mini-9pi: UDP's `announce` and `headers`; `Etherusb`'s second
  adapter, SMSC's LAN9512 and LAN9514, after principia's `smsc.c`, its
  address the firmware's (`Machine.board_mac`); `boot.rc`'s address on
  a board, the card's `ip.txt` or the board's kind's (192.168.9.1 a
  Pi 1, 192.168.9.2 a Pi 2).
- Two bugs fixed on the way (`bugs/ix.md`): lib_core's `Event.sync`
  read `bev.(-1)` when its thread was woken by another; `Etherusb.poll`
  took one frame a tick.

Checked: `games/tests/frames.sh` (the playground's three golden frames
of the game, pixel for pixel by OCaml), `games/tests/network.sh`,
`make -C kernels/9pi check-tron` (a guest that joins Linux's game, one
that hosts it, a round to tick 900 with the checksums in agreement;
two guests over QEMU's socket network, the title's ticks to 600).

## What remains

### 1. The boards (the author's: nothing here can run it)

The steps, each a thing to look at before the next:

1. The card: `make -C kernels/9pi ix card`, written for each board.
2. One board alone, no cable needed. At its boot, a line
   `ip: 192.168.9.1 ether: b827eb......` (a Pi 1; `.2` a Pi 2). That
   line says the adapter was found among usbd's devices, every
   register of its setup written and read, its address had from the
   firmware, and the interface bound.
3. The two boards, the cable between them (no switch: either end
   crosses the pairs). The jack's lights; then, the flags quoted for
   rc:

       tronscroll 'net=host'                       on the Pi 1
       tronscroll 'net=join' 'host=192.168.9.1'    on the Pi 2

   The line at the bottom of each screen: who is there, the tick, the
   stalls, whether the two games agree. Space on either starts a
   round.

What to report when a step fails, and what it would mean:

| seen | means | where to look |
|---|---|---|
| no `ip:` line; `ls '#l0/ether0'` fails later too | the adapter not found, or its setup raised (a transfer's error is caught, and nothing said) | `Etherusb.adapter`: the device's maker and name (0x0424, 0xec00); `lan95xx`'s resets. A line printed where it gives up is the first change to make |
| no `ip:` line at the boot, but `ls '#l0/ether0'` works a moment after | usbd was still going through the hub | `boot.rc`'s wait, five seconds |
| `ip:` with `ether: 026978000001` | the firmware gave no address (`Machine.board_mac`, the tag 0x00010003): the made-up one, the same on both boards | `pi1/machine.c`'s `board_mac`; two boards with one address do not talk |
| the lights stay off | the transceiver's negotiation did not start | the MII writes (`miiwr`), the reset of the PHY |
| the host says "waiting for a player", the other "joining ..., waiting for an answer" | frames do not go out, or do not come in. `cat /net/ipifc/0/status` on each: `pktout` grows on the one that joins, and `pktin` on the host, or not | out: `command`'s two words, the bulk OUT endpoint; in: `Usbdwc.inpoll` on a real controller (below), `frames`' word before a frame |
| the host has its player, the other still waits | one way only | the same, the other direction; `cat /net/arp` on each says whether ARP's answer came |
| plays, a hitch each second | the checksum (below, 3) | `Checksum`, `Multiplayer` |
| plays, "DESYNC" | the two games differ: a real bug of determinism between a Pi 1 and a Pi 2, both mini-ml's program | the tick it names; `netcode=lockstep` first |

The part of the driver I trust least is **receiving**. A transfer in
is kept pending on the controller's second channel and looked at from
the clock (`Usbdwc.inpoll`, `usb.c`'s `usb_start1`, `usb_poll1`), which
only QEMU's adapter has exercised, where a transfer is done as soon as
it is started. On a board the device answers NAK while it has nothing,
for as long as nobody sends: the controller is expected to try again
by itself (its DMA mode, a bulk endpoint), and `usb_poll1` to see
nothing until a frame is there. If the channel halts on the NAK
instead, each poll reads an error and the transfer is started again a
tick later: frames would come, late. And a transfer is 8 packets of
512 bytes here where QEMU's was 24 of 64: the buffer is a page, which
it fills exactly.

Not known either: whether usbd leaves the adapter as `Etherusb`
expects it on a board (addressed, not configured); the two were only
together under QEMU.

### 2. The open row of `bugs/ix.md`: is it `Event.sync`'s?

The row of 2026-10-13, three programs in windows on the Pi 2's four
cores and `Thread 5 killed on uncaught exception
Invalid_argument("index out of bounds")`, was left open, "not found".
The fix of `Event.sync` has the same message from the same kind of
thread (a source's, sending a frame nobody took yet when the next
comes), and I wrote in that row that it is very likely the same. It
was not tried. To do, here: the scenario under QEMU's four cores
(`SMP=1`; cameltry, stats and breakout in three windows,
`kernels/9pi/tests/busy.py` being what was run for half an hour
before), once with `Event.sync` as it was (`git show
ddb60eef^:lib_core/concurrency/Event.ml`, in a copy of the tree: the
shared `_mk` is not for a baseline) to see the message come, once as
it is. If the old one never shows it either, the row stays open and
says so.

### 3. The checksum's cost on a board

Each second of a game (a tick in 60), `Checksum.of_model` is Marshal's
bytes of the whole model and FNV-1a over them: a round's map is 800 by
600 cells, 480 KB, a byte a step in boxed `Int32` by mini-ml. Not
measured; by the count of Tetris's sound (a float's operation some
hundreds of instructions) it could be tens of millions of
instructions, a visible part of a second on a Pi 1. Under QEMU nothing
was felt, which says nothing of a board.

First the number: `Boot_bench` or mini-5i's count of one
`Checksum.of_model` of a round's model for arm. Then, if it is too
much, in the order of what it costs to write:

- the sum in two halves of 16 bits on plain ints (the same numbers:
  `lib_juice`'s `Hash` was done so for the Pi 1's ints of 31 bits),
  the simple version kept beside it;
- the game's own summary given to `Multiplayer` in place of Marshal's
  bytes (the riders and a count of the cells written): another
  interface than the playground's, so only if the first is not enough;
- the checksum every five seconds.

The first also makes OCaml's program and mini-ml's agree only if
Marshal's bytes do, which they do not: see 6.

### 4. The game in a window of mini-rio's

Run on the bare screen only (the console's, under QEMU with no
window). In a window the keys are rio's to give, and `Udp`'s process
is one more of the program's sources. To do: the game started from a
window, by a session of `kernels/9pi/tests/` (`*.steps`), its ticks
said as in `check-tron`. And the game's speed on a board: 36 frames a
second under QEMU for the title, "show 27 ms" of each frame being the
draw device's; a round's trails are a rectangle a line, a few hundred
shapes late in a round. Not measured on a board.

### 5. A board's address

By the board's kind, 192.168.9.1 a Pi 1 and 192.168.9.2 a Pi 2, or
the card's `ip.txt`: the author's two boards with nothing typed, and
two boards of one kind with a file to write. What else it could be,
for the author to choose:

- from the adapter's own address (169.254.x.y, its last two bytes, as
  a machine with no DHCP does by itself): general, and a number to
  read off one screen and type on the other. rc cannot turn hex into
  decimal: a line of `dc`, which is on the card, or a file of the
  kernel's that says it;
- the host found by a broadcast, no address typed at all
  (`net=join` alone): `Ip` sends and takes 255.255.255.255 already; a
  conversation connected to it would have to take an answer from
  anyone, which is not Plan 9's UDP;
- DHCP (Plan 9's `ipconfig`): what a board on a real network asks,
  and nothing a cable between two boards answers.

### 6. What was left in the playground

- `netcode=server` (`Snapshot`, `Prediction`, `Interpolation`: a
  server that owns the game, the clients predicting), in one window
  only there too; some 420 lines.
- `net=relay` and its server: a WebSocket, which ix has not.
- The netcode's own unit tests (`Unit_lockstep`, `Unit_rollback`,
  `Unit_sim_net`, `Unit_wire`, `Unit_checksum`, and
  `Unit_tronscroll`, the options' rules): ix has the game's golden
  frames over them and two programs over UDP, not the modules' own
  cases. `lib_networking/tests/` is where they would go (Testo,
  dune's).
- The lightcycles kit, TinyTron and TinyTron3d (the computer players:
  alpha-beta on the Voronoi partition).
- More than two players (the original had eight): the playground's
  own "left as an exercise", waiting for its relay.

And one thing that is ix's: a game between OCaml's program on Linux
(dune's, SDL's window) and mini-ml's on a board plays and says DESYNC,
a checksum being Marshal's bytes, each compiler's. A sum of the
model's own values, written out (3's second way), would make the two
agree; whether a board against a laptop is wanted is the author's to
say.

### 7. mini-qemu

`check-tron` is QEMU's. mini-qemu has the usb-net and a user network
(`check-ix-net` runs under both), no socket network between two
guests, and no LAN95xx. The chip modelled there (its registers, the
words before a frame) would be the first machine to run the boards'
driver before a board does, some hundreds of lines in `raspberry/`:
worth it only if the driver needs more than a try or two on the
boards.

## Open questions

1. A board's address: as it is, by its kind, or one of 5's others?
2. Is a board against Linux's window wanted (6's last paragraph)?
3. The playground's unit tests of the netcode: copied to
   `lib_networking/tests/`, or the golden frames enough?

## Status

2026-10-13: the game, its netcode, UDP for a game, the kernel's
announce and the boards' driver committed (`ddb60eef`). Checked under
QEMU and on Linux; nothing on a board. Next: 1, by the author, on the
two boards; here meanwhile 2 (the open row), then 3's number.
