(* Squeak, run over a host: the system brought up (Squeak's kernel, or
 * MiniMorphic's), its world made and what is on the screen at the
 * start, then the world's cycle, again and again. A host is what the
 * machine asks of what is under it (St_interp.host: the mouse, the
 * keys, a clock, the Transcript), and shows the Display; the three of
 * them call this module and nothing else: a window on Linux
 * (hosts/sdl), a window of mini-rio, the bare Pi (kernels/squeak).
 * docs/plans/plan_system_squeak.md.
 *
 * After the playground's TinySqueak, whose start this is.
 *
 *     the host, a frame                       Smalltalk
 *     mouse, keys ----------> St_interp.host: primitives 90 to 92
 *     cycle  ---------------> World doOneCycle: the hand's events to
 *        (a budget of           the morphs, each morph's step, the
 *         bytecodes)            damaged rectangles drawn again
 *                                    | copyBits (St_colorblt)
 *     picture, or bits32 <--- the Display, a Form of 32 bits
 *
 * Mini-smalltalk's Blue Book system has its text and its classes, and
 * no window of its own. Here everything on the screen is Smalltalk:
 * the windows, the Browser, the menus, the text typed in, the atoms
 * that bounce are morphs, drawn by Smalltalk with BitBlt on the
 * Display. The Browser opens on EllipseMorph>>drawOn:, what draws the
 * bouncing atoms: change it, accept (the yellow button's menu), and
 * they are drawn the new way at once, while they bounce. Do the same
 * to BorderedMorph>>drawOn: and it is the windows, the Browser's own
 * among them.
 *
 * So the host is small, and that is Squeak's lesson, its paper's
 * title: a Smalltalk written in itself, where what the machine must
 * provide keeps shrinking. A host gives the mouse and the keys, calls
 * [cycle] once a frame, and shows the Display.
 *
 * cs-history:
 * Squeak (Dan Ingalls, Ted Kaehler, John Maloney, Scott Wallace and
 * Alan Kay, at Apple then Disney, 1996) is Smalltalk-80 made live
 * again by some of those who made it, sixteen years on: they started
 * from Apple's Smalltalk-80 image and the Blue Book, and wrote the
 * virtual machine in a subset of Smalltalk that they ran and debugged
 * in Smalltalk, then translated to C. It is free, and Pharo (2008) is
 * a fork of it. Here the virtual machine stays OCaml.
 *
 * cs-history:
 * Morphic is not Smalltalk-80's way of windows, which was
 * Model-View-Controller (Trygve Reenskaug at PARC, 1979): a model, a
 * view that draws it, a controller that reads the mouse for it, three
 * objects for each thing on the screen. Morphic came from Self (John
 * Maloney and Randall Smith, 1995), and Maloney brought it to Squeak:
 * one object, the morph, draws itself, takes the mouse, holds other
 * morphs, and steps in time. Etoys (the car and its script of tiles)
 * is the children's programming built on it; Scratch, whose first
 * versions were written in Squeak with Maloney, came from there.
 *
 * reframe:
 * A host is a kernel's worth of services, and a short one: a screen
 * of pixels, a mouse, keys, a clock. On the bare Pi (kernels/squeak)
 * there is nothing else under Smalltalk, which is how it ran on the
 * Alto: Smalltalk was the machine's system, not a program of it.
 * Ingalls, in Byte (1981): "An operating system is a collection of
 * things that don't fit into a language. There shouldn't be one."
 * (quoted from memory). Processes, files and a network are what this
 * one does not have to make the sentence true.
 *
 * References: Dan Ingalls, Ted Kaehler, John Maloney, Scott Wallace
 * and Alan Kay, "Back to the Future: The Story of Squeak, A Practical
 * Smalltalk Written in Itself" (OOPSLA 1997): the paper to read, on
 * the virtual machine in Smalltalk and on BitBlt in colour. John
 * Maloney and Randall Smith, "Directness and Liveness in the Morphic
 * User Interface Construction Environment" (UIST 1995). kernel/
 * morphic/MiniMorphic.st, Morphic in one file, before kernel/squeak's. *)

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
