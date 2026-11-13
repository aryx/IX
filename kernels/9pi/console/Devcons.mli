(* '#c' is the console (principia's devcons.c). Its /dev/cons is what the
 * programs read and write, on the serial console (the screen's console
 * is stage D). Its input is cooked as Plan 9's is:
 * - each character is echoed as it is typed;
 * - a read gets a line at a time, which backspace and ^U edit;
 * - ^D ends the line without a newline (an empty line is the end of
 *   file);
 * - Delete or ^C interrupts the programs of the shell that reads it
 *   (the note "interrupt" is posted to its note group).
 * In raw mode (consctl's rawon), none of this is done. Output is given
 * as 9pi's UART gives it, with a CR before each LF. There are also
 * consdir's other files: pid, ppid, user, time, null, zero, swap...
 * Nothing is swapped here, but writing "start" to swap starts the
 * kernel process kpager, as in 9pi, and "draw N" chooses which copies
 * of the pixels give the kernel's lock back.
 *
 *     typed        the line kept    a read of /dev/cons
 *     l s x        lsx              sleeps (Proc.sleep Console_input)
 *     backspace    ls               still
 *     Enter        (empty)          returns the 3 bytes ls and newline
 *     ^D           (empty)          returns 0 bytes: the end of file
 *
 * Each byte is echoed as it comes, the backspace too, and the terminal
 * on the serial line does what it wants with it. A read gets one line
 * at most (only its first bytes, when the buffer is smaller).
 *
 * Where it stands: the UART's interrupt gives a byte to [intr] (from
 * Main's [devices]); the keyboard's runes come through Kbd to
 * [kbdputc]; and what the kernel prints goes out by [print], to the
 * serial line and to the screen's console (Swconsole). Programs under a
 * window system never open this device: their /dev/cons is the
 * window's, a file that the window system serves, and the window system
 * does the editing (mini-rio). This device is then read by the window
 * system alone, in raw mode.
 *
 * plan9-is-cleaner:
 * There is no terminal driver beyond these few lines. Unix's terminal
 * driver is a subsystem: line disciplines, the termios structure with
 * its dozens of flags set by ioctl (stty), a controlling terminal for
 * each session, job control with its signals for the foreground group,
 * and pseudo terminals, which are pairs of devices that let a window or
 * a network login pretend to be a serial line. Plan 9 needs none of
 * it. Raw mode is the word rawon written to consctl, and it lasts while
 * that file is open. A window is a file server that serves a cons. A
 * remote login brings its own cons with its name space. And the small
 * files here are system calls elsewhere: pid (getpid), ppid, user
 * (getuid), time (time, gettimeofday), and null and zero (device nodes
 * with numbers of their own).
 *
 * cs-history:
 * The cooked line is as old as time sharing. A terminal sent one
 * character at a time over a slow line, and the system, not each
 * program, let the user take back a mistake before it counted. On the
 * first Unix, with printing terminals that could not erase, # rubbed
 * out a character and @ the whole line; backspace and ^U came with
 * screens. ^D is ASCII's EOT, end of transmission. It is not a
 * character that the file contains; it only sends the line as it is,
 * and a line of nothing is a read of nothing, which is what the end of
 * a file looks like.
 *
 * References: cons(3) in the Plan 9 manual. principia's Kernel.nw
 * (devcons.c). Rob Pike, "8 1/2, the Plan 9 Window System" (USENIX
 * Summer 1991), for a window as the server of a cons. *)

(* [intr] takes a character typed on the serial line (from the UART's
 * interrupt; a CR is taken as a LF, as kbdcr2nl does), and [kbdputc]
 * a rune from the keyboard (kbdputc, called by Kbd) *)
val intr : int -> unit
val kbdputc : int -> unit
(* gives a message to #c/kbd's readers (Kbd calls it with the keys
 * down, at each change) *)
val kbd_message : string -> unit

(* the console's output (the kernel's messages go there too) *)
val print : string -> unit

(* /dev/sysstat, which has a line for each core, as 9pi's does. [cores]
 * is the number of cores that run processes (1 until the kernel says
 * more), and [account] is each tick's look at how long each core waited
 * (the percent idle is over the last fifth of a second). *)
val cores : int ref
val account : unit -> unit

(* registers the device *)
val init : unit -> unit
