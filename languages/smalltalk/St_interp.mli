(* St_interp: the Blue Book's interpreter (chapters 27 to 29).

   The machine's registers are the active context and what is cached
   from it: its method, the instruction pointer (ip), the stack
   pointer (sp), the receiver, the temporaries' home. Each cycle
   fetches a bytecode, decodes it and executes it (St_bytecode.mli).

   **Contexts are objects**, in the object memory like any other:

     MethodContext  0 sender  1 ip  2 sp  3 method  4 closure  5 receiver
                    6... the arguments, the temporaries, then the stack
     BlockContext   0 caller  1 ip  2 sp  3 argument count
                    4 initial ip  5 home  6... the stack

   With closures (Squeak's, St_compile.mli) there is no BlockContext:
   a block is a BlockClosure, not a context,

     BlockClosure   0 outerContext  1 startpc  2 numArgs
                    3... the values it copied when it was made

   and each "value" makes a new MethodContext for it, field 4 naming
   the closure, the receiver its outer context's, the temporaries its
   arguments then its copied values. Its home, where "^" returns from,
   is found up the closures' outer contexts.

   A send makes a new MethodContext whose sender is the active one;
   a return makes the sender active again. So the stack of calls is a
   linked list of objects, "thisContext" is one of them, and the
   debugger only has to read their fields (St_debug.mli).

   **A send**: the receiver's class, the selector, looked up up the
   superclass chain (through a cache of 1024 entries, the Blue Book's
   method cache: most sends hit it). If the method names a primitive,
   the primitive runs first (St_primitives.mli), and the method's own
   code only when it fails. The arithmetic special selectors on two
   SmallIntegers do not even look up: the bytecode does the sum. A
   selector not found sends #doesNotUnderstand: with a Message instead.

   **Returns**: "^" returns from the block's *home* method to the
   home's sender, however many contexts sit in between (a non-local
   return): "detect:" is written with it. If the home has already
   returned, #cannotReturn: is sent instead. A returned context is
   marked by a nil sender and a nil ip.

   **Contexts recycled.** A context for every send is the price of
   contexts being objects, and most are garbage as soon as they return:
   nobody ever looked at them (Deutsch and Schiffman, 1984, built their
   fast Smalltalk on it; the Blue Book's memory, counting references,
   knew at once which could be used again). Here an
   object's entry in the table has a bit, *escaped*, set when a context
   is handed to the program -- thisContext, a block made (its home, a
   closure's outer context), its sender read, the debugger looking at
   its process. A context that returns with the bit clear goes into a
   pool, by size, and the next send of that size takes it from there
   instead of allocating. A method that makes no block is recycled; one
   that does is not.

   **Processes**: a process is a chain of contexts not running. The
   host runs one at a time, for a budget of bytecodes, so that an
   endless loop never freezes the screen; a process ends when its
   bottom context returns, or is suspended: an error (Object>>error:,
   halt), a condition the debugger set, or the host itself (the user's
   interrupt). A suspended process is resumed from where it stopped.

   The collector (St_memory.mli) runs between two bytecodes, when
   enough has been allocated since the last time.

   A send, "3 factorial", drawn:

     the stack: ... 3         a bytecode of 208-223: send the literal
          |                   #factorial, with no argument
          |
     the receiver's class: SmallInteger       (St_memory.class_of)
          |
     the cache: h = (class xor (selector << 3)) >> 1, on 10 bits
          |   entry h has (SmallInteger, #factorial)? its method: a hit
          |   no: SmallInteger's dictionary, then its superclasses',
          |       found in Integer (St_class.lookup); the entry h is
          |       (SmallInteger, #factorial, that method) now: a miss
     the method's header: a primitive? run it; done if it succeeds
          |
     a new MethodContext: its sender the active one, its receiver 3,
     the arguments moved from the caller's stack; it is the active one

   One entry a slot: two sends that fall on the same h take it from
   each other. A method added or removed anywhere empties the whole
   cache ([flush_cache]): which entries a new method makes wrong is
   not worth finding.

   Where it stands: the middle of the virtual machine. St_boot and
   St_image make a vm; a host (CLI, Squeak) spawns processes and runs
   them a budget at a time; St_primitives fills the table that a
   method's header points into; St_debug reads what a stopped process
   left. The budget is the same device as Scheme_eval's fuel, for the
   same reason: one thread, and a screen to keep alive.

   terminology:
   A *message* is a selector and arguments, what is sent; a *method*
   is the code a class answers it with; the *send* is the search
   from one to the other, made when the program runs and on the
   receiver alone. "Late binding" is that search; a "virtual call"
   in C++ or Java is the same thing with the search done by the
   compiler, an index in a table left for the run.

   cs-history:
   The cache of the Blue Book is one table for the whole system.
   Peter Deutsch and Allan Schiffman (1984) put the cache in the
   code: at each place a send is written, remember the class seen
   last and the method found, and next time compare one word and
   jump -- the *inline cache*, on the remark that at a given place
   the receiver's class is nearly always the same. Their system
   also turned bytecodes into machine code the first time a method
   ran, and kept contexts as plain frames of the machine's stack,
   made objects only when the program looked at one: the escaped bit
   above is that last idea, in a small way. Self added the inline
   cache of several classes (Holzle, Chambers and Ungar, 1991). A
   JavaScript engine's property access goes through the same caches
   today.

   road-not-taken:
   Contexts as objects made the debugger and the processes, and
   later the exceptions, things written in Smalltalk with nothing
   asked of the machine, and cost every send an allocation. The fast
   Smalltalks since all keep a stack and pretend, and most later
   languages have kept the stack and not pretended: a frame cannot
   be held, read or restarted by the program. Scheme's call/cc is the other language
   that gives the program its own stack as a value (Scheme_eval.mli,
   where it is data for the same reason and at the same price).

   References: the Blue Book, chapter 27 (contexts, classes and
   methods as the machine sees them), chapter 28 (the interpreter,
   in Smalltalk: sendSelector:, lookupMethodInClass:, the method
   cache). L. Peter Deutsch and Allan Schiffman,
   "Efficient Implementation of the Smalltalk-80 System" (POPL
   1984). Urs Holzle, Craig Chambers and David Ungar, "Optimizing
   Dynamically-Typed Object-Oriented Languages With Polymorphic
   Inline Caches" (ECOOP 1991). Eliot Miranda, "Context Management
   in VisualWorks 5i" (1999), on keeping a stack and giving contexts
   (from memory). *)

type oop = St_memory.oop

(* what the virtual machine asks of the world *)
type host = {
  transcript : string -> unit; (* the Transcript shows *)
  milliseconds : unit -> int; (* a clock *)
  inspect : oop -> unit; (* anObject inspect: an Inspector to open *)
  (* where the mouse is on the Display, and its buttons: 4 red (the
   * left), 2 yellow (the middle), 1 blue (the right), as Smalltalk-80
   * named them *)
  mouse : unit -> int * int * int;
  (* the next character typed, taken out of the keys waiting: its code
   * (13 return, 8 backspace, 28 to 31 the arrows left, right, up and
   * down, as Squeak has them), None when there is none *)
  keyboard : unit -> int option;
}

type process_state =
  | Runnable
  | Suspended of string (* why: "Message not understood: foo", "Halt", "Step" *)
  | Finished of oop (* the bottom context returned this *)
  | Terminated

type process = {
  id : int;
  mutable top : oop; (* the context to run next, when not running *)
  mutable state : process_state;
}

type vm

(* a primitive: the vm, the number of arguments; on success it has
 * replaced the receiver and the arguments on the stack by its result *)
type primitive = vm -> int -> bool

val create : St_memory.t -> host -> vm
val memory : vm -> St_memory.t
val host : vm -> host
val set_host : vm -> host -> unit

(* the primitives, filled by St_primitives.install *)
val primitives : vm -> primitive option array

(* what the host holds, kept alive by the collector *)
val set_extra_roots : vm -> (unit -> oop list) -> unit

(*****************************************************************************)
(* Processes *)
(*****************************************************************************)

(* a new process sending [selector] to [receiver] with [args] *)
val spawn : vm -> oop -> string -> oop list -> process

(* a new process running a compiled DoIt with this receiver *)
val spawn_method : vm -> oop -> oop -> process

(* run a process for at most [budget] bytecodes; with [stop_when], it
 * is suspended with "Step" before a bytecode where the condition
 * holds (the first one excepted) *)
val run : vm -> process -> budget:int -> unit

(* the same, stopped before each bytecode after the first when the
 * condition holds ("Step"): a debugger's *)
val run_until : (vm -> bool) -> vm -> process -> budget:int -> unit

(* resume a suspended process: it becomes runnable where it stopped *)
val resume : process -> unit
val suspend : process -> string -> unit

(* ended for good, and forgotten: its contexts are garbage now *)
val terminate : vm -> process -> unit

(* spawn and run to the end, for the host and the tests: the answer,
 * or why it stopped *)
(* the bytecodes a call or an evaluation may run when nothing else is said *)
val default_budget : int

val call : vm -> budget:int -> oop -> string -> oop list -> (oop, string) result

(* [call ... "printString"], as an OCaml string *)
val print_string : vm -> oop -> string

(* evaluate a Workspace's text with a receiver, to the end *)
val evaluate : vm -> string -> (oop, string) result

(* the same with its budget and with self ([evaluate]: default_budget, nil) *)
val evaluate_with : vm -> budget:int -> receiver:oop -> string -> (oop, string) result

(*****************************************************************************)
(* For the primitives *)
(*****************************************************************************)

val stack : vm -> int -> oop (* 0 the top, 1 under it... *)
val pop : vm -> int -> unit
val push : vm -> oop -> unit
val bool : vm -> bool -> oop

(* a send from a primitive (perform:), the receiver and the arguments
 * on the stack *)
val send : vm -> oop -> int -> unit

(* the context blockCopy: was sent from, the instruction pointer *)
val active_context : vm -> oop
val ip : vm -> int
val home_context : vm -> oop

(* a MethodContext of this many fields, recycled or new, its fixed
 * fields and its first [temps] temporaries nil *)
val new_context : vm -> int -> temps:int -> oop

(* an object handed to the program that may be a context: if it is, it
 * will not be recycled *)
val escape : vm -> oop -> unit

(* make a context active (a block's value), saving the current one *)
val activate_context : vm -> oop -> unit

(* ask the run loop to suspend the process after this bytecode *)
val request_suspend : vm -> string -> unit

(* a garbage collection now, the registers saved first *)
val collect : vm -> unit

(* after a method is added or removed *)
val flush_cache : vm -> unit

(* the method cache's hits and misses since it was created *)
val cache_stats : vm -> int * int

(* bytecodes executed since it was created *)
val bytecodes_run : vm -> int

(* a context's field numbers *)
val c_sender : int
val c_ip : int
val c_sp : int
val c_method : int
val c_closure : int
val c_receiver : int
val c_home : int
val c_temps : int

(* for the debugger: whether a context is a block's, its method, its
 * home, its receiver *)
val is_block_context : vm -> oop -> bool
val is_closure_context : vm -> oop -> bool (* a closure's activation *)
val context_method : vm -> oop -> oop
val context_home : vm -> oop -> oop
