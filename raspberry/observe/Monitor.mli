(* These are mini-qemu's meters. A window has them, and -meters off or
 * -meters on chooses. They watch the board's processor and network,
 * and show them in a strip under the screen and in the window's title.
 * QEMU's window does not say this, which is a reason to prefer this
 * one while a kernel or its network is being written.
 *
 *   mini-qemu  cpu 43%, user 12%,  11.2 Mips  x1.00  net in 120 KB/s out 3 KB/s  2 tcp 1 udp  tcp 93.184.216.34:80
 *
 *   +--------------------------------------+--------------------------------------+
 *   |  the processor: a column each half   |  the network: the bytes that came to |
 *   |  second, as high as the share of     |  the guest go upward (blue), those   |
 *   |  the board's time it ran; the user   |  it sent go downward (orange), from  |
 *   |  programs' part is light, the        |  the middle; a column's full height  |
 *   |  kernel's dark; empty when it waited |  is 1 MB/s, and each step is a       |
 *   |  (WFI)                               |  factor of ten less                  |
 *   +--------------------------------------+--------------------------------------+
 *
 * The numbers are those of the last period (half a second in a
 * window, a second without one). They are:
 * - the share of the board's time that the processor ran (the rest it
 *   waited at a WFI; this is Status's count, by instructions);
 * - the part of that time in user mode;
 * - the instructions run each second of the host's time;
 * - the board's clock against the host's (x1.00 is as fast as a real
 *   board);
 * - the frames' bytes in each direction (from Usernet);
 * - the TCP connections and UDP conversations open;
 * - the last thing the network did.
 * Without a window (-nographic), the line is written on the standard
 * error each second.
 *
 * Nothing here comes from the guest's own saying. A kernel that is
 * wedged still shows as a full dark column, which is the point.
 *
 * others:
 * QEMU has a monitor to ask (info registers, info network), and its
 * trace events, and leaves a picture of the load to tools outside.
 * The strip is the idea of xload (Jim Fulton's, with X11) and of Plan
 * 9's stats, which draws a graph on a line for each of a machine's
 * load, its interrupts, its Ethernet's packets, and so on. Those read
 * a kernel's own counters; here the machine itself is at hand. *)

type t

(* [period] is how many of the host's seconds a column and the numbers
 * cover *)
val create : period:float -> t

(* [sample] is called after a batch, with its CPUs (from Board.where,
 * which Status takes too) *)
val sample : t -> Status.cpu list -> unit

(* [tick] is called at each frame, with [host] the host's seconds,
 * [board] the board's microseconds, and the networks' totals. It
 * returns true when a period has passed and a column was added, so
 * the strip and the line have changed. *)
val tick : t -> host:float -> board:int -> net:Usernet.totals -> bool

(* the title's line *)
val line : t -> string

(* the strip: [height] rows of [width] pixels, with three bytes for each
 * pixel (red, green, blue) *)
val height : int
val strip : t -> width:int -> string
