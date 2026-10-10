(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's examples/gui4/Gui4.ml; retained's before is said, where it was optional (nothing done) (docs/plans/plan_gui.md) *)

type architecture = Immediate | Callbacks | Mvc | Mvu

let architectures = [ (Immediate, "immediate"); (Callbacks, "callbacks"); (Mvc, "MVC"); (Mvu, "MVU") ]

type runner = { step : Widget.input -> Widget.paint list; summary : unit -> string }

let label_size (th : Theme.t) s = (Widget.text_width ~size:th.text_size s, th.row)

let places panel layout =
  let at = Layout.arrange panel layout in
  fun slot -> List.assoc slot at

let immediate theme frame =
  let ui = ref (Immediate.set_theme theme Immediate.empty) in
  fun i ->
    let u = frame (Immediate.frame i !ui) in
    ui := u;
    Immediate.paint u

let retained ~(before : unit -> unit) theme ui i =
  before ();
  Retained.handle i ui;
  Retained.paint theme ui
