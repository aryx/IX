(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/crypto/Chacha20_poly1305.ml (docs/plans/plan_browser.md) *)

(* See Chacha20_poly1305.mli *)

let pad16 (s : string) : string = String.make ((16 - (String.length s mod 16)) mod 16) '\000'
let le64 (n : int) : string = String.init 8 (fun i -> Char.chr ((n lsr (8 * i)) land 0xff))

let tag ~key ~nonce ~aad (ct : string) : string =
  let otk = String.sub (Chacha20.block ~key ~nonce 0) 0 32 in
  Poly1305.mac ~key:otk (aad ^ pad16 aad ^ ct ^ pad16 ct ^ le64 (String.length aad) ^ le64 (String.length ct))

let seal ~key ~nonce ~aad (plaintext : string) : string =
  let ct = Chacha20.encrypt ~key ~nonce ~counter:1 plaintext in
  ct ^ tag ~key ~nonce ~aad ct

(* compared in full, not stopping at the first difference: how long
   the comparison takes says nothing of where it failed *)
let same (a : string) (b : string) : bool =
  String.length a = String.length b
  &&
  let d = ref 0 in
  String.iteri (fun i c -> d := !d lor (Char.code c lxor Char.code b.[i])) a;
  !d = 0

let open_ ~key ~nonce ~aad (data : string) : string option =
  let n = String.length data in
  if n < 16 then None
  else
    let ct = String.sub data 0 (n - 16) and t = String.sub data (n - 16) 16 in
    if same t (tag ~key ~nonce ~aad ct) then Some (Chacha20.encrypt ~key ~nonce ~counter:1 ct) else None
