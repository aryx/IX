(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyLibCore, the core library of tiny-ml's programs (the kernel,
 * tiny-windows, the applications), in tiny-ml's ML. It is a prelude:
 * the compiler reads it before the program's own files, so a program
 * names nothing to have it; TinyLibDraw, TinyLibPlayground and
 * TinyLibGUI are the libraries a program asks for, files given to
 * tiny-ml before its own. The operators and the few functions that are
 * the machine's or the runtime's (core.c), as externals; the option
 * and the exceptions the runtime raises, in the order it numbers them;
 * then the Pervasives and List functions, as a program would find
 * them in ocaml-light's stdlib, written in ML. A name with a dot
 * (List.map) is one name: tiny-ml has no modules.
 *
 * Not OCaml's to compile, and not looked for when tiny-ml runs: the
 * build puts this file's text in the compiler (tiny/dune's rule and
 * tiny/mkfile's make TinyMLPrelude.ml of it; no .mli beside it, which
 * OCaml would have to check), which reads it before
 * the program's files and adds max_int and min_int, the target's. *)
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
external Char.code : char -> int = "%identity"
external Char.chr : int -> char = "%identity"
external ( ^ ) : string -> string -> string = "ml_concat"
external string_of_int : int -> string = "ml_string_of_int"
external print_string : string -> unit = "ml_print_string"
external print_char : char -> unit = "ml_print_char"
external print_newline : unit -> unit = "ml_print_newline"
external exit : int -> 'a = "ml_exit"
external String.length : string -> int = "ml_string_length"
external String.get : string -> int -> char = "ml_string_get"
external String.make : int -> char -> string = "ml_string_make"
external Array.make : int -> 'a -> 'a array = "ml_array_make"
external Array.length : 'a array -> int = "ml_array_length"
external Array.get : 'a array -> int -> 'a = "ml_array_get"
external Array.set : 'a array -> int -> 'a -> unit = "ml_array_set"
external ml_string_sub : string -> int -> int -> string = "ml_string_sub"
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
let String.sub s ofs len =
  if ofs < 0 || len < 0 || ofs > String.length s - len then invalid_arg "String.sub" else ml_string_sub s ofs len
let rec ( @ ) l1 l2 = match l1 with [] -> l2 | x :: l -> x :: (l @ l2)
let List.length l = let rec len n = function [] -> n | _ :: l -> len (n + 1) l in len 0 l
let List.rev l = let rec rev acc = function [] -> acc | x :: l -> rev (x :: acc) l in rev [] l
let List.hd = function [] -> failwith "hd" | x :: _ -> x
let List.tl = function [] -> failwith "tl" | _ :: l -> l
let rec List.nth l n = match l with [] -> failwith "nth" | x :: l -> if n = 0 then x else List.nth l (n - 1)
let rec List.map f = function [] -> [] | x :: l -> let y = f x in y :: List.map f l
let rec List.iter f = function [] -> () | x :: l -> f x; List.iter f l
let List.iteri f l = let rec go i = function [] -> () | x :: l -> f i x; go (i + 1) l in go 0 l
let rec List.fold_left f acc = function [] -> acc | x :: l -> List.fold_left f (f acc x) l
let rec List.fold_right f l acc = match l with [] -> acc | x :: l -> f x (List.fold_right f l acc)
let rec List.mem x = function [] -> false | y :: l -> x = y || List.mem x l
let rec List.assoc x = function [] -> raise Not_found | (a, b) :: l -> if a = x then b else List.assoc x l
let rec List.exists p = function [] -> false | x :: l -> p x || List.exists p l
let rec List.for_all p = function [] -> true | x :: l -> p x && List.for_all p l
let List.filter p l =
  let rec find acc = function [] -> List.rev acc | x :: l -> if p x then find (x :: acc) l else find acc l in
  find [] l
let rec List.concat = function [] -> [] | l :: r -> l @ List.concat r
