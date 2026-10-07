(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Symbol.mli *)
open Ast

exception Error of string

let in_definition = ref false

(* (Hashtbl.add: a name's last symbol hides the others, as the list's front) *)
let table : (string, symbol) Hashtbl.t = Hashtbl.create 64

let install name value =
  let s = { name; value } in
  Hashtbl.add table name s;
  s

let find name = match Hashtbl.find_opt table name with Some s -> s | None -> install name Undef

let check name d =
  if d <> d then raise (Error (name ^ " argument out of domain"))
  else if d = infinity || d = neg_infinity then raise (Error (name ^ " result out of range"))
  else d

let integer x =
  if x < -2147483648.0 || x > 2147483647.0 then raise (Error "argument out of domain");
  Float.trunc x

let () =
  List.iter (fun (name, v) -> ignore (install name (Var v)))
    [ "PI", 3.14159265358979323846; "E", 2.71828182845904523536;
      "GAMMA", 0.57721566490153286060;   (* Euler *)
      "DEG", 57.29577951308232087680;    (* degrees in a radian *)
      "PHI", 1.61803398874989484820 ];   (* golden ratio *)
  let checked name f = (name, fun x -> check name (f x)) in
  List.iter (fun (name, f) -> ignore (install name (Builtin f)))
    [ "sin", sin; "cos", cos; "tan", tan; "atan", atan; checked "asin" asin; checked "acos" acos;
      checked "sinh" sinh; checked "cosh" cosh; "tanh", tanh; checked "log" log; checked "log10" log10;
      checked "exp" exp; checked "sqrt" sqrt; "int", integer; "abs", abs_float ]
