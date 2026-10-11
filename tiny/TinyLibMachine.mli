(* tiny-machine's machine, without a host: TinyLibCPU's CPU with the
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
 *     [store]; csrr, csrw, eret, csrrw, amoswap ([extra]); the
 *     interrupts between two instructions
 *                            |
 *             an env of five functions ([env]); step
 *                            |
 *     TinyLibCPU: sixteen registers, a pc, the memory's bytes, and
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
 * 256 colours (three bytes each: red, green, blue); the machine's
 * speed when a person watches, in instructions a second; the index of
 * the time among the registers of control *)
val memsize : int
val screen : int
val width : int
val height : int
val colours : string
val rate : float
val time : int

(* a trap (its cause, what goes with it), inside the machine; the halt
 * and its status, which ends [ticks] *)
exception Trap of int * int
exception Halt of int

(* the devices' state, a host's to look at and to feed: the console's
 * input, the disk, the mouse, the network *)
type console = { mutable queue : string; mutable next : int; mutable eof : bool; mutable opened : bool; mutable eof_read : bool }
type disk = { image : Bytes.t; mutable block : int; mutable addr : int; mutable done_ : bool; mutable dirty : bool }
type mouse = { mutable at : int; mutable moved : bool }
type net

type machine = {
  cpu : TinyLibCPU.machine; csr : int array; cons : console; disk : disk; mouse : mouse; net : net; mutable events : (int * string) list;
  put : char -> unit; on_open : console -> unit; send : string -> unit;
  mutable touched : bool;
}

(* A machine with an image at 0. [put] has each byte of the console's
 * output, [on_open] is called when a kernel first asks for its input,
 * [send], when there is a network, has each packet sent; a disk's
 * image, a session's events *)
val create :
  put:(char -> unit) -> on_open:(console -> unit) -> send:(string -> unit) option -> disk:Bytes.t -> events:(int * string) list option ->
  string -> machine

(* the CPU's five hooks for it, and so many instructions of its time
 * (Halt when the kernel halts it) *)
val env : machine -> TinyLibCPU.env
val ticks : machine -> TinyLibCPU.env -> int -> unit

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

(* the assembler's extension: csrr, csrw, eret, csrrw, amoswap *)
val ext : TinyLibCPU.extension
