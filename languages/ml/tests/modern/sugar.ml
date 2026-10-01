(* what the parser rewrites into ocaml-light's dialect: record punning,
 * { x; _ }, {| |} strings, \x escapes, match ... | exception, _ in a type *)

type point = { x : int; y : int; name : string }

exception Too_big of int

let check n = if n > 100 then raise (Too_big n) else n

(* the value's clause runs outside the handler: its exception escapes *)
let classify n =
  match check n with
  | 0 -> "zero"
  | v when v < 0 -> raise Not_found
  | v -> string_of_int v
  | exception Too_big v -> "too big: " ^ string_of_int v

let first (l : _ list) = match l with [] -> 0 | v :: _ -> v

let () =
  let x = 1 and y = 2 and name = "p" in
  let p = { x; y; name } in
  let { x; name; _ } = p in
  print_int x; print_string name; print_newline ();
  (match p with { y; _ } -> print_int y; print_newline ());
  let q = { p with x; name = "q" } in
  print_string q.name; print_int q.y; print_newline ();
  print_string {|a "quoted" \n string|}; print_newline ();
  print_string {id|with |} inside|id}; print_newline ();
  print_int (Char.code '\x41'); print_string "\x42\x43"; print_newline ();
  List.iter (fun n -> print_string (classify n); print_newline ()) [ 0; 7; 500 ];
  (try print_string (classify (-1)) with Not_found -> print_string "escaped"); print_newline ();
  print_int (first [ 3; 4 ]); print_newline ()
