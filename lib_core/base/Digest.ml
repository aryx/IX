(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  Automatique.  Distributed only by permission.                      *)
(*                                                                     *)
(***********************************************************************)


(* Message digest (MD5) *)

type t = string

external unsafe_string: string -> int -> int -> t = "md5_string"
external channel: in_channel -> int -> t = "md5_chan"

let string str =
  unsafe_string str 0 (String.length str)

let substring str ofs len =
  if ofs < 0 or ofs + len > String.length str
  then invalid_arg "Digest.substring"
  else unsafe_string str ofs len

let file filename =
  let ic = open_in filename in
  (* ix: the whole file, as OCaml's later Digest.file (not its length asked) *)
  let d = channel ic (-1) in
  close_in ic;
  d

let output chan digest =
  output_substring chan digest 0 16

let input chan =
  let digest = Bytes.create 16 in
  really_input chan digest 0 16;
  Bytes.unsafe_to_string digest

(* ix: OCaml's later functions, those ix's programs use *)

let to_hex d =
  String.init 32 (fun i ->
    let c = Char.code d.[i / 2] in
    "0123456789abcdef".[if i land 1 = 0 then c lsr 4 else c land 15])
