(* expected: File "body.ml", line 9, characters 14-18 *)
(* a type error in the body of a [%bits] clause: OCaml must name this
 * file's line and column, not the rewritten text's *)
type i = Mul of int * int | Undefined

let decode w =
  match w with
  | [%bits "c:4 0000 0000 rd:4 _:8 1001 rm:4"] ->
      Mul (c, "rd")
  | _ -> Undefined
