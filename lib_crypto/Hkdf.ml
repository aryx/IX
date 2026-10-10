(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/crypto/Hkdf.ml (docs/plans/plan_browser.md) *)

(* See Hkdf.mli *)

let extract ~(hmac : string -> string -> string) ~(salt : string) (ikm : string) : string = hmac salt ikm

let expand ~(hmac : string -> string -> string) (prk : string) ~(info : string) (length : int) : string =
  let out = Buffer.create length in
  let rec go t i =
    if Buffer.length out < length then (
      let t = hmac prk (t ^ info ^ String.make 1 (Char.chr i)) in
      Buffer.add_string out t;
      go t (i + 1))
  in
  go "" 1;
  Buffer.sub out 0 length
