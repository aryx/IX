(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See In_channel.mli *)

type t = in_channel

(* (the channel is the descriptor: Stdlib.ml) *)
external u_read : in_channel -> int -> string = "u_read"

(* (the pieces joined at the end, as TinyLibSystem.read_all's) *)
let input_all ic =
  let rec go acc =
    let s = u_read ic 4096 in
    if s = "" then String.concat "" (List.rev acc) else go (s :: acc)
  in
  go []
