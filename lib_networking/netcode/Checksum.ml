(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/networking/netcode/Checksum.ml *)

(* See Checksum.mli *)

let offset_basis = 0x811c9dc5l
let prime = 16777619l

let fnv1a (s : string) : int32 =
  String.fold_left (fun hash c -> Int32.mul (Int32.logxor hash (Int32.of_int (Char.code c))) prime) offset_basis s

let of_model (model : 'a) : int32 = fnv1a (Marshal.to_string model [ Marshal.No_sharing ])

let to_hex (h : int32) : string = Printf.sprintf "%08lx" h
