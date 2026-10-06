(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See FileDir.mli *)

type file = { name : string; mutable data : Bytes.t; mutable length : int }

let files : (string * file) list ref = ref []

let find name = List.assoc_opt name !files
let delete name = files := List.remove_assoc name !files
let insert (f : file) = files := (f.name, f) :: List.remove_assoc f.name !files
let enumerate visit = List.iter (fun (_, f) -> visit f) (List.sort compare !files)

let init () =
  let disk = Machine.Phys.read (Machine.fs_base ()) (Machine.fs_size ()) in
  let rec read pos =
    match String.index_from_opt disk pos '\n' with
    | Some eol when eol > pos -> (
        match String.split_on_char ' ' (String.sub disk pos (eol - pos)) with
        | [ name; length ] ->
            let length = int_of_string length in
            insert { name; data = Bytes.of_string (String.sub disk (eol + 1) length); length };
            read (eol + 1 + length)
        | _ -> Machine.panic "FileDir: the disk's image")
    | _ -> ()
  in
  read 0
