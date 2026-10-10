(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/networking/tls/Pem.ml (docs/plans/plan_browser.md) *)

(* See Pem.mli *)

let certificates (text : string) : string list =
  let lines = String.split_on_char '\n' text |> List.map String.trim in
  let rec go inside acc lines =
    match lines with
    | [] -> List.rev acc
    | "-----BEGIN CERTIFICATE-----" :: rest -> go (Some []) acc rest
    | "-----END CERTIFICATE-----" :: rest -> (
        match inside with Some b64 -> go None (Base64.decode (String.concat "" (List.rev b64)) :: acc) rest | None -> go None acc rest)
    | l :: rest -> go (Option.map (fun b -> l :: b) inside) acc rest
  in
  go None [] lines
