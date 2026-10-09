open Fpath_.Operators

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

(* ix: a file opened by Unix.openfile given the capability: to read, to
 * read and write, to write (made or emptied), to write at its end *)
let open_in_fd (_caps : < Cap.open_in; .. >) (file : string) : Unix.file_descr =
  Unix.openfile file [ Unix.O_RDONLY ] 0
let open_rw_fd (_caps : < Cap.open_in; Cap.open_out; .. >) (file : string) : Unix.file_descr =
  Unix.openfile file [ Unix.O_RDWR ] 0
let open_out_fd (_caps : < Cap.open_out; .. >) (file : string) (perm : Unix.file_perm) : Unix.file_descr =
  Unix.openfile file [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC ] perm
let open_append_fd (_caps : < Cap.open_out; .. >) (file : string) (perm : Unix.file_perm) : Unix.file_descr =
  Unix.openfile file [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_APPEND ] perm


(* ix: whole files in and out (ix's Files, merged here): what the
 * assembler, the linker, the compilers, the builder and the shell do
 * with a file is read it all or write it all *)
(* TinyLib: lib_core's reads and writes by In_channel and Out_channel,
 * which are not here: the same, on Pervasives's channels *)
(* by pieces: a pipe has no length to ask for *)
let input caps file =
  let ic = CapStdlib.open_in caps !!file in
  Fun.protect ~finally:(fun () -> close_in ic) (fun () ->
    let b = Buffer.create 4096 and piece = Bytes.create 4096 in
    let rec go () =
      let n = Pervasives.input ic piece 0 4096 in
      if n > 0 then begin Buffer.add_subbytes b piece 0 n; go () end
    in
    go ();
    Buffer.contents b)

let read (caps : < Cap.open_in; .. >) file =
  Logs.debug (fun m -> m "read %a" Fpath.pp file);
  input caps file


let write_perm (_ : < Cap.open_out; .. >) perm file s =
  Logs.debug (fun m -> m "write %a (%d bytes)" Fpath.pp file (String.length s));
  let oc = open_out_gen [ Open_wronly; Open_creat; Open_trunc; Open_binary ] perm !!file in
  Fun.protect ~finally:(fun () -> close_out oc) (fun () -> output_string oc s)

let write caps file s = write_perm caps 0o644 file s


(* ix: libc's cleanname: a name without its empty and "." parts, and
 * without the ".." a name before them answers *)
let cleanname name =
  let rooted = name <> "" && name.[0] = '/' in
  let parts = List.fold_left (fun acc part ->
    match part, acc with
    | ("" | "."), _ -> acc
    | "..", p :: rest when p <> ".." -> rest
    | "..", [] when rooted -> []
    | _ -> part :: acc) [] (String.split_on_char '/' name) in
  match rooted, String.concat "/" (List.rev parts) with
  | true, s -> "/" ^ s
  | false, "" -> "."
  | false, s -> s


