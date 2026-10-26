(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyCTypes.mli *)

(* (old: a format, Printf.ksprintf's: tiny-ml reads a format only where
 * it is written, Printf.sprintf at the call) *)
let error s = failwith s

(* the machine, TinyCPU, has words of 4 bytes: pointers too, and no
 * long long *)
let unit_name = ref ""  (* the file's name, its local names' prefix *)

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

type ty =
  | Void
  | Int of int * bool                 (* bytes, signed *)
  | Ptr of ty
  | Arr of ty * int
  | Struct of sdef
  | Func of ty * ty list * bool       (* result, parameters, variadic *)

and sdef = {
  mutable fields : (string * ty * int) list;
  mutable ssize : int;
  mutable salign : int }

let int_t = Int (4, true) and long_t = Int (8, true) and char_t = Int (1, true)
(* an int's largest value (old: 0x7fffffffL, a literal tiny-ml does
 * not read) *)
let int_max = Int64.of_string "0x7fffffff"
let rec size = function
  | Void -> 1 | Int (n, _) -> n | Ptr _ | Func _ -> 4
  | Arr (t, n) -> n * size t | Struct s -> s.ssize
let rec align = function
  | Int (n, _) -> n | Arr (t, _) -> align t | Struct s -> s.salign | _ -> 4
let round n a = (n + a - 1) / a * a
let is_int = function Int _ -> true | _ -> false
let is_ptr = function Ptr _ -> true | _ -> false
let unsigned = function Int (_, s) -> not s | Ptr _ -> true | _ -> false

(* a declared long long refused (its values live in 32-bit registers);
 * the compiler's own long temporaries are 32 bits there *)
let rec no_vlong t =
  match t with
  | Int (8, _) -> error "long long: not on TinyCPU (a 32-bit machine)"
  | Arr (t, _) -> no_vlong t
  | Ptr t -> no_vlong t
  | Func (r, ps, _) -> no_vlong r; List.iter no_vlong ps
  | _ -> ()

(* a structure is itself: struct node { struct node *next; } *)
let rec same a b =
  match a, b with
  | Struct s, Struct t -> s == t
  | Ptr a, Ptr b -> same a b
  | Arr (a, n), Arr (b, m) -> n = m && same a b
  | Func (r, p, v), Func (s, q, w) ->
      v = w && same r s && List.length p = List.length q
      && List.for_all2 same p q
  | a, b -> a = b
