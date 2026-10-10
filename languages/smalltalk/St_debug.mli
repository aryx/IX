(* St_debug: what a debugger asks of a suspended process.

   Nothing here stops a process: Smalltalk code does, with error: or
   halt (the primitive 141, St_primitives.mli), and the host does, with
   the user's interrupt. A stopped process's contexts are objects in
   the memory (St_interp.mli), so the debugger only reads them: the
   stack is the chain of senders from the process's top context; a
   frame's method is the context's, the send in progress is found in
   the method's pc map from the context's instruction pointer; its
   variables are the home context's fields, named by the compiler
   (St_bytecode.temp_names).

   Moving on is running the process again, under a condition checked
   before each bytecode (St_interp.run's stop_when):

   - step: the selected context's next send done, whatever it calls,
     then stop before the one after, or where it returned to;
   - send (step into): stop in the method or the block the next send
     enters;
   - restart: the context's method from its start, the contexts above
     it dropped -- the method taken afresh from its class, so that one
     fixed in the debugger runs fixed; a context too small for the new
     method is replaced by a bigger one with become: (St_memory.mli);
   - proceed: run on, where it stopped.

   The classic session (the tests'): a message not understood, the
   missing method defined in its class, the frame that sent it
   restarted, and the program finishes as if it had always been
   there.

     10 fib + 1         Suspended "Message not understood: fib"
       [frames]         SmallInteger(Object)>>doesNotUnderstand:
                        UndefinedObject>>DoIt
       [not_understood] SmallInteger, "fib", and DoIt's context
     fib self < 2 ifTrue: [^self]. ^(self - 1) fib + (self - 2) fib
                        compiled into Integer; the method cache flushed
       [restart] DoIt's context, [proceed], run:   Finished 56

   reframe:
   A debugger elsewhere is a second program that the kernel lets read
   a first one's memory (Unix's ptrace, Plan 9's /proc), and that
   needs tables left by the compiler to find, in a
   stack of bytes, where a frame starts and what its words are. Here
   there is nothing to find: a frame is an object with named fields,
   in the same memory as the debugger, which is 200 lines. What the
   compiler leaves is the pc map and the temporaries' names
   (St_bytecode's trailer), the two things the bytecodes forgot.

   cs-history:
   Fixing a program where it stopped and going on is older than
   Smalltalk: the Lisp systems of the 1960s and 1970s broke into a
   read-eval-print loop inside the failed call, and Interlisp let one
   edit the function there and try again. What Smalltalk-80 added is
   the picture every debugger has had since: the stack as a list to
   click in, the method's text with the place marked, the variables
   in panes beside it.

   modern:
   Restart is what "edit and continue" and "drop frame" are in
   today's debuggers of compiled languages, where they are hard and
   partial: a frame of machine code was laid out for the old
   method. Here the old context is only data for the old bytecodes,
   and a new one is made.

   References: the Blue Book, chapter 17, "The Programming
   Interface" (the notifier and the debugger, used) and chapter 27
   (contexts). Adele Goldberg, "Smalltalk-80: The Interactive
   Programming Environment" (Addison-Wesley, 1984), the Orange Book:
   the debugger's manual. *)

type oop = St_memory.oop

type frame = {
  ctx : oop;
  label : string; (* "SmallInteger(Integer)>>factorial", "[] in UndefinedObject>>DoIt" *)
  source : string; (* the method's *)
  highlight : (int * int) option; (* the send in progress, in the source *)
}

(* the process's contexts, the top first; with [~stepping], the top's
 * highlight is the send it is about to make, else the one it made *)
val frames : stepping:bool -> St_interp.vm -> St_interp.process -> frame list

val label : St_interp.vm -> oop -> string

(* "self" and the temporaries of the context's home, by name *)
val variables : St_interp.vm -> oop -> (string * oop) list

(* an object's fields, as an inspector lists them: the named ones by
 * name, then the indexed ones by index (the first 200) -- a String's
 * as Characters, a large integer's as SmallIntegers *)
val fields : St_interp.vm -> oop -> (string * oop) list

val step : St_interp.vm -> St_interp.process -> oop -> unit
val step_into : St_interp.vm -> St_interp.process -> oop -> unit

(* false when the context cannot be restarted (it has returned) *)
val restart : St_interp.vm -> St_interp.process -> oop -> bool
val proceed : St_interp.process -> unit

(* when the process stopped on a message not understood: the receiver's
 * class, the selector, and the frame that sent it *)
val not_understood : St_interp.vm -> St_interp.process -> (oop * string * oop) option

(* a method's text to start from, "fib: n" and a line saying to write
 * it, for a selector not understood *)
val template : string -> string
