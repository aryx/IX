(* What the kernel's files say about the machine, for mini-stats. This
 * module reads their text, without a screen and without a kernel.
 *
 *     /dev/sysstat      a line for each core; the ninth number is the
 *                       percent of time idle
 *     /dev/swap         "1234/85000 user": the pages taken, and in all
 *     /net/ether0/stats "in: 12", "out: 34": packets since the boot
 *     /dev/sdM0/ctl     "io 512 1024": bytes read and written since the boot
 *
 * plan9-is-cleaner:
 * Each is a file of text that cat shows. Plan 9's stats reads /dev/sysstat,
 * /dev/swap and /net/ether0/stats in just this way. On Linux, top and
 * xosview read /proc the same way, though /proc's formats grew by accident.
 * On BSD and macOS the same numbers come from sysctl, a system call with a
 * structure for each.
 *
 * Two of the numbers are counters, so what is shown is how much they grew
 * since the last look ([grew]). A rate goes from nothing to millions, and a
 * strip has only its share of the window's height. [log_percent] gives
 * each power of ten the same height, so that a trickle can be seen beside
 * a flood, and a strip already drawn need not be drawn again at a new
 * scale when the flood comes. *)

(* each core's percent busy, in the cores' order *)
val cores : string -> int list
(* the pages taken, as a percent of the pages in all *)
val memory : string -> int option
(* packets in, packets out *)
val ether : string -> (int * int) option
(* bytes read, bytes written *)
val disk : string -> (int * int) option

(* [grew before now]: how much the counter grew. For a counter that went
 * back (none should), it gives nothing, 0. *)
val grew : int -> int -> int
(* [log_percent top v]: v on a scale where [top] is 100 and each power of ten
 * has the same height; 0 is 0, and 1 is above 0 *)
val log_percent : int -> int -> int
(* a number in short: 7, 950, 12K, 3M *)
val short : int -> string
