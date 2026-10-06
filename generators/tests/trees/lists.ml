(* the rules that are menhir's standard ones (list(x), x?, x+...): each
 * with none, one and several elements *)
type t = A
type u = A | B of int | C of int * string * t and 'a v = | D of 'a and ('a, 'b) w = W of ('a * 'b) and x
type r = { a : int; mutable b : string; c : t } and s = r = { a : int; mutable b : string; c : t; }
type e = u = | A | B of int | C of int * string * t
type d = { n : int } [@@deriving show]
type f = F and g = G [@@deriving show eq ord]
type h = H [@@deriving]
external one : int -> int = "one"
external three : int -> int -> int = "three_byte" "three" "noalloc"
let f x = x and g x y = f x y and h = 1
let rec even n = n = 0 || odd (n - 1) and odd n = n <> 0 && even (n - 1)
let caps (c : < >) (d : < Cap.stdout >) (e : < Cap.stdout; Cap.stdin; .. >) = c, d, e
let apply f a b c = f a (f b) ~l:c ~c !a [ a; b; ] [| a; b |] { a; b; }
let nested x = match x with 1 -> (match x with 2 -> 3 | _ -> 4) | 5 -> (function | 6 -> 7 | _ -> 8) x | _ -> (try 9 with Not_found -> 10 | Exit -> 11)
let local = let a = 1 and b = 2 and c = 3 in a + b + c
module M : sig type t val x : t;; val y : t type u = t and v = u end = struct type t = int let x = 1 let y = 2 type u = t and v = u end
