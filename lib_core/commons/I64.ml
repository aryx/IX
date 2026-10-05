(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See I64.mli *)

let ( + ) = Int64.add
let ( - ) = Int64.sub
let ( * ) = Int64.mul
let ( land ) = Int64.logand
let ( lor ) = Int64.logor
let ( lxor ) = Int64.logxor
let lnot = Int64.lognot
let ( lsl ) = Int64.shift_left
let ( lsr ) = Int64.shift_right_logical
let ( asr ) = Int64.shift_right
let int = Int64.of_int
