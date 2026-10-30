(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's apps/devtools/TinyDrScheme.ml, here mini-drscheme (a tiny-xxx of ix's is one of tiny/'s files); its last lines are ix's (Playground_platform.mli says why; -h, its help the header's sentences on the keys, and a wrong word on the command line said in a line); the machine's fuel and the stepper's limit are said, where they were optional; a string's characters are taken without a Seq, and an Option.value is written out; text_view's x and y are a pair; and Enter at the prompt takes the frame's typed text with it (docs/plans/plan_scheme.md) *)

(* See DrScheme.mli *)

open Playground
open DrScheme_model
open DrScheme_run
open DrScheme_update
open DrScheme_view

let program =
  {|;; Beginning Student: define, then try at the prompt below
(define (fact n)
  (cond [(= n 0) 1]
        [else (* n (fact (- n 1)))]))

(fact 5)

(beside (circle 20 "solid" "red")
        (circle 20 "solid" "orange")
        (circle 20 "solid" "gold"))

;; How to Design Programs' first world: a rocket landing
(define ROCKET
  (above (triangle 24 "solid" "red")
         (rectangle 14 34 "solid" "gray")))
(define (draw y) (place-image ROCKET 100 y (empty-scene 200 240)))
(define (landed? y) (>= y 200))
(big-bang 0 [on-tick add1] [to-draw draw] [stop-when landed?])
|}

let initial_model : model =
  { defs = Text_edit.of_string program; top = 0; input = Text_edit.of_string ""; focus = Definitions; entries = banner Beginning; machine = None;
    status = Idle; level = Beginning; pink = None; executed = None; stepper = None; keyboard = initial_computer.keyboard;
    mouse = initial_computer.mouse; held = []; dragging = false; frames = 0 }

let app = game view update initial_model

(* -h: how *)
let help = {|usage: mini-drscheme [size=n]
DrScheme in small, in the look of version 209: the program in the Definitions
window above, a prompt in the Interactions window below, Execute between them.
  Control-T, or the Execute button   runs the definitions
  Enter at the prompt                evaluates what was typed
  Break                              stops a program that runs away
  Step                               opens the stepper (Escape closes it)
  a click on "Language:"             Beginning Student or Standard (R5RS)
  Control-Q                          ends it
size=n: a window of n pixels (on Linux 1000, and the window may be given another
size; on mini-9pi the window's, or the screen's).
|}

(* (-help: the platform's usage, and the end, Exit.ExitCode) *)
let () = Cap.main (fun caps -> Exit.exit caps @@ Exit.catch @@ fun () ->
  (if Array.mem "-h" (CapSys.argv caps) then Console.print caps help
   else
     try Playground_platform.run_app caps (Playground_platform.flags caps) app
     with Failure msg -> Console.eprint caps (msg ^ "\n"); CapStdlib.exit caps 1);
  Exit.OK)
