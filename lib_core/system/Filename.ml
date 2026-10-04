(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*          Xavier Leroy and Damien Doligez, INRIA Rocquencourt        *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  Automatique.  Distributed only by permission.                      *)
(*                                                                     *)
(***********************************************************************)

(* ix: Unix's and Plan 9's names only: ocaml-light's Filename also had
   Windows's (a drive, a backslash) and the old MacOS's (a colon), each
   function chosen by Sys.os_type. *)

let current_dir_name = "."

let concat dirname filename =
  let l = String.length dirname in
  if l = 0 or dirname.[l-1] = '/'
  then dirname ^ filename
  else dirname ^ "/" ^ filename

let is_relative n = String.length n < 1 || n.[0] <> '/';;

let is_implicit n =
  is_relative n
  && (String.length n < 2 || String.sub n 0 2 <> "./")
  && (String.length n < 3 || String.sub n 0 3 <> "../")
;;

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

let basename name =
  try
    let p = String.rindex name '/' + 1 in
    String.sub name p (String.length name - p)
  with Not_found ->
    name

let dirname name =
  try
    match String.rindex name '/' with
      0 -> "/"
    | n -> String.sub name 0 n
  with Not_found ->
    "."

let temporary_directory = try Sys.getenv "TMPDIR" with Not_found -> "/tmp"

external open_desc: string -> open_flag list -> int -> int = "sys_open"
external close_desc: int -> unit = "sys_close"

let temp_file prefix suffix =
  let rec try_name counter =
    let name =
      concat temporary_directory (prefix ^ string_of_int counter ^ suffix) in
    try
      close_desc(open_desc name [Open_wronly; Open_creat; Open_excl] 0o666);
      name
    with Sys_error _ ->
      try_name (counter + 1)
  in try_name 0


(* ix: OCaml's later functions, those ix's programs use *)

let remove_extension name = try chop_extension name with Invalid_argument _ -> name

(* between quotes for the shell, a quote in it as '\'' *)
let quote s = "'" ^ String.concat "'\\''" (String.split_on_char '\'' s) ^ "'"
