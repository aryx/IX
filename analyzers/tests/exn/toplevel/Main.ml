(* exceptions.dl's test: which exceptions may escape the toplevel *)

exception Parse_error of string
exception Empty
exception Quiet
exception Late

(* raises Parse_error, nothing catches it on the way to the toplevel *)
let parse (s : string) : int = if s = "" then raise (Parse_error s) else String.length s

(* raises Empty, caught by its caller *)
let first (l : int list) : int = match l with x :: _ -> x | [] -> raise Empty

let safe_first (l : int list) : int = try first l with Empty -> 0

(* Quiet, caught by a catch-all, raised again: escapes *)
let again () : unit = try raise Quiet with e -> print_string "again\n"; raise e

(* a nested try: the inner one lets Not_found through, the outer catches it *)
let nested () : int = try (try List.assoc "x" [] with Empty -> 1) with Not_found -> 2

(* a guard catches nothing for sure: Empty may escape *)
let guarded (b : bool) : int = try first [] with Empty when b -> 0

(* a function made inside a try runs outside it: Late escapes *)
let later () : unit -> unit = try fun () -> raise Late with Late -> fun () -> ()

(* through a function value *)
let apply (f : int list -> int) : int = f []

let () =
  print_int (parse "abc");
  print_int (safe_first []);
  again ();
  print_int (nested ());
  print_int (guarded true);
  later () ();
  print_int (apply first)
