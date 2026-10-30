(* the program mini-acid debugs with ix's acid library (debuggers/tests/acid_proc.sh):
 * values of each kind in its globals, printed by their words (port.acid's ml) *)
type shape = Circle of float | Rect of int * int | Empty
type point = { x : int; y : int; name : string }

let n = ref 42
let s = "hello"
let l = [ 1; 2; 3 ]
let p = { x = 1; y = 2; name = "origin" }
let shapes = [ Circle 1.5; Rect (3, 4); Empty ]
let pair = (7, "seven")
let f = fun x -> x + !n
let arr = [| 10; 20 |]
let opt = Some (-5)

let rec down k = if k = 0 then !n + List.length l else 1 + down (k - 1)

let () = print_int (down 2 + f 1 + p.x + Array.length arr)
