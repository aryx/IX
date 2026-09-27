(* mini-qemu's -status N: every N seconds of the host's, a line on
 * standard error saying where the guest is, to see where a boot
 * blocks without a debugger (mini-pi -v):
 *
 *   mini-qemu: [4s] board 2.7s (+1.4s), idle 0%: 31% svc mark_slice, 13% svc memmove, 12% svc sweep_slice, 8% usr (user)
 *
 * the host's time; the board's time (and how much it advanced); the
 * share of the board's time the CPU waited (at a WFI: the time skipped
 * to its next interrupt; a kernel waiting for a device or for input);
 * and where the rest went, the most first. A sample is taken after
 * each batch (4096 instructions, less when it ends at a WFI), the
 * batch's instructions charged to its last PC, named from the
 * kernel's symbols (-symbols ELF) when not a user program's.
 *
 * claude: charged by instructions, not one per sample: an idle mini-xv6
 * tick is two batches, 830 instructions to its WFI then 4096 in its
 * scheduler's loop, so one per sample said "idle 48%" of a kernel
 * idle 98% of its time.
 *
 * A kernel stuck in a loop shows the loop's function near 100%, line
 * after line; one waiting forever for a device, idle near 100% (and
 * "waiting at" the WFI's function); one wedged with interrupts off,
 * idle 0% and always the same function. *)

(* a CPU after a batch: where it is, the instructions it ran since the
 * last sample, and the time it waited (at a WFI, asleep), in
 * instructions *)
type cpu = { pc : int64; user : bool; label : string; ran : int; waited : int }

type t

(* [symbols]: (address, name), from Elf.symbols *)
val create : every:float -> symbols:(int64 * string) list -> t

(* after a batch: its CPUs' positions *)
val sample : t -> cpu list -> unit

(* a line when [every] seconds have passed since the last one; [now]
 * the board's microseconds *)
val report : t -> now:int -> string option
