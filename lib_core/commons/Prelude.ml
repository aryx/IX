(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Prelude.mli *)

(* OCaml's polymorphic order and equality, before compare and == are
 * the classes': what the instances at the predefined types are made of *)
let order = compare

type 'a show = [%mli] [@@class]
type 'a eq = [%mli] [@@class]
type 'a ord = [%mli] [@@class]

(*****************************************************************************)
(* Show *)
(*****************************************************************************)

let show_int : int show = { show = string_of_int } [@@instance]
let show_bool : bool show = { show = string_of_bool } [@@instance]
let show_char : char show = { show = (fun c -> "'" ^ Char.escaped c ^ "'") } [@@instance]
let show_string : string show = { show = (fun s -> "\"" ^ String.escaped s ^ "\"") } [@@instance]
let show_float : float show = { show = string_of_float } [@@instance]
let show_unit : unit show = { show = (fun () -> "()") } [@@instance]
let show_int64 : int64 show = { show = (fun n -> Int64.to_string n ^ "L") } [@@instance]

let show_list [%using: 'a show] : 'a list show =
  { show = (fun xs -> "[" ^ String.concat "; " (List.map show xs) ^ "]") }
[@@instance]

let show_array [%using: 'a show] : 'a array show =
  { show = (fun xs -> "[|" ^ String.concat "; " (List.map show (Array.to_list xs)) ^ "|]") }
[@@instance]

(* a constructor's argument: in parentheses when it is several words, or negative *)
let argument s = if String.contains s ' ' || (s <> "" && s.[0] = '-') then "(" ^ s ^ ")" else s

let show_option [%using: 'a show] : 'a option show =
  { show = (function None -> "None" | Some x -> "Some " ^ argument (show x)) }
[@@instance]

let show_pair [%using: 'a show] [%using: 'b show] : ('a * 'b) show =
  { show = (fun (a, b) -> "(" ^ show a ^ ", " ^ show b ^ ")") }
[@@instance]

let show_triple [%using: 'a show] [%using: 'b show] [%using: 'c show] : ('a * 'b * 'c) show =
  { show = (fun (a, b, c) -> "(" ^ show a ^ ", " ^ show b ^ ", " ^ show c ^ ")") }
[@@instance]

(*****************************************************************************)
(* Eq *)
(*****************************************************************************)

let eq_int : int eq = { equal = (fun (a : int) b -> a = b) } [@@instance]
let eq_bool : bool eq = { equal = (fun (a : bool) b -> a = b) } [@@instance]
let eq_char : char eq = { equal = (fun (a : char) b -> a = b) } [@@instance]
let eq_string : string eq = { equal = (fun (a : string) b -> a = b) } [@@instance]
let eq_float : float eq = { equal = (fun (a : float) b -> a = b) } [@@instance]
let eq_unit : unit eq = { equal = (fun () () -> true) } [@@instance]
let eq_int64 : int64 eq = { equal = (fun (a : int64) b -> a = b) } [@@instance]

(* rec: equal, at the rest of the list, is this instance *)
let rec eq_list [%using: 'a eq] : 'a list eq =
  { equal = (fun xs ys -> match xs, ys with [], [] -> true | x :: xs, y :: ys -> equal x y && equal xs ys | _ -> false) }
[@@instance]

let eq_array [%using: 'a eq] : 'a array eq =
  { equal = (fun xs ys -> equal (Array.to_list xs) (Array.to_list ys)) }
[@@instance]

let eq_option [%using: 'a eq] : 'a option eq =
  { equal = (fun a b -> match a, b with None, None -> true | Some x, Some y -> equal x y | _ -> false) }
[@@instance]

let eq_pair [%using: 'a eq] [%using: 'b eq] : ('a * 'b) eq =
  { equal = (fun (a, b) (a', b') -> equal a a' && equal b b') }
[@@instance]

let eq_triple [%using: 'a eq] [%using: 'b eq] [%using: 'c eq] : ('a * 'b * 'c) eq =
  { equal = (fun (a, b, c) (a', b', c') -> equal a a' && equal b b' && equal c c') }
[@@instance]

let ( == ) [%using: 'a eq] (a : 'a) (b : 'a) = equal a b
let ( /= ) [%using: 'a eq] (a : 'a) (b : 'a) = not (equal a b)
let ( != ) [%using: 'a eq] (a : 'a) (b : 'a) = not (equal a b)

(*****************************************************************************)
(* Ord *)
(*****************************************************************************)

let ord_int : int ord = { compare = (fun (a : int) b -> order a b) } [@@instance]
let ord_bool : bool ord = { compare = (fun (a : bool) b -> order a b) } [@@instance]
let ord_char : char ord = { compare = (fun (a : char) b -> order a b) } [@@instance]
let ord_string : string ord = { compare = (fun (a : string) b -> order a b) } [@@instance]
let ord_float : float ord = { compare = (fun (a : float) b -> order a b) } [@@instance]
let ord_unit : unit ord = { compare = (fun () () -> 0) } [@@instance]
let ord_int64 : int64 ord = { compare = (fun (a : int64) b -> order a b) } [@@instance]

let rec ord_list [%using: 'a ord] : 'a list ord =
  { compare =
      (fun xs ys ->
        match xs, ys with
        | [], [] -> 0
        | [], _ -> -1
        | _, [] -> 1
        | x :: xs, y :: ys -> (match compare x y with 0 -> compare xs ys | c -> c)) }
[@@instance]

let ord_option [%using: 'a ord] : 'a option ord =
  { compare = (fun a b -> match a, b with None, None -> 0 | None, _ -> -1 | _, None -> 1 | Some x, Some y -> compare x y) }
[@@instance]

let ord_pair [%using: 'a ord] [%using: 'b ord] : ('a * 'b) ord =
  { compare = (fun (a, b) (a', b') -> match compare a a' with 0 -> compare b b' | c -> c) }
[@@instance]

let ord_triple [%using: 'a ord] [%using: 'b ord] [%using: 'c ord] : ('a * 'b * 'c) ord =
  { compare = (fun (a, b, c) (a', b', c') -> match compare a a' with 0 -> compare (b, c) (b', c') | c -> c) }
[@@instance]

let sort [%using: 'a ord] (xs : 'a list) = List.sort compare xs

let maximum [%using: 'a ord] (xs : 'a list) =
  match xs with
  | [] -> invalid_arg "Prelude.maximum: an empty list"
  | x :: rest -> List.fold_left (fun m y -> if compare y m > 0 then y else m) x rest

let minimum [%using: 'a ord] (xs : 'a list) =
  match xs with
  | [] -> invalid_arg "Prelude.minimum: an empty list"
  | x :: rest -> List.fold_left (fun m y -> if compare y m < 0 then y else m) x rest
