(* exceptions: a class of System.Exception's each; raise and try, the
   handler's cases tried on what was caught, the others thrown again;
   failwith's Failure, Not_found, a division by zero *)
exception Stop of string * int
exception Empty_stack

let check n = if n > 3 then raise (Stop ("too big", n)) else n * 10

let safe n =
  try check n with
  | Stop (why, k) -> print_string (why ^ ": " ^ string_of_int k ^ "; "); -1

let divide a b = try a / b with Division_by_zero -> print_string "by zero; "; 0

let rec digit_from s i =
  if i >= String.length s then raise Not_found
  else if s.[i] >= '0' && s.[i] <= '9' then i
  else digit_from s (i + 1)

let first_digit s = digit_from s 0

let inner () = try raise Empty_stack with Not_found -> print_endline "not this one"

let () =
  print_int (safe 2); print_newline ();
  print_int (safe 7); print_newline ();
  print_int (divide 7 2); print_newline ();
  print_int (divide 7 0); print_newline ();
  (try print_int (first_digit "abc4d") with Not_found -> print_string "none");
  print_newline ();
  (try print_int (first_digit "abcd") with Not_found -> print_string "none");
  print_newline ();
  (try failwith "boom" with Failure m -> print_endline ("failed: " ^ m));
  (try inner () with Empty_stack -> print_endline "through the inner handler");
  let r = try check 1 with Stop _ -> 0 in
  print_int r; print_newline ()

(* a try inside an operand (values on IL's stack, where a try starts
 * with none): its own method, what it names its arguments *)
let () =
  let base = 40 in
  let n = base + (try int_of_string "x" with Failure _ -> 2) in
  print_int (n + (try List.assoc 3 [ (3, 0) ] with Not_found -> 9)); print_newline ()
