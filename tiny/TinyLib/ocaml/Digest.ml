(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. Distributed only by permission. *)

(* Message digest (MD5) *)

type t = string

external unsafe_string: string -> int -> int -> t = "md5_string"
external channel: in_channel -> int -> t = "md5_chan"

let string str =
  unsafe_string str 0 (String.length str)


let file filename =
  let ic = open_in filename in
  (* ix: the whole file, as OCaml's later Digest.file (not its length asked) *)
  let d = channel ic (-1) in
  close_in ic;
  d



(* ix: OCaml's later functions, those ix's programs use *)

let to_hex d =
  String.init 32 (fun i ->
    let c = Char.code d.[i / 2] in
    "0123456789abcdef".[if i land 1 = 0 then c lsr 4 else c land 15])
