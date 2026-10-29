(* [@@tailrec] where it does not hold: count's call of itself is an
 * operand of +, the addition done after it returns *)
let rec count n = if n = 0 then 0 else 1 + count (n - 1) [@@tailrec]

let () = print_int (count 10)
