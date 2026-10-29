(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Annotations.mli *)

let tailcalls : (Ast.span, unit) Hashtbl.t = Hashtbl.create 16
let tailrecs : (Ast.span, unit) Hashtbl.t = Hashtbl.create 16
