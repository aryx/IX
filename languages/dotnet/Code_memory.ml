(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Code_memory.mli: dune's build, which has no JIT (mini-ml/'s
 * file is the other) *)

let available = false
let load (_ : string) : int = failwith "the JIT runs where mini-ml built mini-dotnet"
let closure (_ : int) : Obj.t = failwith "the JIT runs where mini-ml built mini-dotnet"
let address (_ : Obj.t) : int = failwith "the JIT runs where mini-ml built mini-dotnet"

exception Divide_by_zero
let divide_by_zero () : unit = raise Divide_by_zero
