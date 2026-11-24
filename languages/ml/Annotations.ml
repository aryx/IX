(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Annotations.mli *)

let tailcalls : (Ast.span, unit) Hashtbl.t = Hashtbl.create 16
let tailrecs : (Ast.span, unit) Hashtbl.t = Hashtbl.create 16
let zero_allocs : (Ast.span, unit) Hashtbl.t = Hashtbl.create 16
let inlines : (Ast.span, unit) Hashtbl.t = Hashtbl.create 16
let unboxed_floats : (Ast.span, unit) Hashtbl.t = Hashtbl.create 16
let raises : (string, string) Hashtbl.t = Hashtbl.create 16

let known =
  [ (* the checked annotations, and what the analyses read *)
    "tailrec"; "zero_alloc"; "inline"; "unboxed_float"; "raise";
    (* mlpp's *)
    "deriving"; "class"; "instance";
    (* OCaml's *)
    "unboxed"; "noalloc"; "warning"; "ocaml.warning"; "immediate"; "deprecated"; "ocaml.deprecated";
    "specialise"; "untagged"; "alert"; "ocaml.alert" ]

let has (name : string) (attrs : Ast.attribute list) : bool =
  List.exists (fun (a : Ast.attribute) -> a.aname = name) attrs
