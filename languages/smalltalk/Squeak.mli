(* Squeak, run over a host: the system brought up (Squeak's kernel, or
 * MiniMorphic's), its world made and what is on the screen at the
 * start, then the world's cycle, again and again. A host is what the
 * machine asks of what is under it (St_interp.host: the mouse, the
 * keys, a clock, the Transcript), and shows the Display; the three of
 * them call this module and nothing else: a window on Linux
 * (hosts/sdl), a window of mini-rio, the bare Pi (kernels/squeak).
 * docs/plans/plan_system_squeak.md.
 *
 * After the playground's TinySqueak, whose start this is. *)

type system =
  | Squeak (* in colour: Morphic, the Browser, a Workspace, the Transcript, the atoms, the car *)
  | Quiet (* Squeak's, with nothing that moves by itself: no atoms, the car's script not ticking. A pass
             of the world then costs hundreds of bytecodes, not tens of thousands: for a slow machine *)
  | Mini (* MiniMorphic: fifty squares bouncing, black and white *)

(* the Display's size, which the start's windows are placed for *)
val width : int
val height : int

type t

(* brought up from the kernel's text; what the start cannot do is said
 * by the host's Transcript *)
val start : system -> St_interp.host -> t

(* the same on a Display of another size (a window of mini-rio's: what
 * the window is): the start's windows placed and sized in proportion.
 * MiniMorphic's Display is the Blue Book's, whatever is asked. *)
val start_sized : system -> St_interp.host -> int * int -> t

(* started again from an image (St_image.save's) of a system that
 * [start] brought up: no text compiled, the world as it was saved *)
val resume : St_interp.host -> string -> t

val vm : t -> St_interp.vm

(* the world's cycle, run for a frame's budget of bytecodes: a cycle
 * that did not end goes on at the next call, and one that stopped on
 * an error is said in Smalltalk's Transcript and forgotten: the world
 * goes on. [interrupt]: a cycle still running is stopped (Control-C). *)
val cycle : t -> interrupt:bool -> unit

(* the Display, when it was drawn on since it was last asked: its
 * width, its height, and its pixels, four bytes each (red, green,
 * blue, alpha), row after row *)
val picture : t -> (int * int * Bytes.t) option

(* the same in two steps, for a host that can show the Display's own
 * bytes and spare the copy (the bare Pi: a pixel of [picture] is a
 * thousand of mini-ml's instructions): whether it was drawn on since
 * this was last asked; then its pixels as [picture]'s, or as they are
 * (St_colorblt.bits32: Squeak's Display, not MiniMorphic's) *)
val changed : t -> bool
val pixels : t -> (int * int * Bytes.t) option
val bits32 : t -> (int * int * int * Bytes.t) option
