(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Sha1.mli *)

type t = string

(* in C, the runtime's (TinyMLRuntime/core.c), on words of 32 bits
 * (old: here, a word as its two halves of 16, an integer having 31:
 * 2.6 KB a second on tiny-kernel, where tiny-build digests every file
 * of tiny-kernel's build of itself) *)
external string : string -> t = "ml_sha1_string"

(* the context, a string of the runtime's (ml_sha1_init) *)
type ctx = string
external init : unit -> ctx = "ml_sha1_init"
external update : ctx -> string -> unit = "ml_sha1_update"
external final : ctx -> t = "ml_sha1_final"

let reads next =
  let c = init () in
  let rec go () = match next () with "" -> final c | s -> update c s; go () in
  go ()

let to_hex t =
  let digit n = String.get "0123456789abcdef" n in
  String.init (2 * String.length t) (fun i -> let c = Char.code (String.get t (i / 2)) in digit (if i mod 2 = 0 then c lsr 4 else c land 15))
