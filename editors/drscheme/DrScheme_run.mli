(* DrScheme_run: a program evaluated, the three ways the IDE has: Execute
   and the prompt, a budget of steps a frame in the window's own thread;
   a (big-bang ...), run by the host; and the Step button's window,
   evaluation as algebra.

   A frame of the window has [fuel] steps of the machine to give:

       work m 100000
         | the job's next form:      Scheme_syntax.top, Scheme_eval.start
         | Scheme_eval.run ~fuel     at most the budget
         |-- Running                 spent: the machine kept as it is;
         |                           the next frame, the same call
         |-- Done v, 30000 steps     v said below, and 70000 are left:
         |                           work again, with those, on the next
         |                           form
         |-- Failed                  said below, the job dropped
         '-- World                   the status a World

   So a form that ends early gives what it did not spend to the next, and
   a file of a hundred small forms runs in a frame, not a hundred.

   Break is the status set to Idle and no more. Nothing is interrupted,
   as nothing is running: between two frames the machine is a value that
   nobody is working on, and it is left where it stopped.

   Execute starts from a new machine and clears the Interactions: the
   prompt then talks to the program as it is written (DrScheme.mli's
   cs-history). A failure is pink only when it comes from the definitions
   (a job's [from_defs]): the span of an expression typed at the prompt
   is in a text that the window no longer has.

   A world. The machine stops at big-bang with its description
   (Scheme_eval's World): the first world, and the handlers by their
   clause's name. From there, a frame of the window is a step of the
   student's program:

       update_world
         | on-tick    every other frame: 30 a second, HtDP's is 28
         | on-key     each key pressed in this frame (Bigbang.key_events)
         | on-mouse   when the mouse did something, in the scene's
         |            coordinates: from its corner, the scale undone
         | to-draw    the world's picture, kept for the view
         | stop-when
         |-- no         the same next frame
         '-- yes, or    finish: the last world is what big-bang returns
             Escape     (Scheme_eval.resume), the job goes on

   Each handler is a call into the same machine, nested, which keeps what
   it was doing for after (Scheme_eval.call), with a million steps: a
   handler is meant to end, and one that does not is a failure and ends
   the world. Here no budget is carried over to the next frame: a world's
   frame that is not finished has nothing to draw. A failure in a handler
   is said below but painted nowhere (fail's false): the handler may have
   been typed at the prompt, whose text is gone. The scene is drawn scaled
   down to fit 800 by 760, in a window drawn by this program over the two,
   not a window of the system's.

   The stepper. Beginning Student's evaluation, one rewriting at a time
   (Scheme_step):

       +- Stepper  (Esc closes) ----------------------------------+
       |          before                         after            |
       | +---------------------------+ +-------------------------+|
       | | (+ 5 (fact (- 5 1)))      | | (+ 5 (fact 4))          ||
       | |            ^^^^^^^ green  | |            ^ purple     ||
       | +---------------------------+ +-------------------------+|
       | [< Step]            step 3 of 57              [Step >]   |
       +----------------------------------------------------------+

   All the steps are made when the window opens, at most a thousand, an
   array: going back is an index taken down by one, as cheap as going on.
   The last index past the array says how it ended, the program's error
   or that all went well. The window knows nothing of the machine, nor
   the machine of it: Scheme_step rewrites text, on its own and from the
   definitions' text as it is now, not as last executed, so that it needs
   no Execute first. A step's panes are its text broken at the width of
   the pane, an offset kept for each row, so a redex over two rows is
   shaded on each.

   design:
   Why this works without threads: Scheme_eval is a CESK machine, whose
   continuation is a value of its own and not the OCaml stack, so
   stopping is returning. A recursive evaluator (mini-emacs's Lisp_eval)
   has its place in the middle of OCaml's stack, and could stop only in
   a thread of its own. The machine's shape is what gives the IDE its
   Break.

   others:
   Counting work rather than time is how Erlang's BEAM shares a core
   among its processes: a process runs a number of reductions, then the
   scheduler takes the next. Turbo_debug gives its P-machine a slice of
   instructions in the same way. An operating system does it with a
   clock's interrupt instead (mini-9pi's scheduler), for programs that
   are not there to be counted.

   reframe:
   The window around it is Model-View-Update, the Playground's game; and
   a big-bang is Model-View-Update too, written by the student: the world
   the model, on-tick and on-key the update, to-draw the view. So a world
   is one such loop running inside another, the outer's update calling
   the inner's. Bigbang.mli tells how big-bang came to be, and how Elm
   found the same solution; BigBangRocket and BigBangWorm are worlds
   written in OCaml.

   others:
   A debugger steps forward because that is what a machine does; to step
   back, it must have kept the past, as rr's recording does for a whole
   process, at a cost. An evaluation told as a list of texts has no such
   question. mini-turbopascal's debugger is the other way of showing a
   program run: the same program, a bar on the line, its variables
   watched, and what it shows is the machine. *)

open Playground
open DrScheme_model

(*****************************************************************************)
(* The model's questions *)
(*****************************************************************************)

(* "Welcome to DrScheme" and the language, newest first *)
val banner : level -> entry list

(* how a value is printed: Beginning Student's (list 1 2), or (1 2) *)
val style : model -> Scheme.style

val running : model -> bool

(* the machine: a new one when there was none *)
val machine : model -> Scheme_eval.state

(* an entry below; display's pieces make one *)
val add : entry -> model -> model

(*****************************************************************************)
(* Running: a budget of steps a frame *)
(*****************************************************************************)

(* the steps of a frame *)
val fuel : int

(* [work m budget]: the job on, until its steps are spent, it waits
   for a world, or it is done *)
val work : model -> int -> model

(* Execute: a new machine, the Interactions cleared, the definitions
   read and queued *)
val execute : model -> model

val break : model -> model

(*****************************************************************************)
(* A world, run by the host *)
(*****************************************************************************)

(* a frame of the world: its handlers called. The world goes on, or it
   ended and the job is on, or a failure ended both *)
val update_world : computer -> model -> world -> model

(* the scene, and a title over it *)
val view_world : world -> shape list

(*****************************************************************************)
(* The stepper *)
(*****************************************************************************)

(* the steps made, the window open; in Standard, a word below instead *)
val open_stepper : model -> model

(* [update_stepper computer keys m s]: arrows and buttons, Escape closes *)
val update_stepper : computer -> string list -> model -> stepper -> model

val view_stepper : stepper -> shape list
