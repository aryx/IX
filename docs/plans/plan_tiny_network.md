# Plan: TinyNetwork: a file fetched by tiny-kernel, its packets shown; a wire for tiny-machine, IL in the kernel, the page as the other end

The author (2026-10-11): "we recently added TinyGraphics, TinyWindows
to the tiny/, what could be a TinyNetwork.ml? And how it could also
work with TinyMachine ? (And TinyMachineWeb too so one could exercise
network things from the t-ix web page)". Of a first design whose demo
was tetris drawn on a second machine: "we need a better demo than this
tetris thing; the web page already let the user type tetris [...] Also
not sure we want two window running; things are already slow; we need
to find a better simpler network demo". Then: "also ideally when on
Linux the tiny network can also be exercised in some way; not sure
how"; "also I really liked the IL protocol in plan 9 that was
rethinking TCP in a cleaner way; not sure if we can inject that in the
tiny network (or maybe we could also add it to the mini-9pi)"; and of
this plan's first version: "I don't really understand it. Can you
start from the demo we want to present and explain clearly the
underlying things to support it and how it's a tiny one compared to
m-ix; I'm not a network expert".

A plan from reading (`tiny/`, mini-9pi's `kernels/9pi/network/`,
principia's `il.c`): nothing built, nothing run. The line counts of
what exists are measured (`wc -l`); those of what is planned are
guesses.

## 1. The demo

The t-ix page as it is today (one machine, its console, its screen),
with one thing more under the console: **a panel that lists the
packets**, and beside it **a button, "lose the next packet"**.

The visitor types three commands.

**`ping`**: the machine asks "are you there?" and something answers.
Two lines appear in the panel, one each way:

    $ ping
    answer in 1.0 ms

    > echo?                                    0.0 ms
    < echo!                                    1.0 ms

**`get hello.txt`**: the machine asks for a file that is not in its
image; it is on the website, beside the page. Its text comes on the
console, and the panel shows the conversation that brought it:

    $ get hello.txt
    Hello from the other end of the wire.

    > sync    id 100                           "may I talk to you?"
    < sync    id 300  ack 100                  "yes"
    > data    id 101  ack 300  "hello.txt"     the request
    < data    id 301  ack 101  38 bytes        the file
    > close   id 102  ack 301                  "I am done"

**`get hello.txt` again, the button pressed first**: the file's packet
is lost on the way. The file still arrives; the panel shows how:

    > data    id 101  ack 300  "hello.txt"
    x data    id 301           38 bytes        lost
    > query   id 101  ack 300                  "I heard nothing: where are you?"
    < state   id 301  ack 101                  "I sent 301 and have your 101"
    < data    id 301  ack 101  38 bytes        sent again

**And then `get life > life`, and `life`**: a program that was not in
the image, fetched and run, drawing on the screen. That is what a
network is for, and the page could not do it before.

Everything else in this plan is what must exist for these four lines.
There is one machine, one screen: the page is not slower.

## 2. What is under `get hello.txt`

Five pieces, from the program down to the wire and across. Each is
explained below, with why it is needed.

      in the machine (ML and C, compiled by the tiny tools)       the host (OCaml)

      get, a program
          | dial, write, read: system calls
      tiny-kernel: a connection is a descriptor
          |
      TinyNetwork.ml: IL (a message arrives         the same TinyNetwork.ml,
      once, in order, or is sent again)             as "the peer": it answers
          |                                         ping and serves files
      TinyNetwork.ml: IP (an envelope: from,            |
      to, what is inside)                               |
          |                                             |
      the machine's network device  <== the wire ==>  two functions of
      (four words at the top of memory)               TinyLibMachine

### The wire: a device of the machine

A network starts as a way to send some bytes out of the machine and
to get some in. tiny-machine has a console, a disk, a mouse and a
screen; it gets a fifth device, shaped as its disk is: the kernel
writes where a packet is in memory and how long, then "send"; and
when a packet has come, an interrupt says so and the kernel says where
to put it.

    -48(r0)  an address       where a packet is, or goes
    -44(r0)  a length         written: the packet to send; read: the
                              length of the packet waiting, 0 if none
    -40(r0)  a command        1 send, 2 receive
    -36(r0)  a status

On the host's side, `TinyLibMachine` gets two things, as it has `put`
and `console_type` for the console: a hook called with each packet
the machine sends, and a function that gives the machine a packet.
What is at the other end is the host's business; the machine does not
know.

The wire has **two ends and nothing else**. That removes most of what
a real network card brings: no Ethernet, so no hardware addresses, and
no ARP (the protocol that asks "who has this IP address?" on a shared
cable).

### IP: the envelope

Each packet starts with IP's header, 20 bytes: who sends it, who it
is for, and what kind of thing is inside (a ping, or IL). On a wire
with two ends this is nearly nothing: two fixed addresses (the
machine is 10.0.0.2, the other end 10.0.0.1), a checksum, no routes.
It is kept because it makes the packets real ones, which Linux's
tools can read (section 5), and because `ping` is defined on it. It
is a decision (1 below): our own smaller envelope would do for the
page alone.

### ping (ICMP's echo)

The smallest use of the envelope: a packet that says "echo", and the
answer that returns the same bytes. A dozen lines. It is the first
step because it tests the device, the interrupt and IP with nothing
else in the way.

### IL: making the wire reliable

The wire may lose a packet (the button), and a program wants to write
a request and read an answer without thinking of that. The transport
protocol is the piece that gives this. On the Internet it is TCP; here
it is **IL, Plan 9's**, which its authors designed as TCP thought
again for what Plan 9 needed. All of it:

- **A connection is opened by a sync each way**, so
  that both ends know the other is there and each tells the number
  its messages start from.
- **Every message has a number** (its id), one more than the last.
  The receiver gives messages to the program in order, each once: a
  message that comes twice is known by its number and dropped.
- **Every packet also says the last number received from the other
  end** (its ack). So the sender knows what has arrived.
- **When the sender hears nothing for a while, it asks** (query); the
  other end answers where it is (state); the sender then sends again
  what is missing. That is the conversation the demo shows.
- **close** ends it.

What makes IL simpler than TCP, and why it suits a tiny system:

- **It carries messages, TCP carries a stream of bytes.** With TCP a
  write of 100 bytes may arrive as 60 and 40, or joined to the next
  write: the protocol must cut, number each byte, and put back
  together, and the program must find where its message ends. With
  IL a write is one packet and a read gives it whole. A request's
  line, a file's block, a drawing message of TinyGraphics are all
  messages already.
- **It asks before sending again.** TCP sends again on a timer and
  hopes; IL's query and state say what is missing first.
- **Less to hold**: six states where TCP has eleven, no connection
  half closed, a window that is a fixed count of messages (20 in
  Plan 9) and not a number negotiated all along.

In principia it is `kernel/network/ip/il.c`, 1,551 lines with its
chunk markers, where `tcp.c` has 3,603. Its header is 18 bytes after
IP's: a checksum, a length, a type (one of seven: sync, data,
dataquery, ack, query, state, close), two ports, the id and the ack.

Its price: nothing on the Internet speaks it. Plan 9 itself gave it
up in its fourth edition (from memory: 9P went over TCP, IL doing
badly on long roads that lose a lot, and through address
translation). On a wire with two ends that does not matter, and
section 5 says how Linux is reached all the same.

**`TinyNetwork.ml` is a function, with no input or output of its
own**: given a connection's state, the time, and a packet that came
(or none: only time passed), it gives the state after, the packets to
send, and the messages for the program. The kernel calls it at each
packet and each tick. Because it does nothing else, it is tested on
the host with no machine: two of them, a list between them that
loses packets from a seed, and the check that every message arrives
once and in order. TinyGraphics.ml is tested the same way, an array
standing for the screen.

### tiny-kernel: a connection is a descriptor

A program of tiny-kernel has descriptors: a file, a pipe's end, the
screen it draws on. A connection is one more kind (`Conn`, beside
`Reader`, `Writer`, `Draw` in the kernel's `file` type), so `read`
and `write` are the calls a program already has, and the shell's `>`
works on what comes from the network. Two calls are new:

- `dial(address, port)`: a descriptor on a connection to there;
- `listen(port)`: a descriptor whose read gives a connection each
  time someone dials the machine.

A read that must wait for a packet needs nothing new: tiny-kernel's
waiting calls are closures its scheduler tries again, and this is one
more.

`get` is then a few lines: dial, write the name, read until the end,
write each message on standard output. `ping` a few more.

### The other end: the peer

Who answers? Not a second machine. **The host runs the same
`TinyNetwork.ml`**, compiled by OCaml (and by js_of_ocaml in the
page), as the other end of the wire: "the peer". It has no CPU under
it: the hook of the device gives it the machine's packets, it calls
the same function, and gives back what comes out. On top of it, a few
lines: answer a ping; on port 80, read a name and send that file.

Where a file comes from is the one thing the two hosts do
differently:

- in the page (`TinyMachineWeb.ml`), a fetch of the file beside the
  page;
- in a terminal (`TinyMachine.ml`), a directory:
  `./tiny-machine -net tiny/tests/www tiny-kernel`.

The panel is the peer's too: it sees every packet both ways, and
writes a line for each. In a terminal `-net-trace` prints the same
lines, and `-net-lose n` is the button.

So one file does three jobs: the kernel's stack, the host's test of
it, and the other end of the wire. mini-qemu needed a separate
program for that last job (`raspberry/Usernet.ml`), written against
the kernel's stack and not with it.

### Time

tiny-machine's time is the instructions it has run, which makes every
run the same. The network keeps that: the peer answers a fixed number
of instructions after a packet was sent, and what it loses is said by
a seed or by the button. A recorded session with the network then has
the same screen and the same panel each time, and is checked by a
checksum as the others are.

## 3. Tiny against m-ix

m-ix already fetches a page: mini-curl on mini-9pi (commit 70b6b2b
has https:// from a boot under QEMU). It does it the real way, and
the list of what that takes is the best account of what the tiny one
leaves out:

| the piece | m-ix (lines) | t-ix |
|---|---|---|
| the hardware | the Pi's Ethernet behind its USB: `buses/` 598, `Etherusb` 82, `Devether` 152 | a device of four words; about 40 lines of `TinyLibMachine` |
| who is on the cable | Ethernet's addresses and ARP (in `Ip`, `Devip`) | nothing: the wire has two ends |
| the envelope | `Ip` 218: routes, an interface's configuration | the header and its checksum, two fixed addresses |
| ping | `Icmp` 54 | the echo alone |
| packets with no connection | `Udp` 56, for names and the time | none |
| the reliable connection | `Tcp` 306, the twin of `tcp.c` in a simple form: a stream of bytes | IL: messages, six states, a question before sending again |
| how a program reaches it | `Devip` 196: Plan 9's files (`/net/tcp/clone`, `ctl`, `data`) | two system calls, dial and listen |
| the program's library | `lib_networking/tcp` 143 (with names by DNS), `http` 889 | none: a request is a name, an answer the file |
| secrecy | `lib_networking/tls` 931, `lib_crypto` 1,485 | none |
| the program | `Curl` 137 | `get`, about 20 lines |
| the other end, in the emulator | `raspberry/Usernet` 254, a second small stack | the peer: `TinyNetwork.ml` again, and about 40 lines |

About 5,500 lines for m-ix with https, 3,100 without (the table's
sum, the tests not counted). The tiny one I guess at 500: the device 40,
`TinyNetwork.ml` 250 to 300, the kernel 60, `get` and `ping` 40, the
two hosts 100.

What the tiny one keeps is the part that is the idea of a network: a
wire that loses, an envelope, numbers and acknowledgements that make
it reliable, and a program that reads from it as from a file. What it
drops is what the real Internet asks for: many machines on a cable,
many networks joined, names, a stream of bytes, secrecy. As
elsewhere in ix, the mini one is where to read how it is really
done, the tiny one where to see it whole in a sitting.

## 4. What each file gets

- `TinyLibMachine.ml`: the device, its interrupt (a fifth source, 16,
  in ip and ie), the hook and the function for the host; a queue of
  packets waiting, bounded. Without `-net` nothing changes: the
  device reads 0.
- `TinyNetwork.ml` and `TinyNetwork.mli` (new; the header in the
  `.mli`): IP's header and checksum, the echo, IL, the table of
  connections; then the peer's services, or a small file beside it
  for them.
- `TinyKernel.ml`: `Conn`, `sys_dial`, `sys_listen`, the interrupt
  and the tick calling TinyNetwork.
- `TinyKernel/user/`: `get`, `ping`, later `listen port cmd`.
- `TinyMachine.ml`: `-net dir`, `-net-trace`, `-net-lose`.
- `TinyMachineWeb.ml`, `TinyMachineWeb.html`, `docs/t-ix.html`: the
  fetch, the panel, the button.

**An int has 31 bits under tiny-ml -tm** (TinyML.mli) and IL's id has
32: decision 2.

## 5. On Linux

In a terminal the demo is the same with `-net dir`. Beyond it, three
ways for the tiny network to meet programs that are not ours; none
needs root:

1. **Out**: when tiny-kernel dials an address that is not the peer's
   own, the peer opens a real connection there from the host (a
   socket, through its capability) and passes the messages both
   ways. So `get` asks ix's `mini-httpd` or any web server. The peer
   speaks IL to the machine and TCP to the world: a translator. This
   is how IL, which nothing else speaks, still reaches everything.
2. **In**: `-net-forward 8080:80`: the host listens on its port 8080
   and, for each connection, the peer dials the machine's port 80.
   With a server of a few lines running in tiny-kernel, **a page
   served by tiny-kernel is read in Firefox**, or by curl. The one a
   person sees.
3. **A capture**: `-net-pcap f` writes the wire's packets in the
   format tcpdump and Wireshark read. tcpdump (installed here) checks
   IP's header and its checksum; whether Wireshark reads IL's was not
   checked.

Not on Linux: IL itself against another IL. Linux has none; what has
is Plan 9: principia's kernel for the Pi (its configuration links
`il`), and mini-9pi if it gets it (below).

**In the page there is no way out**: a page cannot open a connection,
it can only fetch, and only from its own site or from sites that
allow it. So the page's network is the peer and the site's files.

## 6. IL in mini-9pi

Asked by the author as a maybe. Its own step, after the tiny one and
not needed by it: `kernels/9pi/network/ip/Il.ml`, the twin of
principia's `il.c` beside `Tcp.ml`, one more protocol in `Devip`'s
table, so that `il!address!port` is dialed as on Plan 9. About 300
lines, guessed. Then tiny-kernel and mini-9pi can talk to each other
(a wire between tiny-machine and mini-qemu: a Unix socket), two
implementations written apart, and mini-9pi's is checked against
principia's kernel. Whether goken's kernel has il was not looked at.

## Decisions (for the author; what I recommend first)

0. **IL or TCP in the tiny network**: IL.
1. **Real headers (IP's 20 bytes, IL's 18) or an envelope of our
   own**: real. They cost perhaps 40 lines more and give the capture,
   mini-9pi as a partner, and packets that are what the books show.
2. **A 32-bit id on ints of 31 bits**: two halves of 16 bits; or
   numbers that start small and a difference masked.
3. **The addresses**: fixed, 10.0.0.1 (the peer) and 10.0.0.2 (the
   machine), nothing to configure.
4. **The program fetched and run** in the demo: life, or a clock
   (plan_tiny_web.md's step 2 has the candidates).
5. **Whether the page gets a second text box that dials the machine**
   (`listen 23 sh` in the console, a shell reached by the network):
   it shows listen with still one machine. Later.
6. **IL in mini-9pi**: later, or not.

## Steps

1. The device in `TinyLibMachine`; a test in assembly
   (`TinyMachine_tests/`): a packet sent comes back.
2. `TinyNetwork.ml`: IP, the echo; the peer answering; `ping` in
   tiny-kernel; `-net-trace`. The demo's first command, in a
   terminal.
3. IL: the function, the host's test with loss from seeds; `Conn` and
   `sys_dial`; the peer's files; `get`; `-net dir`, `-net-lose`; a
   recorded session and its checksum in `TinyKernel/Makefile`'s
   check. The demo whole, in a terminal.
4. The page: the fetch, the panel, the button; "What to try" in
   `docs/t-ix.html`; a program fetched and run.
5. On Linux: out, `sys_listen` and `-net-forward`, the capture.
6. The documents: `tiny/README.md`'s row, `docs/manuals/t-ix.md` (the
   device, the calls), `TinyMachine.mli`'s header (the memory's map,
   the fifth source).

## Later

- IL in mini-9pi (section 6).
- A wire between two tiny-machines (a Unix socket), and a program of
  one drawing in a window of the other: its descriptors 3 and 4 as
  connections, Plan 9's `cpu`. The first design's demo.
- The wire given to Linux as a network interface (a tun device; root
  once): `ping 10.0.0.2` from a shell.
- Names, a table in the peer.

## Not in this plan

- Ethernet, ARP, routes, UDP, DNS, TCP, TLS: m-ix has them.
- tiny-os's kernels in C (v6, t6): the device is there for them; no
  stack in C is planned.
- The `.mli` files missing in `tiny/` (TinyGraphics, TinyDraw,
  TinyWindows, TinyPlayground, TinyTetris, TinyKernel, TinyLibCPU,
  TinyLibMachine, TinyMachineWeb, TinyMachineWindow), asked in the
  same conversation: a change of its own.

## Status

2026-10-11: the plan written, then written again from the demo down.
Nothing built.
