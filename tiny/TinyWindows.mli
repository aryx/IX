(* A tiny window system, a program of TinyKernel.ml's, in ML: the
 * essential of Plan 9's rio (ix's twin is windows/, mini-rio). Compiled
 * by tiny-ml -tm after TinyLibDraw.ml, TinyKernel/user/mlsys.c its runtime
 * and its system calls (plan_tiny_windows.md):
 *
 *     ./tiny-machine -window tiny-kernel
 *     $ windows
 *     the right button: New, then a rectangle swept with the left one;
 *     in the window, a shell: ls, paint, windows
 *
 * The idea kept is rio's: {b a window looks like the machine}. A
 * program of TinyKernel.ml is given five descriptors: 0, 1 and 2 its
 * text, 3 where it draws (TinyKernelGraphics.ml's messages), 4 its mouse. The
 * kernel gives the first shell the console, the screen and the mouse;
 * tiny-windows gives each window's shell three pipes and a box, and is
 * itself a program that reads its 0 and its 4 and draws on its 3. So a
 * program does not know whether it has the screen or a window, and
 * tiny-windows runs in one of its own windows unchanged.
 *
 *            the console        the screen        the mouse
 *     (or, in a window, what the window system above gives for them)
 *                | 0                 ^ 3               | 4
 *                v                   |                 v
 *          +------------------ tiny-windows ------------------+
 *          | the keys to the     every window's     the mouse  |
 *          | front window, a     messages, their    in a       |
 *          | line at the Enter   images renumbered  window     |
 *          +----|-------------^-----------^-------------|------+
 *               | a pipe      | a pipe    | a pipe      | a box
 *               v 0           | 1, 2      | 3           v 4
 *          +----------------- a window's shell ----------------+
 *          | sh, and what it runs: ls, paint, tetris,          |
 *          | windows                                           |
 *          +---------------------------------------------------+
 *
 * (one such column of four for each window). What goes up the third
 * pipe, for a program that makes a red image and fills its window
 * with it, and what tiny-windows writes on its own 3:
 *
 *     the program:       a 1 ... red          d 0 1 none, the window
 *     tiny-windows:      a 17 ... red         d 16 17 none, the same
 *                        then, for what changed on the screen:
 *                        d 0 16 none, where the window is
 *
 * 16 being the image it made for that window and 17 the first number
 * it had free. Run in a window of another tiny-windows, its 0 and its
 * 16 and 17 are renumbered again by the one above, and only the
 * outermost 0 is the kernel's screen.
 *
 * How, each the cheapest that keeps the idea:
 *
 * - {b The kernel has every pixel.} A window is an image off the
 *   screen, made by a message; tiny-windows has its number, never its
 *   bytes. What shows is composed: the windows drawn on the screen
 *   back to front, clipped to the rectangle that changed (no layers:
 *   mini-9pi's Memlayer keeps what is hidden apart; here nothing is).
 * - {b Forwarding is renumbering.} A window's program names its images
 *   by numbers of its own, 0 its window. tiny-windows reads its
 *   messages from a pipe, gives each number one of its own (0 is the
 *   window's image) and sends the message on, to its own 3. A window
 *   system in a window is renumbered twice.
 * - {b One loop.} ready, the kernel's call, waits for the mouse, the
 *   keys and every window's two pipes at once: rio has a thread a
 *   window and channels for it.
 * - {b A window is a text or a picture.} What its programs print is
 *   drawn in it, a character a cell, scrolled at the bottom; the keys
 *   are then a line, edited here and given at the Enter. When a
 *   program draws in it, the window is its picture: each key is given
 *   as typed, and the mouse in it is the program's, until something
 *   is printed again (the shell's prompt, after the program's end).
 * - {b A mouse is a box}: where it is in the window, written to the
 *   kernel's kind of pipe that keeps the last write only, so that a
 *   program that does not read its mouse stops nothing.
 *
 * The mouse: the left button on a window brings it to the front, where
 * it has the keys; the right button is the menu (New, Move, Delete,
 * Exit), then the left one says where: a rectangle swept, a window
 * dragged, a window pointed at.
 *
 * Dropped: a window's own menu, its scroll bar and its text kept (what
 * left the top is gone), selecting, snarf and paste, Resize and Hide,
 * the cursor's shapes, a border as a handle, a window's name and the
 * files it serves (rio is a file server: here descriptors are given,
 * TinyKernel.ml having no name space).
 *
 * Exercises:
 * - Resize: a new image, the old one drawn in it, freed;
 * - the text kept and a scroll bar; a selection, snarf and paste;
 * - the window's size told to its program (a message read on its 4);
 * - a program started by New other than the shell (an argument).
 *
 * Where it stands: TinyKernel gives the five descriptors, the pipes,
 * the box and ready; TinyKernelGraphics, in the kernel, has the images;
 * TinyLibDraw makes and reads the messages; the programs in a window
 * (TinyKernel/user's paint in C, TinyAppTetris on TinyLibPlayground) are the
 * ones that run without it. mini-rio is the whole of it: Wm and
 * Window, a window's text as a Terminal, and Fileserver, Virtual_cons
 * and Virtual_mouse for what a window's program opens.
 *
 * cs-history:
 * The idea is the Blit's (Rob Pike, Bell Labs, 1982): its window
 * system, mpx, was called a multiplexer because that is all it did,
 * give each window a terminal like the one the whole screen had
 * been, so that a program written for a terminal ran in a window
 * knowing nothing. Pike's 8 1/2 for Plan 9 (1991) kept the idea and
 * found its form: the window system is a file server, and what it
 * serves each window, /dev/cons, /dev/mouse and the screen's files,
 * are the names of what the kernel serves it. rio (2000) is 8 1/2
 * rewritten with threads. A window system run in its own window is
 * the test of the idea, and 8 1/2 and rio pass it.
 *
 * plan9-is-cleaner:
 * In X a program does not draw on something it was given: it
 * connects to a server by a socket and speaks a protocol of about
 * a hundred and twenty requests; which window is where is decided by
 * a third program, the window manager, by rules of its own; and a
 * server run inside a window is a special server (Xnest, Xephyr),
 * written for that. Here, as in rio, there is no protocol to speak
 * of and no manager apart, since what a window's program sees is
 * the kernel's own interface, and nesting needs no code.
 *
 * modern:
 * Each window an image off the screen, and the screen composed from
 * them back to front, is what window systems came to when memory
 * and graphics processors allowed (Mac OS X's Quartz, 2001; the
 * compositors of X; Wayland, where it is the only way): a window
 * moved or uncovered is copied again, never asked to redraw. The
 * systems before drew a window where it shows, on the screen itself,
 * and dealt with the rest apart: layers that save the hidden parts
 * (rio), or a message telling a program which part of its window
 * was uncovered (X). The old way saves memory; the new one made
 * shadows, transparency and smooth moves nearly free.
 *
 * References: R. Pike, "The Blit: A Multiplexed Graphics
 * Terminal" (1984), "8½, the Plan 9 Window System" (1991) and "Rio:
 * Design of a Concurrent Window System" (2000): a window system as a
 * multiplexer that gives what it takes; N. Wirth and J. Gutknecht,
 * "Project Oberon" (1992), the other road, windows in the system. *)

(* A program: its last lines are its loop, and it gives nothing to
 * another file. OCaml only checks it (its system calls are the
 * machine's externals: no program is linked on the host). *)
