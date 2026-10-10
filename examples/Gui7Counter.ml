(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's examples/Gui7Counter.ml; its last line is ix's (Playground_platform.mli says why), and what was optional is said (docs/plans/plan_gui.md) *)
(* 7GUIs, task 1: Counter
 * (docs/claude_notes/plans/plan_gui_teaching.md, phase 3).
 *
 * 7GUIs (Eugen Kiss, 2014) is seven tasks chosen to expose where each
 * way of building an interface hurts -- a benchmark for GUI toolkits
 * the way n-body is one for physics engines. The first is the
 * smallest program that has an interface at all: a number and a
 * button that increases it.
 *
 * Trivial, and that is the point: it is the baseline every
 * architecture is measured against, and here it is four lines of
 * update. In phase 4 the same task will be written with callbacks,
 * with MVC and in MVU, beside this immediate-mode one, and the
 * comparison starts from how little there is to compare.
 *
 * What the task asks for: a read-only field showing the count, and a
 * button. The field is read-only here in the simplest possible way --
 * a label -- since a field you cannot type in is a label with a box
 * around it.
 *
 * The seven, each with the one thing it is there to ask, and where
 * it is here:
 *
 *   1 Counter       Gui7Counter       is there an interface at all?
 *   2 Temperature   Gui7Temperature   two fields, each the other's
 *     Converter                       answer: which way does a change
 *                                     go, and what of half a number?
 *   3 Flight        Gui7Flight        rules between widgets: one turns
 *     Booker                          another off
 *   4 Timer         Gui7Timer         time: a thing changes that
 *                                     nobody touched
 *   5 CRUD          Gui7Crud          a list and a selection in it,
 *                                     the list changing under it
 *   6 Circle        Gui7Circles       a canvas, a dialog, and undo:
 *     Drawer                          what is one edit?
 *   7 Cells         Gui7Cells         a spreadsheet: a change that
 *                                     spreads, and a widget made anew
 *
 * They go up in size on purpose (a few lines to a real program),
 * and each can be done in an afternoon, which is what lets the same
 * seven be written again in every toolkit and the programs laid
 * side by side -- here four times over for five of them, in
 * GuiFourWays. All seven stand on the playground's Gui, which is
 * Immediate; the last two also on the office suite's Undo and
 * Sheet.
 *
 * others:
 * A benchmark of this kind measures the program, not the machine:
 * how much is written and where the difficulty went. TodoMVC (2012)
 * did the same for the web's frameworks with a single task, a list
 * of things to do, and is why every such framework has a to-do list
 * for its first example. 7GUIs asks more with less: TodoMVC has no
 * task where time passes or where an edit must be undone.
 *
 * References: Eugen Kiss, "7GUIs: A GUI Programming Benchmark"
 * (2014; the tasks' text is at 7guis.github.io/7guis).
 *
 * Exercises: make the count a field you can type into, and decide what
 * a field holding "12x" should do; two counters sharing one button;
 * the same task with callbacks (examples/GuiFourWays.ml has it).
 *)
open Playground

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

(* the whole model: the count. 7GUIs' baseline is a program with one
   number in it *)
let initial = 0

type slot = Count | Button

let panel =
  Layout.(
    center
      (column ~gap:10.
         [ leaf Count (Gui.field_size ()); stretch (leaf Button (Gui.button_size "count")) ]))

let places computer = Layout.arrange (Gui.area computer) panel

(*****************************************************************************)
(* Update *)
(*****************************************************************************)

let update computer model =
  let at = places computer in
  Gui.label_in computer (List.assoc Count at) (string_of_int model);
  if Gui.button_in ~enabled:true computer (List.assoc Button at) "count" then model + 1 else model

(*****************************************************************************)
(* View *)
(*****************************************************************************)

let view computer _model =
  let s = computer.screen in
  (rectangle (Gui.theme ()).background s.width s.height :: Gui.draw ())
  @ [ words black "7GUIs 1: Counter" |> move_y 200. ]

let app = game view update initial
let () = Cap.main (fun caps -> Playground_platform.run_app caps (Playground_platform.flags caps) app)
