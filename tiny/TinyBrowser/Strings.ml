(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Strings.mli *)

let find s pat i : int option =
  let n = String.length s and m = String.length pat in
  let rec at j k = k >= m || (s.[j + k] = pat.[k] && at j (k + 1)) in
  let rec go j =
    if j + m > n then None else if at j 0 then Some j else go (j + 1) in
  go i

let is_space c = c = ' ' || c = '\n' || c = '\t' || c = '\r'

let number s = match int_of_string_opt s with Some n -> n | None -> 0
