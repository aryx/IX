(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's playground's libs/crypto/tests/Testutil_crypto.ml (docs/plans/plan_browser.md) *)

(* See Testutil_crypto.mli *)

let unhex (s : string) : string =
  let s = String.concat "" (String.split_on_char ' ' (String.concat "" (String.split_on_char '\n' s))) in
  String.init (String.length s / 2) (fun i -> Char.chr (int_of_string ("0x" ^ String.sub s (2 * i) 2)))

let hex (s : string) : string = String.concat "" (List.init (String.length s) (fun i -> Printf.sprintf "%02x" (Char.code s.[i])))
let check_hex (name : string) (expected : string) (actual : string) : unit = Alcotest.(check string) name (hex (unhex expected)) (hex actual)
