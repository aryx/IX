(* A guest's memory: segments of bytes at addresses, each checked on
 * every access; the bus the CPU loads and stores through (plan_arm.md,
 * decision 4). An access outside every segment raises Fault, the
 * guest's segmentation fault.
 *
 *   map m ~base:0x80a0 ~size:0x6ee8 "text"
 *   load32 m 0x80cc                       the word at the entry
 *
 * Addresses and values are words (Bits): compared unsigned, so that
 * the same code is right under js_of_ocaml. Little-endian. Unaligned
 * words and halfwords are allowed, as ARMv6 and later allow them to
 * user programs.
 *
 * A segment is of two kinds, and the CPU cannot tell which it
 * touches:
 *
 *     a Plan 9 program's (mini-5i)       a board's (mini-qemu's Pi 1)
 *     0x1000    "text"   bytes           0x00000000  "ram"   bytes
 *     then      "data"   bytes           0x20003000  "systimer"  a device
 *     then      "heap"   bytes, grown    0x20201000  "uart0"     a device
 *     at the top "stack" bytes           ...
 *
 * Bytes are an array. A device is two functions, read and write: a
 * store to 0x20201000 is no store, it is the UART's write called
 * with offset 0, which prints a character. Nothing else connects
 * the processor to its devices, here or on the board.
 *
 * Where it stands: the cores (Arm32, Arm64) load and store through
 * it, with physical addresses (the MMUs translate before); the
 * personalities (Linux, Plan9) read a system call's strings and
 * buffers from it and grow its heap; a board maps its RAM and each
 * device of raspberry/ once, at its address.
 *
 * design:
 * Memory-mapped I/O. A device's registers answer at addresses, and
 * the instructions that drive a disk or a screen are the ordinary
 * load and store: no instruction of the processor is about I/O, a
 * driver is C that writes through a pointer, and one protection
 * mechanism, the MMU, covers memory and devices. The PDP-11 had it
 * so (its top 8 KB were the devices), and ARM does. The other
 * school gives I/O its own instructions and its own space of port
 * numbers (the 8080's in and out, kept by every x86).
 *
 * wib:
 * An unmapped address is a fault and nothing subtler: no bus error
 * told from a segmentation fault, no access rights on a segment
 * (the text can be written), no alignment trap. What a real system
 * would refuse and this allows is a wrong program that runs here;
 * rights are the MMU's work when there is one. *)

type t

exception Fault of int

val create : unit -> t

(* a zeroed segment *)
val map : t -> base:int -> size:int -> string -> unit

(* a segment of the caller's bytes (a board's RAM) *)
val map_bytes : t -> base:int -> string -> Bytes.t -> unit

(* a device: loads and stores of 1, 2 or 4 bytes by offset in its range
 * (a board's registers); the last mapped wins where ranges overlap *)
type device = { read : int -> int -> int; write : int -> int -> int -> unit }

val map_device : t -> base:int -> size:int -> string -> device -> unit

(* the segment's end grown or shrunk (brk); its end *)
val resize : t -> string -> size:int -> unit
val segment_end : t -> string -> int

val load8 : t -> int -> int
val load16 : t -> int -> int
val load32 : t -> int -> int
val store8 : t -> int -> int -> unit
val store16 : t -> int -> int -> unit
val store32 : t -> int -> int -> unit

(* arm64's doublewords, as Int64 (an int has 63 bits, or 32 under
 * js_of_ocaml) *)
val load64 : t -> int -> int64
val store64 : t -> int -> int64 -> unit

val write_string : t -> int -> string -> unit
val read_string : t -> int -> int -> string

(* the RAM's own bytes where [n] bytes at an address are, and their
 * place in them: read_string without the copy *)
val direct : t -> int -> int -> Bytes.t * int

(* a NUL-terminated string at the address *)
val read_cstring : t -> int -> string
