(* mini-qemu's meters (a window has them; -meters off, -meters on):
 * the board's processor and network watched, in
 * a strip under the screen and in the window's title -- what QEMU's
 * window does not say, and a reason to prefer this one while a kernel
 * or its network is being written.
 *
 *   mini-qemu  cpu 43%, user 12%,  11.2 Mips  x1.00  net in 120 KB/s out 3 KB/s  2 tcp 1 udp  tcp 93.184.216.34:80
 *
 *   +--------------------------------------+--------------------------------------+
 *   |  the processor: a column a half      |  the network: the bytes come to the  |
 *   |  second, as high as the share of     |  guest upward (blue), those it sent  |
 *   |  the board's time it ran; the user   |  downward (orange), from the middle; |
 *   |  programs' part light, the kernel's  |  a column's full height 1 MB/s, a    |
 *   |  dark; nothing: it waited (WFI)      |  step a factor of ten less           |
 *   +--------------------------------------+--------------------------------------+
 *
 * The numbers are the last period's (half a second in a window, a
 * second without): the share of the board's
 * time the processor ran (the rest waited at a WFI: Status's count,
 * by instructions), the part of it in user mode, the instructions
 * the host ran a second, the board's clock against the host's (x1.00:
 * as a real board), the frames' bytes each way (Usernet's), the TCP
 * connections and UDP conversations open, and the last thing the
 * network did. Without a window (-nographic) the line is written on
 * the standard error each second.
 *
 * Nothing here is of the guest's own saying: a kernel that is wedged
 * still shows as a full dark column, which is the point.
 *
 * others:
 * QEMU has a monitor to ask (info registers, info network), and its
 * trace events; a picture of the load is left to tools outside.
 * The strip is the idea of xload (Jim Fulton's, with X11) and of
 * Plan 9's stats (a graph a line for a machine's load, its
 * interrupts, its Ethernet's packets), which read a kernel's own
 * counters; here the machine itself is at hand. *)

type t

(* [period]: the host's seconds a column and the numbers are of *)
val create : period:float -> t

(* after a batch: its CPUs (Board.where's, which Status takes too) *)
val sample : t -> Status.cpu list -> unit

(* each frame: [host] the host's seconds, [board] the board's
 * microseconds, the networks' totals. True when a period has
 * passed and a column was added: the strip and the line have changed *)
val tick : t -> host:float -> board:int -> net:Usernet.totals -> bool

(* the title's line *)
val line : t -> string

(* the strip, [height] rows of [width] pixels, three bytes each (red,
 * green, blue) *)
val height : int
val strip : t -> width:int -> string
