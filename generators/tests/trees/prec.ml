(* precedences and associativities, each against its neighbours *)
let a = 1 + 2 * 3 - 4 / 5 mod 6 ** 7 ** 8 lsl 9 land 10
let b = x :: y :: z @ w ^ v, f x y :: g, - a - - b, -. c *. d, not a && b || c & d or e
let c = if a then b; c else d; e
let d = fun x -> x, y | _ -> match z with A -> 1 | B -> fun w -> 2 | C -> try 3 with E -> 4 | F -> 5
let e = a := b <- c := !d.e.(f) <- g, h; i
let f = let x = 1 in x; let y = 2 in y, z as w
let g = (a : int -> int * string list -> (unit, 'a) t) :: f ~x:1 ~y (z : int) ! w
type t = A of int * (int -> int) | B of { x : int; mutable y : t list } | C and u = t * t -> t option
let h = a.(i).[j] <- b.c <- d; M.(x + N.y).z; [| 1; 2 |].(0); { r with a = 1; b }
let i = function A | B -> 1 | C x when x > 0 -> 2 | D (_, _) as d -> 3 | _ -> 4
