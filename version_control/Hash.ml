(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Hash.mli *)

type t = Sha1.t

let zero = Sha1.of_raw (String.make 20 '\000')
let of_object kind data = Sha1.strings [ Printf.sprintf "%s %d\000" kind (String.length data); data ]
let to_hex = Sha1.to_hex
let of_hex = Sha1.of_hex
let is_hex s = String.length s = 40 && String.for_all (function '0' .. '9' | 'a' .. 'f' -> true | _ -> false) s
let compare (a : t) (b : t) = String.compare (Sha1.raw a) (Sha1.raw b)
