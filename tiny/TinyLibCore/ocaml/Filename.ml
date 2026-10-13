(* Xavier Leroy and Damien Doligez, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. Distributed only by permission. *)

(* ix: Unix's and Plan 9's names only: ocaml-light's Filename also had
   Windows's (a drive, a backslash) and the old MacOS's (a colon), each
   function chosen by Sys.os_type. *)

let concat dirname filename =
  let l = String.length dirname in
  if l = 0 or dirname.[l-1] = '/'
  then dirname ^ filename
  else dirname ^ "/" ^ filename

let is_relative n = String.length n < 1 || n.[0] <> '/';;

let check_suffix name suff =
 String.length name >= String.length suff &&
 String.sub name (String.length name - String.length suff) (String.length suff)
    = suff

let chop_suffix name suff =
  let n = String.length name - String.length suff in
  if n < 0 then invalid_arg "Filename.chop_suffix" else String.sub name 0 n

let chop_extension name =
  try
    String.sub name 0 (String.rindex name '.')
  with Not_found ->
    invalid_arg "Filename.chop_extension"

(* ix: the two as OCaml 4.14's (its generic_basename and
 * generic_dirname): the slashes at a name's end are not of it, so
 * basename "d/sub/" is "sub" and dirname "d/sub/" is "d"; "" is ".".
 * old: OCaml Light's, the text after the last slash and the text
 * before it: basename "d/sub/" was "" and dirname "d/sub/" "d/sub"
 * (docs/plans/bugs/ix.md) *)
let basename name =
  let rec find_end n =
    if n < 0 then String.sub name 0 1
    else if name.[n] = '/' then find_end (n - 1)
    else find_beg n (n + 1)
  and find_beg n p =
    if n < 0 then String.sub name 0 p
    else if name.[n] = '/' then String.sub name (n + 1) (p - n - 1)
    else find_beg (n - 1) p in
  if name = "" then "." else find_end (String.length name - 1)

let dirname name =
  let rec trailing_sep n =
    if n < 0 then String.sub name 0 1
    else if name.[n] = '/' then trailing_sep (n - 1)
    else base n
  and base n =
    if n < 0 then "."
    else if name.[n] = '/' then intermediate_sep n
    else base (n - 1)
  and intermediate_sep n =
    if n < 0 then String.sub name 0 1
    else if name.[n] = '/' then intermediate_sep (n - 1)
    else String.sub name 0 (n + 1) in
  if name = "" then "." else trailing_sep (String.length name - 1)

let temporary_directory = try Sys.getenv "TMPDIR" with Not_found -> "/tmp"

external open_desc: string -> open_flag list -> int -> int = "sys_open"
external close_desc: int -> unit = "sys_close"

(* ix: OCaml's later functions, those ix's programs use *)

let remove_extension name = try chop_extension name with Invalid_argument _ -> name

(* between quotes for the shell, a quote in it as '\'' *)
let quote s = "'" ^ String.concat "'\\''" (String.split_on_char '\'' s) ^ "'"
