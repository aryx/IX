(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Fingerprint.mli: the native road's, ML's *)

let basis () : Int64.t = 0xcbf29ce484222325L
let mix (h : Int64.t) (b : int) : Int64.t =
  Int64.mul (Int64.logxor h (Int64.of_int (b land 0xff))) 0x100000001b3L
let add (a : Int64.t) (b : Int64.t) : Int64.t = Int64.add a b
