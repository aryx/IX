(* mlpp's a |! b (pp/Pp): an option's value, or else b, evaluated only
 * when there is none; and let*, mini-ml's own (OCaml's binding
 * operators), for options in sequence *)

exception Missing of string

let table = [ "one", 1; "two", 2; "three", 3 ]
let find k = List.assoc_opt k table

let calls = ref 0
let default () = incr calls; 0

let () =
  (* the value; the right side is not evaluated *)
  let two = find "two" |! default () in
  Printf.printf "%d, %d call\n" two !calls;
  (* none: the right side, once *)
  let four = find "four" |! default () in
  Printf.printf "%d, %d call\n" four !calls;
  (* an error, the usual right side *)
  (match find "five" |! raise (Missing "five") with
   | n -> Printf.printf "%d\n" n
   | exception Missing k -> Printf.printf "missing %s\n" k);
  (* an application on the left, an arithmetic expression around *)
  Printf.printf "%d\n" (1 + (List.assoc_opt "three" table |! failwith "no three") * 2);
  (* one inside another's right side *)
  Printf.printf "%d\n" (find "none" |! (find "one" |! 0));
  (* another construct in its right side (not the other way: a [%list]'s
   * parts are copied as they are) *)
  print_endline (String.concat " " (List.assoc_opt "names" [] |! [%list k || k <- List.map fst table; k <> "two"]))

(* options in sequence, by a let* defined here: None as soon as one is *)
let ( let* ) = Option.bind

let sum a b =
  let* x = find a in
  let* y = find b in
  Some (x + y)

let show = function Some n -> string_of_int n | None -> "none"

let () =
  print_endline (show (sum "one" "two"));
  print_endline (show (sum "one" "ten"));
  (* a let* that fails instead: the same error for every step *)
  let ( let* ) o f = match o with Some x -> f x | None -> raise (Missing "a key") in
  let total a b = let* x = find a in let* y = find b in x * y in
  Printf.printf "%d\n" (total "two" "three");
  (match total "two" "eleven" with n -> Printf.printf "%d\n" n | exception Missing m -> Printf.printf "missing %s\n" m)
