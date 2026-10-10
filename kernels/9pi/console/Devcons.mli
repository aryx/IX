(* '#c', the console (principia's devcons.c): /dev/cons, what the
 * programs read and write, on the serial console (the screen's is
 * stage D). Its input cooked as Plan 9's: each character echoed as
 * typed, a line at a time, backspace and ^U editing it, ^D ending it
 * without a newline (an empty one: the end of file); raw (consctl's
 * rawon): neither. Output as 9pi's UART gives it: a CR before each LF.
 * Also consdir's other files: pid, ppid, user, time, null, zero, swap
 * (its writes ignored: no swapping here)...
 *
 *     typed        the line kept    a read of /dev/cons
 *     l s x        lsx              sleeps (Proc.sleep Console_input)
 *     backspace    ls               still
 *     Enter        (empty)          returns the 3 bytes ls and newline
 *     ^D           (empty)          returns 0 bytes: the end of file
 *
 * Each byte is echoed as it comes, the backspace too: the terminal on
 * the serial line does what it wants with it. A read gets one line
 * at most (its first bytes, when the buffer is smaller).
 *
 * Where it stands: the UART's interrupt gives a byte to [intr] (from
 * Main's [devices]); the keyboard's runes come through Kbd to
 * [kbdputc]; what the kernel prints goes out by [print], to the
 * serial line and to the screen's console (Swconsole). Programs under
 * a window system never open this one: their /dev/cons is the
 * window's, a file the window system serves, and it does the editing
 * (mini-rio); this device is then read by the window system alone,
 * raw.
 *
 * plan9-is-cleaner:
 * No terminal driver beyond these few lines. Unix's is a subsystem:
 * line disciplines, the termios structure with its dozens of flags set
 * by ioctl (stty), a controlling terminal for each session, job
 * control with its signals for the foreground group, and pseudo
 * terminals, pairs of devices that let a window or a network login
 * pretend to be a serial line. Plan 9 needs none: raw mode is the
 * word rawon written to consctl and lasts while that file is open;
 * a window is a file server that serves a cons; a remote login
 * brings its own cons with its name space. And the small files
 * here are system calls elsewhere: pid (getpid), ppid, user
 * (getuid), time (time, gettimeofday), null and zero (device nodes
 * with numbers of their own).
 *
 * cs-history:
 * The cooked line is as old as time sharing: a terminal sent a
 * character at a time over a slow line, and the system, not each
 * program, let the user take back a mistake before it counted. On
 * the first Unix, with printing terminals that could not erase, #
 * rubbed out a character and @ the whole line; backspace and ^U came
 * with screens. ^D is ASCII's EOT, end of transmission: not a
 * character the file contains, only the line sent as it is, and a
 * line of nothing is a read of nothing, which is what the end of a
 * file looks like.
 *
 * References: cons(3) in the Plan 9 manual. principia's Kernel.nw
 * (devcons.c). Rob Pike, "8 1/2, the Plan 9 Window System" (USENIX
 * Summer 1991), for a window as the server of a cons. *)

(* a character typed on the serial line (the UART's interrupt: a CR is
 * a LF, kbdcr2nl); a rune from the keyboard (kbdputc, Kbd's) *)
val intr : int -> unit
val kbdputc : int -> unit
(* a message for #c/kbd's readers (Kbd's: the keys down, at each change) *)
val kbd_message : string -> unit

(* the console's output (the kernel's messages too) *)
val print : string -> unit

(* the device registered *)
val init : unit -> unit
