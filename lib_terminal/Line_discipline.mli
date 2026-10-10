(* Line_discipline: the tty, between the keyboard and the program.

   When a program asks for a line ("What is your name?"), it doesn't
   see the keys as they are typed: it sees nothing until Enter, and
   then the line, the typos already fixed with Backspace. Who fixed
   them? Not the program, and not the terminal: the tty driver in the
   kernel, sitting between the two, which keeps the line being typed,
   echoes each key back to the screen (the terminal itself shows
   nothing it isn't sent), and hands the line over on Enter. That is
   *cooked mode*, and its rules are the *line discipline*:

       keyboard --bytes--> [ line discipline ] --lines--> program
                                  |
                                echo
                                  v
       screen   <--bytes-------------------------------- program
                        (\n becomes \r\n on the way out)

   Its keys, the Unix ones (stty -a shows them):

       Enter (CR or LF)   the line goes to the program
       Backspace (DEL)    the last character erased: echoed as BS SP BS,
                          back, a space over it, back again
       Control-U          the whole line erased
       Control-W          the last word erased
       Control-C          the program interrupted (the kernel's SIGINT)
       Control-D          on an empty line, the end of the input

   *Raw mode* turns all of it off: each key goes to the program at
   once, unechoed, Control-C included. It is what full-screen programs
   ask for (vi, Rogue, a shell's own line editor, bash's readline:
   the arrow keys that move in a command line are readline in raw
   mode, not the tty, which has no idea what an arrow is -- in cooked
   mode, this module drops the keys that are escape sequences).

   The other direction has one rule of its own, ONLCR: the program
   writes "\n", a Unix file's end of line, and the terminal needs CR
   LF, back to the first column and down a line -- two motions, as on
   a teletype's carriage. The tty adds the CR ([output]).

   Worked example (checked by the tests), cooked, echo on: the keys

       h e l x DEL l o CR

   echo "helx", then BS SP BS (the x erased on the screen), then "lo",
   then CR LF; the program reads the one line "hello", and a Vt fed
   the echo shows "hello" with the cursor on the next line.

   Simplified: Control-D on a line that isn't empty does nothing (Unix
   hands the program the partial line); Control-C is only an event
   (the program decides what an interrupt means); the special keys
   can't be changed (stty's intr, erase, kill); Backspace erases a
   UTF-8 character, not a byte, as Linux's IUTF8 flag does.

   In ix this module is the tty as a value, for a terminal that is a
   value (Talk's machine, with Vt for its screen). The same rules are
   written twice more, for real: in the kernel, where Devcons keeps
   the line typed on mini-9pi's console and puts the reader to sleep
   until Enter; and in the window system, where Virtual_cons does it
   for the programs of a window. On Linux it is the kernel's, which
   Tty_unix turns off.

   cs-history:
   The rules are older than the screen. On a Teletype nothing typed
   could be rubbed out, so the first Unix erased with characters that
   printed: # took back the character before it and @ the whole line,
   and one read helx#lo on the paper and knew the program would get
   hello. The interrupt was DEL. Erasing on the glass (BS SP BS), the
   word erased, and Control-C, Control-U and DEL in their present
   places came with the video terminals and Berkeley's terminal
   driver (from memory); stty still sets any of them.

   terminology:
   Terminal, tty, console, pty. A terminal is the device, a keyboard
   and something that shows characters. A tty (from teletype) is the
   kernel's file for one, /dev/tty1, with its line discipline. The
   console is the terminal that is part of the computer, where the
   kernel prints. A pseudo-terminal (pty) is a tty with no device: a
   pair of files, what is written in one read from the other, with
   the line discipline between, so that a program (xterm, sshd) can
   sit where the device was and the programs it runs still find a
   tty. The shell is none of them: a program that reads the lines.

   plan9-is-cleaner:
   Plan 9 has no pty and no termios. The console is a file, and a
   window system gives each window a file of the same name that it
   serves itself: nothing in the kernel needs to pretend to be a
   device. Raw mode is a word written to a second file (Virtual_cons,
   Devcons).

   References: the tty(4) and termios(3) manual pages; Linus Åkesson,
   "The TTY demystified" (2008); Ken Thompson and Dennis Ritchie, "The
   UNIX Time-Sharing System" (1974), whose typewriter files are this. *)

(*****************************************************************************)
(* {1 The tty} *)
(*****************************************************************************)

type mode = Cooked | Raw

(* what the program reads *)
type event =
  | Line of string (* cooked: a line, without its end of line *)
  | Key of string (* raw: one key, as its bytes ("a", "\r", "\x1b[A") *)
  | Interrupt (* cooked: Control-C *)
  | End_of_file (* cooked: Control-D on an empty line *)

type t

(* cooked, echo on, the line empty *)
val create : unit -> t

val mode : t -> mode
val set_mode : t -> mode -> t
val set_echo : t -> bool -> t

(* the line being typed, not yet sent *)
val pending : t -> string

(* bytes from the keyboard -> the tty after them, the bytes to echo
   to the screen, and what the program reads, in order *)
val input : t -> string -> t * string * event list

(* bytes from the program -> the bytes for the terminal (ONLCR) *)
val output : string -> string

(* bytes into keys: an escape sequence (ESC [ A) or a UTF-8 character
   is one key, anything else a byte; a lone ESC at the end is the
   Escape key *)
val split_keys : string -> string list
