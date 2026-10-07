open Fpath_.Operators
(* for fields *)
open Chan

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)
(* Capability-aware filesystem operations.
 *)

(*****************************************************************************)
(* API *)
(*****************************************************************************)

(* capabilities-aware version of UChan.ml *)
(* ix: the capabilities by their types (mini-ml has no objects: xix's
 * caps#open_in !!file) *)
let with_open_in (_caps : < Cap.open_in; .. >) f file = 
  (* nosemgrep: use-caps *)
  let chan : in_channel =
    (* nosemgrep: do-not-use-open-in *)
    open_in !!file 
  in
  let ichan : Chan.i = { ic = chan; origin = Chan.File file } in
  Fun.protect ~finally:(fun () -> close_in chan) (fun () -> f ichan)
let with_open_out (_caps : < Cap.open_out; .. >) f file = 
  (* nosemgrep: use-caps *)
  let chan : out_channel =
    (* nosemgrep: use-caps *)
    open_out !!file 
  in
  let ochan : Chan.o = { oc = chan; dest = Chan.OutFile file } in
  Fun.protect ~finally:(fun () -> close_out chan) (fun () -> f ochan)

(* ix: a file's descriptor, for a program that reads and writes bytes
 * and says the system's reason when it cannot (Unix_error's; open_in's
 * Sys_error has only the name under mini-ml). A name as it is given:
 * Plan 9's '#c/cons' too. *)
let open_in_fd (_caps : < Cap.open_in; .. >) (file : string) : Unix.file_descr =
  (* nosemgrep: use-caps *)
  Unix.openfile file [ Unix.O_RDONLY ] 0
let open_rw_fd (_caps : < Cap.open_in; Cap.open_out; .. >) (file : string) : Unix.file_descr =
  (* nosemgrep: use-caps *)
  Unix.openfile file [ Unix.O_RDWR ] 0

(* ix: a file made, or emptied, to be written (cp's); a file made that
 * must not be there (touch's); a directory made;
 * a file or an empty directory removed (Plan 9's remove is one call
 * for the two, Unix has two); the directory the process is in *)
let open_out_fd (_caps : < Cap.open_out; .. >) (file : string) (perm : Unix.file_perm) : Unix.file_descr =
  (* nosemgrep: use-caps *)
  Unix.openfile file [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC ] perm
let create_fd (_caps : < Cap.open_out; .. >) (file : string) (perm : Unix.file_perm) : Unix.file_descr =
  (* nosemgrep: use-caps *)
  Unix.openfile file [ Unix.O_RDONLY; Unix.O_CREAT; Unix.O_EXCL ] perm
let mkdir (_caps : < Cap.open_out; .. >) (dir : string) (perm : Unix.file_perm) : unit =
  (* nosemgrep: use-caps *)
  Unix.mkdir dir perm
let remove_any (_caps : < Cap.open_out; .. >) (file : string) : unit =
  (* nosemgrep: use-caps *)
  try Unix.unlink file with Unix.Unix_error ((Unix.EISDIR | Unix.EPERM), _, _) -> Unix.rmdir file
let getcwd (_caps : < Cap.readdir; .. >) () : string =
  (* nosemgrep: use-caps *)
  Unix.getcwd ()

(* tail recursive efficient version *)
let cat (caps : < Cap.open_in; .. >) (file : Fpath.t) : string list =
  file |> with_open_in caps (fun chan ->
  let rec cat_aux acc ()  =
      (* cant do input_line chan::aux() cos ocaml eval from right to left ! *)
    let (b, l) = try (true, input_line chan.ic) with End_of_file -> (false, "") in
    if b
    then cat_aux (l::acc) ()
    else acc
  in
  cat_aux [] () |> List.rev
  )

let remove (_caps : < Cap.open_out; ..>) (file : Fpath.t) =
  (* alt: Logs.info (fun m -> m "deleting %s" !!file); *)
  (* alt: use Unix.unlink? *)
  (* nosemgrep: use-caps *)
  Sys.remove !!file
