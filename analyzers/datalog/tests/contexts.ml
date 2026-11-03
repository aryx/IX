(* The same questions for ML: a function is a value, every call a call
 * through a variable. The answers in contexts_ml.out; run.sh asks. *)
let inc n = n + 1
let dec n = n - 1

(* 1: which function is a? *)
let id x = x
let a = id inc
let b = id dec
let ra = a 1
let rb = b 2

(* 2: two levels of it: f is given to id from one place in twice *)
let twice f = id f
let c = twice inc
let d = twice dec
let rc = c 1
let rd = d 2

(* 3: a pair, by its object *)
let p = (inc, 1)
let q = (dec, 2)
let (pf, _) = p
let (qf, _) = q
let rp = pf 1
let rq = qf 2

(* 4: a wrapper of a block; a's field by the object that holds it *)
type box = { fn : int -> int }
let make f = { fn = f }
let b1 = make inc
let b2 = make dec
let f1 = b1.fn
let f2 = b2.fn
let r1 = f1 1
let r2 = f2 2

(* 5: a list given to a function, the elements held by their list *)
let hd l = match l with x :: _ -> x | [] -> inc
let l1 = inc :: []
let l2 = dec :: []
let h1 = hd l1
let h2 = hd l2
let rh1 = h1 1
let rh2 = h2 2

(* 6: a function's second argument, of a function given an object first *)
let second box f = ignore box; f
let e = second b1 inc
let g = second b2 dec
let re = e 1
let rg = g 2
