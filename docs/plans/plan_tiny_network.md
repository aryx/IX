# Plan: TinyNetwork: a picture from the Internet painted as its packets arrive; a wire for tiny-machine, IL in the kernel, the page as the other end

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
m-ix; I'm not a network expert". Of that version's demo (a ping, a
text file fetched, its packets listed): "any way we could find an even
better demo? Ideally it would be fetching something from the internet
... so you clearly see it handles the network, but I understand
internet has lots of intracacies and ugly corners that goes against
the Tiny Spirit"; "I'm afraid the reader of the website does not fully
appreciate the network support in the tiny-machine with the current
demo"; "for sure it can appreciate the graphics, the windowing system,
the network I'm less sure"; and of a picture painted as it arrives:
"yes, I think it is more impactful for the user".

A plan from reading (`tiny/`, mini-9pi's `kernels/9pi/network/`,
principia's `il.c`): nothing built, nothing run. The line counts of
what exists are measured (`wc -l`); those of what is planned are
guesses.

## 1. The demo

Graphics and windows show themselves; a network does not. So the demo
puts the network on the screen: **the visitor types a word of their
own, and Wikipedia's picture for it is painted on the machine's
screen, row by row, as its packets arrive**, the article's first lines
on the console.

    $ wiki plan 9
    Plan 9 from Bell Labs is an operating system designed by the
    Computing Science Research Center at Bell Labs ...

    (on the screen, Glenda, from the top, a row at a time)

- **It is the Internet**: the word is the visitor's, so nothing in
  the image could have answered it.
- **It is the network**: the picture fills in over a few seconds, as
  a page did over a modem. The machine's 8 million instructions a
  second are here what makes it seen.
- **A loss is seen**: a button of the page, "lose the next packet".
  The painting stops at a row, and goes on when the packet has been
  sent again.
- **With the other two**: `wiki` draws by TinyGraphics's messages on
  its descriptor 3, so in tiny-windows the picture loads in a window:
  the graphics, the windows and the network at once.

**The wire is drawn too**, in the page, beside the screen: the
machine at the left, "the Internet" at the right, a dot for each
packet going across; a lost one falls. Under it, for who wants to
read, a line a packet:

    > sync    id 100                           "may I talk to you?"
    < sync    id 300  ack 100                  "yes"
    > data    id 101  ack 300  "wiki plan 9"   the request
    < data    id 301  ack 101  "320 240"       the picture's size
    < data    id 302  ack 101  320 bytes       its first row
    x data    id 303           320 bytes       lost
    < data    id 304  ack 101  320 bytes       (kept, not shown yet)
    < query   id 304  ack 101                  "I sent up to 304: where are you?"
    > state   id 101  ack 302                  "I have up to 302"
    < data    id 303  ack 101  320 bytes       sent again
    ...
    > close   id 102  ack 541                  "I am done"

Before it, as steps that each stand alone and stay in the page's
"What to try": **`ping`** (two dots, one each way) and **`get
hello.txt`** (a file of the site's on the console).

**What is honest to say on the page**: the machine does not speak to
Wikipedia. It speaks its own small protocol to the other end of its
wire, a gateway, which asks Wikipedia (names, TLS, HTTP, JSON, a PNG:
the Internet's ugly corners, left to the browser), reduces the picture
to the screen's 256 colours and sends rows of bytes. The machine's
part is the wire, the envelope, the reliable connection, and a
program that reads a row and draws it.

Checked from here (2026-10-11): Wikipedia's summary of an article
(`/api/rest_v1/page/summary/...`) gives the text and a thumbnail's
address, and both are served with `access-control-allow-origin: *`,
so a page of any site may fetch them; for "Plan 9 from Bell Labs" the
thumbnail is Glenda, a PNG of 49 KB. Not checked: who asks first
after a loss in il.c, the sender or the one that sees a hole (the
lines above have the sender); how photographs
look in Plan 9's 256 colours; the pace that feels right.

Everything else in this plan is what must exist for that. There is
one machine, one screen: the page is not slower.

## 2. What is under `wiki plan 9`

Five pieces, from the program down to the wire and across. Each is
explained below, with why it is needed.

      in the machine (ML and C, compiled by the tiny tools)       the host (OCaml)

      wiki, a program
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
write each message on standard output. `ping` a few more. `wiki` is
`get` that draws: the text's messages to standard output, then the
size, then each message a row, drawn at its place by a message of
TinyGraphics on descriptor 3 (TinyDraw.ml's side). A row is a
message: IL's messages are why nothing here looks for where a row
ends.

### The other end: the peer

Who answers? Not a second machine. **The host runs the same
`TinyNetwork.ml`**, compiled by OCaml (and by js_of_ocaml in the
page), as the other end of the wire: "the peer". It has no CPU under
it: the hook of the device gives it the machine's packets, it calls
the same function, and gives back what comes out. On top of it, a few
lines: answer a ping; on port 70, read a line and send what it names,
then close. (One line out, a document back, the connection closed:
that is Gopher, of 1991; the port is its own, and in a terminal real
Gopher servers can be reached the same way, section 5.)

Where a document comes from is the one thing the two hosts do
differently, by one function the host gives the peer (a line to its
messages):

- **in the page** (`TinyMachineWeb.ml`): `get name`, a fetch of the
  file beside the page; `wiki words`, a fetch of Wikipedia's summary,
  then of its thumbnail, which the browser decodes (an image drawn on
  a canvas that is not shown, its pixels read), each pixel then the
  nearest of the screen's 256 colours;
- **in a terminal** (`TinyMachine.ml`): a directory,
  `./tiny-machine -net tiny/tests/www tiny-kernel`: `get name` is a
  file of it, `wiki words` a picture kept there already reduced (a
  size and its rows), so that a recorded session has a picture with
  no Internet. Wikipedia from a terminal is decision 5.

The pace is the peer's: so many instructions between two rows sent.

The drawn wire and its lines are the peer's too: it sees every
packet both ways, and tells the page of each. In a terminal `-net-trace` prints the same
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
the same screen and the same lines each time, and is checked by a
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
| the program | `Curl` 137; `browsers/lynx` and `netscape` for a picture | `get`, about 20 lines; `wiki`, about 40 |
| the other end, in the emulator | `raspberry/Usernet` 254, a second small stack | the peer: `TinyNetwork.ml` again, and about 40 lines |

About 5,500 lines for m-ix with https, 3,100 without (the table's
sum, the tests not counted). The tiny one I guess at 600: the device 40,
`TinyNetwork.ml` 250 to 300, the kernel 60, `get`, `ping` and `wiki`
80, the two hosts 150 (the page's drawn wire and its gateway are
most of it).

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
- `TinyKernel/user/`: `ping`, `get`, `wiki`, later `listen port cmd`.
- `TinyMachine.ml`: `-net dir`, `-net-trace`, `-net-lose`.
- `TinyMachineWeb.ml`, `TinyMachineWeb.html`, `docs/t-ix.html`: the
  gateway (the two fetches, the picture reduced), the wire drawn and
  its lines, the button.

**An int has 31 bits under tiny-ml -tm** (TinyML.mli) and IL's id has
32: decision 2.

## 5. On Linux

In a terminal the demo is the same with `-net dir` and `-window`,
its pictures the directory's. Beyond it, three
ways for the tiny network to meet programs that are not ours; none
needs root:

1. **Out**: when tiny-kernel dials an address that is not the peer's
   own, the peer opens a real connection there from the host (a
   socket, through its capability) and passes the messages both
   ways. So a program of tiny-kernel that speaks Gopher reaches the
   Gopher servers there still are (checked from here:
   gopher.floodgap.com answers, and gopherpedia.com gives Wikipedia's
   articles as text), and one that writes a request's line reaches
   ix's `mini-httpd` or any web server. The peer
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
4. **The picture**: 320 by 240 at most, kept in its proportions, a
   row a message, the nearest colour with no dithering; the pace by
   hand, for a picture in two to four seconds. All to see on real
   pictures first.
5. **Wikipedia from a terminal**: not at first (a directory's
   pictures, already reduced, which is also what the tests need).
   Then either the terminal's gateway uses m-ix's libraries
   (`lib_networking`'s HTTP and TLS, `lib_graphics/images`' PNG and
   JPEG: tiny-machine then links them), or the Internet stays the
   page's and the terminal has Gopher's servers by "On Linux"'s way
   out. The second.
6. **IL in mini-9pi**: later, or not.
7. **Later, or dropped**: a second text box of the page that dials
   the machine (`listen 23 sh`: a shell reached by the network), and
   a program fetched and run (`get life > life`).

## Steps

1. The device in `TinyLibMachine`; a test in assembly
   (`TinyMachine_tests/`): a packet sent comes back.
2. `TinyNetwork.ml`: IP, the echo; the peer answering; `ping` in
   tiny-kernel; `-net-trace`. The demo's first command, in a
   terminal.
3. IL: the function, the host's test with loss from seeds; `Conn` and
   `sys_dial`; the peer's files; `get`; `-net dir`, `-net-lose`; a
   recorded session and its checksum in `TinyKernel/Makefile`'s
   check.
4. `wiki`: the peer's document of a size and rows, from the
   directory; the program, on the screen and in a window of
   tiny-windows; a recorded session, its screen's checksum. The demo
   whole, in a terminal, with no Internet.
5. The page: the gateway (Wikipedia's text and picture, reduced), the
   wire drawn and its lines, the button; "What to try" in
   `docs/t-ix.html`.
6. On Linux: out, `sys_listen` and `-net-forward`, the capture.
7. The documents: `tiny/README.md`'s row, `docs/manuals/t-ix.md` (the
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

2026-10-11: the plan written, then written again from the demo down,
then its demo changed (a picture of Wikipedia's painted as it
arrives, the wire drawn).

2026-10-11, step 1, the device: done. `TinyLibMachine`: the four
words at -48(r0) as planned (the status reads 1 when there is a
wire), `i_net` 16, `net_give mc ~after packet` and `send` (an optional
argument of `create`); a packet at most 2,048 bytes, 64 waiting at
most. The packets on their way are kept with their time and landed by
`tick`; `calm` counts to the next one, so the batched loop takes the
interrupt where the simple one does. `devices` is now the top less 48
(it was 32), and the supervisor's first stack pointer with it.
`TinyMachine`: `-net-loop n`, the wire coming back after n
instructions, which the plan did not have: a test's other end until
the peer exists, kept after. `tests/TinyMachine_tests/net.tm`: two
packets sent and received by the interrupt, and "no wire" without the
option. Checked: TinyMachine_test.sh, 0 failures; make check of
tiny-kernel, t6 and v6 with the new machine, ok (the recorded screens'
sums unchanged). TinyMachine_bench.sh on paint.events: 22.0 million
instructions a second natively and 8.4 under node, the screen the
recorded one (22.0 and 8.1 were the numbers written before: no cost
seen). Not run: the page (`TinyMachineWeb.ml` builds, its machine has
no wire yet); mini-ml's build of tiny-machine.
Next: step 2, `TinyNetwork.ml` with IP and the echo, the peer, `ping`.
