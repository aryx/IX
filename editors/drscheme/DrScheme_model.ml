(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's apps/devtools/TinyDrScheme.ml, its section The model's types (docs/plans/plan_scheme.md) *)

(* DrScheme_model: the types of mini-drscheme, and nothing else. All that
   the program knows is one record, replaced at each frame; its parts
   open this module, as Turbo_model's do (whose design: paragraph says
   what such a record buys and costs).

   What the program is doing is one field, [status], and what each
   state needs is in its constructor:

            Execute, or Enter at the prompt
       Idle ------------------------------> Busy job
        ^ ^                                  |    ^
        | | the forms spent, a failure,      |    | the world ended:
        | '------ Break --------------------'|    | big-bang returns,
        |                                    |    | the job goes on
        |                     (big-bang ...) v    |
        '---- a failure, Break ---------- World w

   A job left half done is not lost in a world: [after] holds it, and
   the machine holds where in the form it was (Scheme_eval.resume). The
   stepper is not a status: it opens only when Idle and is over the
   windows until closed.

   The machine is an option because nothing made it yet before the first
   Execute or the first line at the prompt. It lives outside the job: it
   is what stays when a job is over, and the next job, Enter at the
   prompt, runs on it and sees the definitions. Only Execute replaces it.

   terminology:
   DrScheme says Language where this says [level]: the menu is Choose
   Language, and a teaching language is a level of a ladder (Beginning
   Student, Intermediate, Advanced). Here, two rungs: Beginning and
   Standard (R5RS), which is no teaching language. What differs is how
   a value is printed (Scheme.style) and whether the stepper opens, not
   what the machine accepts. *)

open Playground

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

type level = Beginning | Standard
type pane = Definitions | Interactions

(* what the Interactions window shows *)
type entry =
  | Banner of string
  | Echo of string (* what was typed at the prompt *)
  | Result of Scheme.t
  | Printed of string (* display's *)
  | Failure of string
  | Warning of string

(* forms to evaluate, a machine running one of them *)
type job = { forms : Sexpr.t list; from_defs : bool; running : bool }

type world = {
  spec : Scheme_eval.world;
  value : Scheme.t;
  picture : Scheme_image.t option;
  ticks : int;
  after : job; (* what to go on with, the last world returned *)
}

type status = Idle | Busy of job | World of world

type stepper = { steps : Scheme_step.step array; error : string option; shown : int }

type model = {
  defs : Text_edit.t;
  top : int; (* the Definitions' first line shown *)
  input : Text_edit.t; (* the prompt's *)
  focus : pane;
  entries : entry list; (* newest first *)
  machine : Scheme_eval.state option; (* made by the first Execute, or the prompt *)
  status : status;
  level : level;
  pink : (int * int) option; (* the failed expression's span in the definitions *)
  executed : string option; (* the definitions last executed, to warn when they changed *)
  stepper : stepper option;
  keyboard : keyboard; (* at the last frame *)
  mouse : mouse;
  held : (string * int) list; (* keys held, for how many frames: repeating *)
  dragging : bool;
  frames : int;
}
