(* A tiny window system, written in ML as a program that runs on
 * TinyKernel.ml. It keeps the essentials of Plan 9's rio; the
 * full-size version in ix is windows/ (mini-rio). The design is in
 * plan_tiny_windows.md.
 *
 * The main idea comes from rio: {b a window looks like the machine}.
 * Every program on TinyKernel.ml is given five file descriptors: 0, 1
 * and 2 for its text, 3 where it draws (with the messages of
 * TinyKernelGraphics.ml), and 4 for its mouse. The kernel connects the
 * first shell to the console, the screen and the mouse. tiny-windows
 * instead gives the shell of each window three pipes and a box. It is
 * itself just a program that reads its 0 and its 4 and draws on its 3.
 * So a program cannot tell whether it has the whole screen or a
 * window, and tiny-windows can run unchanged inside one of its own
 * windows.
 *
 *            the console        the screen        the mouse
 *     (or, in a window, what the window system above provides)
 *                | 0                 ^ 3               | 4
 *                v                   |                 v
 *          +------------------ tiny-windows ------------------+
 *          | sends the keys to   forwards every     sends the  |
 *          | the front window,   window's draw      mouse to   |
 *          | a line at a time    messages, with     the window |
 *          | on Enter            renumbered images  under it   |
 *          +----|-------------^-----------^-------------|------+
 *               | a pipe      | a pipe    | a pipe      | a box
 *               v 0           | 1, 2      | 3           v 4
 *          +----------------- a window's shell ----------------+
 *          | sh, and what it runs: ls, paint, tetris,          |
 *          | windows                                           |
 *          +---------------------------------------------------+
 *
 * There is one such set of four connections for each window. Here is
 * what goes up the third pipe when a program makes a red image and
 * fills its window with it, and what tiny-windows then writes on its
 * own 3:
 *
 *     the program:       a 1 ... red          d 0 1 none, the window
 *     tiny-windows:      a 17 ... red         d 16 17 none, the same
 *                        then, for what changed on the screen:
 *                        d 0 16 none, where the window is
 *
 * Here 16 is the image tiny-windows made for that window, and 17 is
 * the first number it had free. If this tiny-windows itself runs in a
 * window of another tiny-windows, its 0, 16 and 17 are renumbered
 * again by the one above, and only the outermost 0 is the kernel's
 * real screen.
 *
 * How the idea is implemented, each time in the cheapest way that
 * still keeps it:
 *
 * - {b The kernel holds every pixel.} A window is an off-screen image
 *   created by a message; tiny-windows only knows its number, never
 *   its bytes. What appears on the screen is composed by drawing the
 *   windows back to front, clipped to the rectangle that changed.
 *   There are no layers: mini-9pi's Memlayer saves the hidden parts
 *   of windows separately, but here nothing needs saving.
 * - {b Forwarding is renumbering.} The program in a window names its
 *   images with its own numbers, 0 being its window. tiny-windows
 *   reads these messages from a pipe, replaces each number with one of
 *   its own (0 becomes the window's image), and passes the message on
 *   to its own 3. A window system running in a window is therefore
 *   renumbered twice.
 * - {b There is one loop.} The kernel call ready waits at the same
 *   time for the mouse, the keys and the two pipes of every window.
 *   rio, in contrast, has one thread per window, with channels between
 *   them.
 * - {b A window shows either text or a picture.} What its programs
 *   print is drawn in it, one character per cell, scrolling at the
 *   bottom; the keys typed are then collected into a line, edited
 *   here, and delivered on Enter. As soon as a program draws in the
 *   window, the window becomes that program's picture: each key is
 *   delivered as it is typed, and the mouse in the window belongs to
 *   the program. This lasts until something is printed again (for
 *   example the shell's prompt, once the program ends).
 * - {b A mouse is a box}: the position of the mouse in the window is
 *   written to a special kind of kernel pipe that keeps only the last
 *   write. So a program that never reads its mouse does not block
 *   anything.
 *
 * The mouse: clicking the left button on a window brings it to the
 * front, where it receives the keys. The right button opens the menu
 * (New, Move, Delete, Exit), and then the left button says where: you
 * sweep a rectangle, drag a window, or point at a window.
 *
 * What is dropped: a menu specific to each window, scroll bars and the
 * kept text of a window (what scrolls off the top is lost), selection,
 * snarf and paste, Resize and Hide, cursor shapes, using the border as
 * a handle, window names, and the files a window serves. rio is a file
 * server, but here the descriptors are simply handed over, because
 * TinyKernel.ml has no name space.
 *
 * Exercises:
 * - Resize: make a new image, draw the old one in it, free the old one;
 * - keep the text and add a scroll bar; add selection, snarf and paste;
 * - tell a program the size of its window (a message read on its 4);
 * - let New start a program other than the shell (an argument).
 *
 * Where it stands: TinyKernel provides the five descriptors, the
 * pipes, the box and ready; TinyKernelGraphics, inside the kernel,
 * holds the images; TinyLibDraw builds and parses the messages. The
 * programs that run in a window (paint in C, TinyKernel/examples/paint.c, and
 * TinyAppTetris on TinyLibPlayground) also run without it. mini-rio is
 * the complete version: Wm and Window, a Terminal for the text of a
 * window, and Fileserver, Virtual_cons and Virtual_mouse for the files
 * that a window's program opens.
 *
 * cs-history:
 * The idea comes from the Blit (Rob Pike, Bell Labs, 1982). Its window
 * system, mpx, was called a multiplexer because that was all it did:
 * it gave each window a terminal just like the one the whole screen
 * had been, so a program written for a terminal ran in a window
 * without knowing it. Pike's 8 1/2 for Plan 9 (1991) kept the idea and
 * gave it its final form: the window system is a file server, and the
 * files it serves to each window, /dev/cons, /dev/mouse and the screen
 * files, have the same names as the files the kernel serves to it. rio
 * (2000) is 8 1/2 rewritten with threads. Running a window system
 * inside one of its own windows is the test of the idea, and both
 * 8 1/2 and rio pass it.
 *
 * plan9-is-cleaner:
 * In X, a program does not draw on something it was given. It
 * connects to a server through a socket and speaks a protocol of
 * about a hundred and twenty requests. Which window goes where is
 * decided by a third program, the window manager, following its own
 * rules. And running a server inside a window requires a special
 * server written for that purpose (Xnest, Xephyr). Here, as in rio,
 * there is no real protocol and no separate manager, because what a
 * window's program sees is the kernel's own interface, and nesting
 * needs no extra code.
 *
 * modern:
 * Making each window an off-screen image and composing the screen from
 * them back to front is where window systems ended up once memory and
 * graphics processors allowed it (Mac OS X's Quartz in 2001, the X
 * compositors, and Wayland, where it is the only way). A window that
 * is moved or uncovered is simply copied again; its program is never
 * asked to redraw. Earlier systems drew a window directly on the
 * screen where it is visible and handled the rest separately: either
 * with layers that save the hidden parts (rio), or with a message
 * telling the program which part of its window was uncovered (X). The
 * old way saves memory; the new way made shadows, transparency and
 * smooth moves almost free.
 *
 * References: R. Pike, "The Blit: A Multiplexed Graphics Terminal"
 * (1984), "8½, the Plan 9 Window System" (1991) and "Rio: Design of a
 * Concurrent Window System" (2000), on a window system as a
 * multiplexer that gives programs the same interface it uses itself;
 * N. Wirth and J. Gutknecht, "Project Oberon" (1992), for the other
 * road, where windows are part of the system; principia's
 * windows/rio/ (rio's C: wm.c, fsys.c, terminal.c...) and xix's rio in
 * OCaml, which mini-rio follows, module by module. *)

(* A program: its last lines are its loop, and it gives nothing to
 * another file. OCaml only checks it (its system calls are the
 * machine's externals: no program is linked on the host). *)
