(* Squeak, run over a host: the system brought up (Squeak's kernel, or
 * MiniMorphic's), its world made and what is on the screen at the
 * start, then the world's cycle, again and again. A host is what the
 * machine asks of what is under it (St_interp.host: the mouse, the
 * keys, a clock, the Transcript), and shows the Display; the three of
 * them call this module and nothing else: a window on Linux
 * (hosts/sdl), a window of mini-rio, the bare Pi (kernel/squeak).
 * docs/plans/plan_system_squeak.md.
 *
 * After the playground's TinySqueak, whose start this is. *)

type system =
  | Squeak (* in colour: Morphic, the Browser, a Workspace, the Transcript, the atoms, the car *)
  | Mini (* MiniMorphic: fifty squares bouncing, black and white *)

(* the Display's size, which the start's windows are placed for *)
val width : int
val height : int

type t

(* brought up from the kernel's text; what the start cannot do is said
 * by the host's Transcript *)
val start : system -> St_interp.host -> t

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
