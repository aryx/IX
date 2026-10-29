(* [@@zero_alloc] where it does not hold: go captures s, so its closure
 * is made at each call of first_digit (holds.ml's gives s to go) *)
let first_digit (s : string) =
  let rec go i = if i = String.length s then -1 else if s.[i] = '7' then i else go (i + 1) in
  go 0 [@@zero_alloc]

let () = print_int (first_digit "ab7")
