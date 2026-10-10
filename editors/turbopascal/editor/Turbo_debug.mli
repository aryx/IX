(* Turbo_debug: the text compiled and its program run, stepped and
   paused: what made Turbo Pascal an environment and not an editor. The
   compiler is Pascal_compile, in one pass to P-code; the machine is
   Pmachine, which can be paused; the steps are Pdebug's.

   A program started is a session (Turbo_model.session). It is not run
   to its end in one call: [advance] drives its machine a slice a frame
   towards the session's goal (the next line, the cursor's line, a
   breakpoint, the end), so that the IDE stays alive, Ctrl-C can break
   a loop, and a readln waits for keys. When the goal is reached the
   session is paused, the execution bar on the line to run next.

   The program's screen (the user screen) is shown only while the
   program writes or reads, Turbo's "smart" screen swapping: a step
   that prints nothing doesn't flash it.

       Ctrl-F9                go m (Continue [ 7 ]), a breakpoint on
                              line 7: compiled, a session made, that
                              its goal
       a tick                 advance: the machine a slice towards it
       a tick                 ... line 7: the goal None, paused, the
                              bar on that line
       F8                     go m Step_over: the goal the next line
                              of this call or of its callers
       a tick                 advance: reached, paused again

   design:
   A program run inside the program that shows it must give the
   screen and the keys back. A thread or a process for it is one way;
   here it is a machine that can stop after any instruction and go on
   later, because all it is, the stack included, is data (Pmachine),
   and a count of instructions a tick. Stepping is then the same
   mechanism with another place to stop: no trap, no second program
   watching the first. mini-drscheme runs its Scheme so (its fuel),
   and a kernel's scheduler is the same idea with a clock in the
   counter's place. *)

open Turbo_model

(* Compiling *)

(* the text compiled: its code, kept in the model while the text is
   unchanged; or the model with the red bar saying the first error and
   the cursor on it *)
val compile : model -> (Pcode.program * model, model) result

(* the box after F9: the lines compiled and the code's size *)
val compiled_box : model -> Pcode.program -> model

(* Running and stepping *)

(* [go m step]: a step taken (F7 trace into, F8 step over, F4 to the
   cursor) or a run (Ctrl-F9), the program compiled and started first
   if it wasn't *)
val go : model -> Pdebug.step -> model

(* a frame while the program runs: its machine run towards the goal, a
   slice at most. Then paused, finished (the user screen kept, and a
   run-time error's line), waiting for a line to read, or still going *)
val advance : model -> session -> model

(* a key while the program runs: typed on the user screen for the line
   the program reads; Control-C, Turbo's Ctrl-Break, pauses it where it
   is *)
val executing_key : model -> session -> string -> model

(* the line (from 0) where a paused program is, the execution bar's;
   None when no program is paused *)
val execution_line : model -> int option

(* the word under the cursor: what Ctrl-F7 offers to watch *)
val word_at : model -> string
