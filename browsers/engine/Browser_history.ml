(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's src/chrome/Browser_history.ml, its first version (docs/plans/plan_browser.md) *)

(* See Browser_history.mli *)

type 'a t = { behind : 'a list; ahead : 'a list }

let empty = { behind = []; ahead = [] }
let visit (current : 'a) (h : 'a t) : 'a t = { behind = current :: h.behind; ahead = [] }

let back (current : 'a) (h : 'a t) : ('a * 'a t) option =
  match h.behind with e :: rest -> Some (e, { behind = rest; ahead = current :: h.ahead }) | [] -> None

let forward (current : 'a) (h : 'a t) : ('a * 'a t) option =
  match h.ahead with e :: rest -> Some (e, { ahead = rest; behind = current :: h.behind }) | [] -> None
