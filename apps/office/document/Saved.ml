(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's appkits/document/Saved.ml (docs/plans/plan_office.md) *)

let to_string ~magic v = magic ^ "\n" ^ Marshal.to_string v []

let of_string ~magic s =
  let head = magic ^ "\n" in
  let n = String.length head in
  if String.length s < n + Marshal.header_size || String.sub s 0 n <> head then None
  else
    let b = Bytes.unsafe_of_string s in
    (* all of the data, as Marshal's own header counts it *)
    if Marshal.total_size b n > String.length s - n then None
    else try Some (Marshal.from_bytes b n) with _ -> None
