(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Filename.mli *)

let check_suffix name suffix =
  let n = String.length name and m = String.length suffix in
  n >= m && String.sub name (n - m) m = suffix
let concat dir file =
  let n = String.length dir in
  if n = 0 || String.get dir (n - 1) = '/' then dir ^ file else dir ^ "/" ^ file

(* OCaml's: the slashes at the end, then the last name, then the
 * slashes before it, taken away; "." when no directory is left *)
let dirname name =
  let sep n = String.get name n = '/' in
  let rec trailing n = if n < 0 then String.sub name 0 1 else if sep n then trailing (n - 1) else base n
  and base n = if n < 0 then "." else if sep n then between n else base (n - 1)
  and between n = if n < 0 then String.sub name 0 1 else if sep n then between (n - 1) else String.sub name 0 (n + 1) in
  if name = "" then "." else trailing (String.length name - 1)
