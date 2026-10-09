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



(* ix: whole files in and out (ix's Files, merged here): what the
 * assembler, the linker, the compilers, the builder and the shell do
 * with a file is read it all or write it all *)
let input caps file =
  let ic = CapStdlib.open_in caps (Fpath.to_string file) in
  Fun.protect ~finally:(fun () -> close_in ic) (fun () -> In_channel.input_all ic)

let read (caps : < Cap.open_in; .. >) file =
  Logs.debug (fun m -> m "read %a" Fpath.pp file);
  input caps file


let write_perm (_ : < Cap.open_out; .. >) perm file s =
  Logs.debug (fun m -> m "write %a (%d bytes)" Fpath.pp file (String.length s));
  Out_channel.with_open_gen [ Open_wronly; Open_creat; Open_trunc; Open_binary ] perm (Fpath.to_string file)
    (fun oc -> Out_channel.output_string oc s)

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


