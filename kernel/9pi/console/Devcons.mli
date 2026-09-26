(* '#c', the console (principia's devcons.c): /dev/cons, what the
 * programs read and write, on the serial console (the screen's is
 * stage D). Its input cooked as Plan 9's: each character echoed as
 * typed, a line at a time, backspace and ^U editing it, ^D ending it
 * without a newline (an empty one: the end of file); raw (consctl's
 * rawon): neither. Output as 9pi's UART gives it: a CR before each LF.
 * Also consdir's other files: pid, ppid, user, time, null, zero, swap
 * (its writes ignored: no swapping here)... *)

(* a character typed on the serial line (the UART's interrupt: a CR is
 * a LF, kbdcr2nl); a rune from the keyboard (kbdputc, Kbd's) *)
val intr : int -> unit
val kbdputc : int -> unit

(* the console's output (the kernel's messages too) *)
val print : string -> unit

(* the device registered *)
val init : unit -> unit
