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
  let rec trailing n =
    if n < 0 then String.sub name 0 1
    else if sep n then trailing (n - 1) else base n
  and base n = if n < 0 then "." else if sep n then between n else base (n - 1)
  and between n =
    if n < 0 then String.sub name 0 1
    else if sep n then between (n - 1) else String.sub name 0 (n + 1) in
  if name = "" then "." else trailing (String.length name - 1)

(* the last name, its slashes at the end taken away (OCaml's) *)
let basename name =
  let sep n = String.get name n = '/' in
  let rec trailing n =
    if n < 0 then String.sub name 0 1
    else if sep n then trailing (n - 1) else base n n
  and base e n =
    if n < 0 || sep n then String.sub name (n + 1) (e - n) else base e (n - 1) in
  if name = "" then "." else trailing (String.length name - 1)
let is_relative name = name = "" || String.get name 0 <> '/'
let chop_suffix name suffix =
  if check_suffix name suffix
  then String.sub name 0 (String.length name - String.length suffix)
  else invalid_arg "Filename.chop_suffix"

(* the extension: from the last dot of the last name, unless only dots
 * come before it there (OCaml's: .profile has none) *)
let remove_extension name =
  let sep i = String.get name i = '/' in
  let n = String.length name in
  let rec check dot i =
    if i < 0 || sep i then 0
    else if String.get name i = '.' then check dot (i - 1) else n - dot in
  let rec search i =
    if i < 0 || sep i then 0
    else if String.get name i = '.' then check i (i - 1) else search (i - 1) in
  String.sub name 0 (n - search (n - 1))
