(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Stdlib.mli *)

external raise : exn -> 'a = "%raise"
external ( = ) : 'a -> 'a -> bool = "%eq"
external ( <> ) : 'a -> 'a -> bool = "%neq"
external ( < ) : 'a -> 'a -> bool = "%lt"
external ( > ) : 'a -> 'a -> bool = "%gt"
external ( <= ) : 'a -> 'a -> bool = "%le"
external ( >= ) : 'a -> 'a -> bool = "%ge"
external ( == ) : 'a -> 'a -> bool = "%physeq"
external ( != ) : 'a -> 'a -> bool = "%physneq"
external compare : 'a -> 'a -> int = "ml_compare"
external not : bool -> bool = "%not"
external ( ~- ) : int -> int = "%neg"
external ( + ) : int -> int -> int = "%add"
external ( - ) : int -> int -> int = "%sub"
external ( * ) : int -> int -> int = "%mul"
external ( / ) : int -> int -> int = "%div"
external ( mod ) : int -> int -> int = "%mod"
external ( land ) : int -> int -> int = "%and"
external ( lor ) : int -> int -> int = "%or"
external ( lxor ) : int -> int -> int = "%xor"
external ( lsl ) : int -> int -> int = "%lsl"
external ( lsr ) : int -> int -> int = "%lsr"
external ( asr ) : int -> int -> int = "%asr"
external lnot : int -> int = "%lnot"
external ref : 'a -> 'a ref = "%ref"
external ( ! ) : 'a ref -> 'a = "%field0"
external ( := ) : 'a ref -> 'a -> unit = "%setfield0"
external fst : 'a * 'b -> 'a = "%field0"
external snd : 'a * 'b -> 'b = "%field1"
external ignore : 'a -> unit = "%ignore"
external int_of_char : char -> int = "%identity"
external char_of_int : int -> char = "%identity"
external ( ^ ) : string -> string -> string = "ml_concat"
external string_of_int : int -> string = "ml_string_of_int"
external print_string : string -> unit = "ml_print_string"
external print_char : char -> unit = "ml_print_char"
external print_newline : unit -> unit = "ml_print_newline"
external exit : int -> 'a = "ml_exit"

(* (a string's length and bytes, for int_of_string_opt: String is a
 * module after this one, and s.[i] is String.get) *)
external stdlib_length : string -> int = "ml_string_length"
external stdlib_get : string -> int -> char = "ml_string_get"

type 'a option = None | Some of 'a
exception Match_failure
exception Not_found
exception Failure of string
exception Invalid_argument of string
exception Exit

let failwith s = raise (Failure s)
let invalid_arg s = raise (Invalid_argument s)
let print_int n = print_string (string_of_int n)
let print_endline s = print_string s; print_char '\n'
let incr r = r := !r + 1
let decr r = r := !r - 1
let succ n = n + 1
let pred n = n - 1
let abs n = if n < 0 then - n else n
let min a b = if a <= b then a else b
let max a b = if a >= b then a else b
let ( |> ) x f = f x
let rec ( @ ) l1 l2 = match l1 with [] -> l2 | x :: l -> x :: (l @ l2)

(* a decimal number, with its sign; OCaml's reads 0x1f and 1_000 too *)
let int_of_string_opt s =
  let n = stdlib_length s in
  let digit i = let c = stdlib_get s i in c >= '0' && c <= '9' in
  let rec go i acc = if i >= n then Some acc else if digit i then go (i + 1) (acc * 10 + int_of_char (stdlib_get s i) - 48) else None in
  if n > 1 && stdlib_get s 0 = '-' then (match go 1 0 with Some v -> Some (- v) | None -> None) else if n = 0 then None else go 0 0
