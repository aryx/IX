(* This is tiny-machine's machine, without a host. It is TinyMachineCPU's CPU
 * plus the control registers, the traps, the pages, the state of the
 * devices, and the passing of time, one instruction at a time
 * ([tick]). TinyMachine.mli's header describes the machine itself.
 *
 * Two programs are built around this module, each with its own loop,
 * console and window:
 * - TinyMachine.ml runs in a terminal (and shows the window through a
 *   separate program of the host);
 * - TinyMachineWeb.ml runs in a web page, drawing on a canvas, compiled
 *   by js_of_ocaml.
 * A host gives two functions, [put] and [on_open], plus a third one,
 * [send], when it has a network. Everything else it does by changing
 * the machine's state between two ticks (console_type, mouse_set,
 * net_give).
 *
 *     TinyMachine: a terminal, files,      TinyMachineWeb: a page, a
 *     a window by TinyMachineWindow        canvas, by js_of_ocaml
 *            \                               /
 *             put, on_open; console_type, mouse_set; tick
 *                            |
 *     this file: the control registers and [trap]; the window and
 *     the pages ([check], [translate]); the devices behind [load] and
 *     [store]; csrr, csrw, eret, csrrw, amoswap, wfi ([extra]); the
 *     interrupts between two instructions
 *                            |
 *             an env of five functions ([env]); step
 *                            |
 *     TinyMachineCPU: sixteen registers, a pc, the memory's bytes, and
 *     what each instruction means
 *
 * These layers are the hardware's own. A CPU core knows only registers
 * and memory. What an address means (a page, a device) and what a
 * privileged instruction does are decided around it. What a console or
 * a disk is in the real world is up to the host. Each layer can be read
 * without the one above it. mini-5i and mini-qemu, in m-ix, are cut
 * the same way (Cpu and Memory, then Board and its devices, then Main
 * and the SDL or web display).
 *
 * design:
 * A device here is a few words of memory and an interrupt bit, with no
 * bus, no FIFO and no timing: for example, the disk's transfer is done
 * by the very instruction that asks for it. So a driver is a few lines,
 * and it teaches the shape of all drivers (a command, a status, an
 * interrupt to say it is done) without a datasheet. The real devices,
 * with their datasheets, are mini-qemu's (Pl011, Sdhost, Dwc2). *)

(* [colours] holds the 256 colours, three bytes each (red, green, blue) *)
val memsize : int
val screen : int
val width : int
val height : int
val colours : string

(* [time] is the time register's index among the control registers. *)
val nearest : int -> int -> int -> int
val time : int

(* [rate] is the number of instructions per second. It is set before
 * [create], which puts it in the read-only register "rate", and
 * tiny-kernel uses it to make its tick 2.5 ms. A host with a window
 * holds the machine to it. The default, 8 million, is what
 * the web page keeps up with and what the sessions were recorded at. *)
val default_rate : int
val rate : int ref

(* Both are set before [create]. [date] is the date at boot, in seconds
 * since 2000-01-01 UTC; it is read at -56(r0) and comes from the host's
 * clock or from -date. [seed] is the seed of the random numbers; it is
 * read at -60(r0) and comes from -seed (with 0, the kernel uses its
 * clock). *)
val date : int ref
val seed : int ref

(* The number of cores (-cores), set before [create]. The devices are
 * wired to core 0; the others reach only -64(r0), the interrupt between
 * cores. *)
val cores : int ref

(* Trap (cause, tval) stays inside the machine; Halt ends [ticks]. *)
exception Trap of int * int
exception Halt of int

type console = {
  mutable queue : string; mutable next : int; mutable eof : bool;
  mutable opened : bool; mutable eof_read : bool;
}
(* There are two disks of 1 KB blocks, with their registers at -32(r0)
 * and -80(r0). [wrote] is given each block that is written, so that the
 * host can save it. *)
val bsize : int
type disk = {
  image : Bytes.t; mutable block : int; mutable addr : int;
  mutable done_ : bool; mutable wrote : int -> unit;
}
(* [cursor] is set by a program and shown by the host: 0 is the arrow,
 * and 1 is a hand over a link. [moved] says that the word changed since
 * it was last read. *)
type mouse = { mutable at : int; mutable moved : bool; mutable cursor : int }
type net
(* [ring_at] is 0 when the speaker is off; [since] is the time of the
 * last sample *)
type speaker = {
  mutable ring_at : int; mutable played : int; mutable since : int;
}

type machine = {
  cpu : TinyMachineCPU.machine; csr : int array; cons : console;
  disks : disk array;
  mouse : mouse; net : net; speaker : speaker;
  mutable events : (int * string) list;
  put : char -> unit; on_open : console -> unit; send : string -> unit;
  hear : string -> unit;
  mutable touched : bool;
  (* the core sleeps after a wfi, until an interrupt enabled in ie is
   * pending *)
  mutable waiting : bool;
  ipis : int Atomic.t array;
  (* the instructions run in user mode and in the kernel, and the ones
   * spent idle after a wfi *)
  spent : int array;
  (* the translations of user pages: the low bits of a page number pick
   * a slot, which holds the number (-1 for none) and its entry. They
   * are emptied when satp is written. *)
  tlb_tag : int array; tlb_pte : int array;
}

(* A machine with an image at 0. [on_open] is called when a kernel first
 * reads the console. With [events], a session's keys are the console's
 * only input, and its last event ends the input. *)
val create :
  put:(char -> unit) -> on_open:(console -> unit) ->
  send:(string -> unit) option -> hear:(string -> unit) ->
  disks:Bytes.t list -> events:(int * string) list option -> string ->
  machine

(* The speaker plays a ring of [ring] signed bytes, [hz] a second.
 * [speaker_hear] gives [hear] the samples due; a host that listens must
 * call it at least once per ring. *)
val ring : int
val hz : int
val speaker_hear : machine -> unit

(* [core m k] is core k (0 < k < !cores) of m, which is core 0. It has
 * its own registers and its pc at 0, and it shares the rest with m. *)
val core : machine -> int -> machine

val env : machine -> TinyMachineCPU.env

(* For -prof, the window's base tells which program runs. [ticks] runs
 * the given number of instructions. *)
val supervisor : machine -> bool
val window_base : machine -> int
val ticks : machine -> TinyMachineCPU.env -> int -> unit

(* These are what a host does between two [ticks]. An empty packet does
 * not reach the kernel: at its time it comes back to [send], and so it
 * serves as the clock of the other end. *)
val console_type : console -> string -> unit
val mouse_set : mouse -> int -> int -> int -> unit
val net_give : machine -> after:int -> string -> unit

(* A recorded session is made of timed lines, "m x y buttons" or
 * "k text". *)
val timed_events : string -> (int * string) list
val event : mouse -> console -> string -> unit

(* [show] lists the instructions added to the CPU (csrr, eret, wfi...),
 * naming the control registers (TinyLibMachine.csr_names) *)
val show : int -> string option
