(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Filename.mli *)

let check_suffix name suffix =
  let n = String.length name and m = String.length suffix in
  n >= m && String.sub name (n - m) m = suffix
let concat dir file =
  let n = String.length dir in
  if n = 0 || String.get dir (n - 1) = '/' then dir ^ file else dir ^ "/" ^ file
