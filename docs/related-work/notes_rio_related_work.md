# Related work: window systems, from the Alto to rio and the compositors

Where mini-rio ([`plan_rio.md`](../plans/plan_rio.md)) sits. The kernel
under it is in [`notes_9pi_related_work.md`](notes_9pi_related_work.md).
The dates of the lineage are principia's (`~/principia/windows/lineage.txt`,
read; its sources: Wikipedia's history of the graphical user interface,
toastytech's timeline). What is said beyond a name and a date is **from
memory** where marked, to check before it is quoted in a `.mli`.

## The lineage

- **The Alto** (Xerox PARC, 1973) and **Smalltalk-80** (1980): a bitmap
  screen, a mouse, overlapping windows; the **Star** (1981) made a
  product of it, the **Lisa** (1983) and the **Macintosh** (1984) a
  market.
- **The Blit and mpx** (Bell Labs, 1982), for UNIX V8; **mux** (1988),
  for V9; the **Concurrent Window System** (1989); **8½** (1991), Plan
  9's first; **rio** (2000), its second. One line of descent, mostly
  one author (Rob Pike), and the one mini-rio is on.
- **W** (Stanford, 1983, for the V system) and **X** (MIT, 1984, from
  W; X11 in 1987; XFree86 1992; X.org 2004): the window system as a
  server on a network.
- **SunView** (1986), **NeWS** (1987, from X and Andrew's window
  manager), **MGR** (1984; its paper 1987): the workstation makers'
  and Bellcore's.
- **Oberon** (1992 in the lineage; ETH): tiled, not overlapping.
- **The small ones**: Mini-X (1991), MicroWindows (1999) and Nano-X
  (2005); Pico GUI (2000); Nitpicker (2005).
- **The compositors**: Quartz in Mac OS X (Aqua, 2000), Windows
  Vista's DWM (2007), Android's SurfaceFlinger (2008), **Wayland**
  (2008; 1.0 in 2012), Fuchsia's Scenic (2019), Redox's Orbital (2015,
  which the lineage draws from rio and from Wayland).

## The ideas, and where they came from

- **Overlapping windows and bitblt** (the Alto; from memory: Ingalls's
  BitBlt for Smalltalk): one operation that copies a rectangle of
  bits, with a rule to combine them, is enough to draw text, move a
  window and pop up a menu. Plan 9 kept it until its third edition,
  when `draw` replaced it: the same operation with a mask and Porter
  and Duff's compositing (from memory). ix's is that one
  (`lib_graphics`' `Draw`, the kernel's `Devdraw`).
- **Layers** (from memory: Pike, "Graphics in Overlapping Bitmap
  Layers", 1983): a window that is partly covered is still a bitmap a
  program draws in whole; the system keeps what is hidden and the
  program never repaints for an exposure. X chose the other way, an
  expose event the program answers. Plan 9's libmemlayer is the first
  way; so a program in a window of rio's draws as on a bare screen.
- **Where the window system runs.** In the terminal itself (the Blit:
  mpx's other half was downloaded into it); in the kernel (SunView,
  and Windows' USER and GDI; from memory); a process, a server its
  clients talk to by a protocol (W, X: "mechanism, not policy", the
  window manager one more client; from memory); a server its clients
  program, in PostScript (NeWS); **a file server** (8½, rio); a
  compositor, whose clients draw in buffers of their own that it only
  puts together (Quartz, Wayland).
- **A window system that is a file server** (8½, 1991): each window
  is given a `/dev/cons`, a `/dev/mouse` and a screen to draw on (rio:
  `/dev/draw`'s window, by its `winname`) that are files the window
  system serves, in a name space of the window's own. So a program
  does not know whether it is in a window or on the bare machine, the
  window system needs no library of its own on the client's side, and
  it runs in one of its own windows (the test of the idea; none of
  mini-rio's checked sessions runs it so). What X does with a
  protocol and a connection is done with open, read and write.
- **Concurrency as the structure** (from memory: Pike's Squeak and
  Newsqueak, 1985-89, then "A Concurrent Window System", 1989): the
  mouse, the keyboard and each window are processes that talk by
  channels, after Hoare's CSP, in place of one loop over events and a
  table of states. 8½ was written in C as a state machine all the
  same; rio came back to threads and channels (Alef's, then C's
  libthread). OCaml's `Event` (from memory: Reppy's Concurrent ML) is
  of the same family, which is why xix's rio, and mini-rio (a thread a
  window), could keep rio's shape.
- **Text you can edit, not a terminal** (8½, rio): a window is a text
  the output is appended to, with a place where typing goes; any of it
  can be selected, snarfed, pasted or sent again, and scrolled back.
  No cursor addressing, so no terminal to emulate, and no curses
  program (Plan 9 has none). The same choice in Oberon's texts and
  acme.
- **Tiling against overlapping** (Oberon's viewers in two tracks; from
  memory: Cedar at PARC before it; acme after): the system places the
  windows, the user only splits. mini-oberon
  ([`plan_system_oberon.md`](../plans/done/plan_system_oberon.md)) is ix's
  place for it.
- **Who draws the decorations and decides the placement**: the window
  manager, a client (X); the window system itself (rio: a border, no
  title bar, a menu of five words); each program for its own window
  (Wayland's client-side decorations; from memory).
- **Isolation between the windows' programs** (Nitpicker, 2005; Qubes'
  GUI, 2012): a small trusted server so that one client cannot read
  another's keys or pixels, which X never tried. rio gets most of it
  from the name space: a window's program sees only its own files.

## The small ones, and rio's own clones

- **MGR** (Bellcore): a window system for dumb machines, its clients
  writing escape sequences down a terminal's line (from memory).
- **Mini-X, MicroWindows, Nano-X**: an X-like interface small enough
  for a hand-held; **Pico GUI**; **TWIN** (which the lineage leaves
  out: a graphics system more than a window system).
- **Nitpicker** (Feske and Helmuth): "minimal-complexity", about
  1,500 lines of C (from memory): views on clients' buffers, and the
  labels that say whose window it is.
- **rio elsewhere**: 9front's (the same program, grown; from memory);
  plan9port's `rio` (an X window manager with rio's looks, not the
  file server; from memory) and its `devdraw` (libdraw's protocol over
  X or macOS, so that acme and sam run there; from memory); drawterm.
- **xix's orio** (the author's, `~/xix/windows/`, surveyed 2026-10-05):
  rio in OCaml, 3,465 lines, literate, over a `lib_graphics` of 2,850;
  on Plan 9 it ran ocaml-light's threads over APE's `select`. By its
  own header: no unicode, one font, a simple terminal.
- **Orbital** (Redox, Rust): windows as files of a scheme, after Plan
  9; a compositor, after Wayland.

## The documents

From memory, to check:

- R. Pike, "The Blit: A Multiplexed Graphics Terminal" (AT&T Bell
  Labs Technical Journal, 1984); "Graphics in Overlapping Bitmap
  Layers" (ACM Transactions on Graphics, 1983).
- R. Pike, "Window Systems Should Be Transparent" (Computing Systems,
  1988); "A Concurrent Window System" (Computing Systems, 1989).
- R. Pike, "8½, the Plan 9 Window System" (USENIX, 1991); "Rio: Design
  of a Concurrent Window System" (slides, 2000); rio(1), rio(4),
  draw(3) in Plan 9's manual.
- R. Scheifler and J. Gettys, "The X Window System" (ACM Transactions
  on Graphics, 1986); J. Gosling, D. Rosenthal and M. Arden, *The NeWS
  Book* (1989).
- N. Wirth and J. Gutknecht, *Project Oberon* (1992; revised 2013),
  its chapters on the display, the viewers and the texts.
- N. Feske and C. Helmuth, "A Nitpicker's Guide to a Minimal-Complexity
  Secure GUI" (ACSAC, 2005).
- principia's own book on rio (`~/principia/windows/`), and its
  lineage, read.

## Where mini-rio sits

At the end of the Blit's line, as rio's twin in look and in idea and
not in code: a file server for its windows (`lib_networking/9p`), a thread a
window, the text of 8½ and rio (selected, snarfed, sent, scrolled
back, UTF-8), drawn through `/dev/draw` by a `lib_graphics` written
anew; in OCaml, about 800 lines for the window system and 750 for the
graphics library (2026-10-06), where principia's rio is 8,170 lines of
C over libdraw, libframe and libthread, and xix's 3,465 of OCaml. It
runs on mini-9pi with ix's own programs, mini-rc in its windows, and
is checked by its screens (`kernels/9pi`'s `make check-windows`). What
it does not have yet is in its plan.
