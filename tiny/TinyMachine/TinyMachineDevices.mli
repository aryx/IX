(* tiny-machine's machine, without a host: TinyMachineCPU's CPU with the
 * registers of control, the traps, the pages, the devices' state, and
 * one instruction of its time ([tick]). TinyMachine.mli's header says
 * what the machine is. Two programs are around it, each with its
 * loop, its console and its window: TinyMachine.ml, a terminal's (and
 * a window of the host's, another program), and TinyMachineWeb.ml, a
 * page's (a canvas), by js_of_ocaml. What a host gives is two
 * functions, [put] and [on_open], and a third when it has a network,
 * [send]; the rest it does to the machine's state between two ticks
 * (console_type, mouse_set, net_give).
 *
 *     TinyMachine: a terminal, files,      TinyMachineWeb: a page, a
 *     a window by TinyMachineWindow        canvas, by js_of_ocaml
 *            \                               /
 *             put, on_open; console_type, mouse_set; tick
 *                            |
 *     this file: the registers of control and [trap]; the window and
 *     the pages ([check], [translate]); the devices behind [load] and
 *     [store]; csrr, csrw, eret, csrrw, amoswap, wfi ([extra]); the
 *     interrupts between two instructions
 *                            |
 *             an env of five functions ([env]); step
 *                            |
 *     TinyMachineCPU: sixteen registers, a pc, the memory's bytes, and
 *     an instruction's meaning
 *
 * The layers are the hardware's own: a CPU's core knows registers and
 * memory; what an address means (a page, a device) and what an
 * instruction of privilege does are decided around it; and what is a
 * console or a disk in the world is the host's. Each can be read
 * without the one above. mini-5i and mini-qemu, in m-ix, are cut the
 * same way (Cpu and Memory, then Board and its devices, then Main and
 * the SDL or the web display).
 *
 * design:
 * A device here is a few words of memory and an interrupt's bit,
 * with no bus, no FIFO and no timing: the disk's transfer is done by
 * the instruction that asks for it. So a driver is a few lines and
 * teaches the shape (a command, a status, an interrupt to say done)
 * without a datasheet. The real ones, with their datasheets, are
 * mini-qemu's (Pl011, Sdhost, Dwc2). *)

(* the memory's size; the screen's address and its size in pixels, its
 * 256 colours (three bytes each: red, green, blue); the index of the
 * time among the registers of control *)
val memsize : int
val screen : int
val width : int
val height : int
val colours : string

(* the colour nearest to a red, green and blue (bytes) *)
val nearest : int -> int -> int -> int
val time : int

(* The machine's speed, in instructions per second. A host sets [rate]
 * before [create], which puts it in the machine's read-only register
 * "rate"; tiny-kernel reads it to make its tick 2.5 ms long. A host
 * with a window or a page also holds the machine to that speed. The
 * default, 8 million, is what the web page keeps up with and what the
 * recorded sessions were made at. *)
val default_rate : int
val rate : int ref

(* the date at the boot, in seconds since 2000-01-01 UTC, which the
 * kernel reads at -56(r0): set by a host before [create] (the host's
 * clock, or tiny-machine's -date) *)
val date : int ref

(* the seed, read at -60(r0), for the programs' first random numbers;
 * 0 for none (the kernel gives its clock): tiny-machine's -seed *)
val seed : int ref

(* the number of cores, set by a host before [create] (tiny-machine's
 * -cores): 1 by default, the machine as it was. A core is a machine of
 * its own ([core]) sharing the memory and the devices; the devices are
 * core 0's, the others reach only -64(r0), the interrupt between cores
 * (the .ml says how) *)
val cores : int ref

(* a trap (its cause, what goes with it), inside the machine; the halt
 * and its status, which ends [ticks] *)
exception Trap of int * int
exception Halt of int

(* the devices' state, a host's to look at and to feed: the console's
 * input, the disk, the mouse, the network *)
type console = {
  mutable queue : string; mutable next : int; mutable eof : bool;
  mutable opened : bool; mutable eof_read : bool;
}
(* the disk's block, 1 KB; [wrote], told of each block written (its
 * number), the host's to keep it *)
val bsize : int
type disk = {
  image : Bytes.t; mutable block : int; mutable addr : int;
  mutable done_ : bool; mutable wrote : int -> unit;
}
(* the mouse: its word, whether it changed since it was read, and the
 * look a program asked for by writing that word (0 the arrow, 1 a hand
 * over a link), which the host shows *)
type mouse = { mutable at : int; mutable moved : bool; mutable cursor : int }
type net
(* the speaker: its ring's address (0: off), the samples played, the
 * time of the last *)
type speaker = {
  mutable ring_at : int; mutable played : int; mutable since : int;
}

type machine = {
  cpu : TinyMachineCPU.machine; csr : int array; cons : console; disk : disk;
  mouse : mouse; net : net; speaker : speaker;
  mutable events : (int * string) list;
  put : char -> unit; on_open : console -> unit; send : string -> unit;
  hear : string -> unit;
  mutable touched : bool;
  (* asleep since a wfi, until an interrupt of ie's is pending *)
  mutable waiting : bool;
  ipis : int Atomic.t array;
  (* the instructions this core ran: in user mode, in the kernel, the
   * kernel idle (asleep after a wfi), counted by [ticks] *)
  spent : int array;
  (* the translations' cache, user mode's pages: a page's number (-1:
   * none) and its entry, in the slot of its number's low bits; emptied
   * when satp is written *)
  tlb_tag : int array; tlb_pte : int array;
}

(* A machine with an image at 0. [put] has each byte of the console's
 * output, [on_open] is called when a kernel first asks for its input,
 * [send], when there is a network, has each packet sent, [hear] the
 * speaker's samples, played; a disk's image, a session's events *)
val create :
  put:(char -> unit) -> on_open:(console -> unit) ->
  send:(string -> unit) option -> hear:(string -> unit) ->
  disk:Bytes.t -> events:(int * string) list option -> string -> machine

(* The speaker: a ring of [ring] samples in memory (a byte each, signed),
 * played at [hz] a second; [speaker_hear] gives [hear] the samples due
 * since the last look (the kernel's, or the host's: a host listening
 * looks often, at least once a ring) *)
val ring : int
val hz : int
val speaker_hear : machine -> unit

(* core k (0 < k < !cores) of the machine made by [create], which is
 * core 0: its own registers and registers of control, its pc at 0 *)
val core : machine -> int -> machine

(* the CPU's five hooks for it, and so many instructions of its time
 * (Halt when the kernel halts it) *)
val env : machine -> TinyMachineCPU.env

(* whether the CPU is in supervisor mode (the kernel's); the base of the
 * user's window (which program's partition): a profile's (-prof) *)
val supervisor : machine -> bool
val window_base : machine -> int
val ticks : machine -> TinyMachineCPU.env -> int -> unit

(* what a host does to it between two calls of ticks: bytes typed, the
 * mouse at a place with its buttons, a packet that lands so many
 * instructions from now (an empty one does not reach the kernel: it
 * comes back to [send] then, the other end's clock) *)
val console_type : console -> string -> unit
val mouse_set : mouse -> int -> int -> int -> unit
val net_give : machine -> after:int -> string -> unit

(* a session: a file's lines, each with its time; one of them done
 * ("m x y buttons", "k text") *)
val timed_events : string -> (int * string) list
val event : mouse -> console -> string -> unit

(* the listing of the machine's own instructions, csrr, csrw, eret,
 * csrrw, amoswap, wfi (tiny-assembler makes them; the registers of control
 * by their names, TinyMachineISA.csr_names) *)
val show : int -> string option
