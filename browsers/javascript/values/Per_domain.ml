(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: copied from libs/opti/domain/threads.ml.in in the author's
 * mini-chrome, its Per_domain for an OCaml without domains, which is
 * the only kind of OCaml here (docs/plans/plan_browser.md) *)

(* See Per_domain.mli *)

let parallel = false

let make (init : unit -> 'a) : unit -> 'a =
  let v = init () in
  fun () -> v

let main () : bool = true
