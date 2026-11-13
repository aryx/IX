(* This is mini-qemu's -status N. Every N seconds of the host's time,
 * it writes a line on standard error that says where the guest is. It
 * shows where a boot blocks without a debugger (mini-pi -v):
 *
 *   mini-qemu: [4s] board 2.7s (+1.4s), idle 0%: 31% svc mark_slice, 13% svc memmove, 12% svc sweep_slice, 8% usr (user)
 *
 * The line gives the host's time; the board's time (and how much it
 * advanced); the share of the board's time that the CPU waited; and
 * where the rest of the time went, the most first. The CPU waits at a
 * WFI, where the time is skipped to its next interrupt, when a kernel
 * waits for a device or for input. A sample is taken after each batch
 * (4096 instructions, or fewer when the batch ends at a WFI), and the
 * batch's instructions are charged to its last PC. That PC is named
 * from the kernel's symbols (-symbols ELF), unless it is a user
 * program's.
 *
 * A sample counts as many as the instructions of its batch, not as
 * one. An idle mini-xv6 tick is two batches: 830 instructions up to
 * its WFI, then 4096 in its scheduler's loop. Counting each sample as
 * one said "idle 48%" for a kernel that was idle 98% of its time.
 *
 * A kernel stuck in a loop shows the loop's function near 100%, line
 * after line. A kernel waiting forever for a device shows idle near
 * 100% (and "waiting at" the WFI's function). A kernel wedged with its
 * interrupts off shows idle 0% and always the same function. *)

(* a CPU after a batch: where it is, the instructions it ran since the
 * last sample, and the time it waited (asleep at a WFI), counted in
 * instructions *)
type cpu = { pc : int64; user : bool; label : string; ran : int; waited : int }

type t

(* [symbols] are (address, name) pairs, from Elf.symbols *)
val create : clock:(unit -> float) -> every:float -> symbols:(int64 * string) list -> t

(* [sample] is called after a batch, with the positions of its CPUs *)
val sample : t -> cpu list -> unit

(* [report] gives a line when [every] seconds have passed since the last
 * one; [now] is the board's time in microseconds *)
val report : t -> now:int -> string option
