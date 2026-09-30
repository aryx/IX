(* expected: File "guard.ml", line 7, characters 57-60 *)
(* a type error in the guard of a [%bits] clause, which the rewrite
 * copies *)
type i = B of int | Undefined

let decode = function
  | [%bits "c:4 101 _:1 off:s24"] when c <> 15 && off <> "0" -> B off
  | _ -> Undefined
