(* what mini-cc's front end asked of mini-ml -dotnet (the plan's stage
 * 8 begun): a local function at several types, compare as a value in a
 * polymorphic function, %a %t %h %S %C, |> and @@, a polymorphic
 * toplevel value, constant patterns of int64 and float, a primitive
 * given fewer arguments, a unit matched *)

type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree
let empty = Leaf
let rec add x t = match t with Leaf -> Node (Leaf, x, Leaf) | Node (l, y, r) -> if x < y then Node (add x l, y, r) else Node (l, y, add x r)
let rec elements t = match t with Leaf -> [] | Node (l, x, r) -> elements l @ [ x ] @ elements r

let uniq l = List.sort_uniq compare l

let one_of (n : int) =
  let one l = match l with [] -> None | [ x ] -> Some x | _ -> None in
  (one [ n ], one [ string_of_int n ])

let pp_tree ppf t = Format.fprintf ppf "[%s]" (String.concat ";" (List.map string_of_int (elements t)))

let kind (x : int64) = match x with 0L -> "zero" | 1L -> "one" | _ -> "many"
let fkind (x : float) = match x with 0.5 -> "half" | _ -> "other"

exception Stop

let () =
  print_endline (String.concat " " (elements (add "b" (add "a" empty))));
  print_endline (String.concat " " (List.map string_of_int (elements (add 2 (add 1 empty)))));
  print_endline (String.concat " " (uniq [ "x"; "y"; "x" ]));
  (match one_of 7 with (Some a, Some b) -> Printf.printf "%d %s\n" a b | _ -> print_endline "none");
  Format.printf "tree %a@." pp_tree (add 3 (add 1 empty));
  print_endline (Printf.sprintf "%t|%h|%S|%C" (fun () -> "t") 1.5 "q\"u" 'c');
  [ 1; 2; 3 ] |> List.map (fun x -> x * 10) |> List.iter (Printf.printf "%d ");
  print_newline ();
  print_endline @@ kind 1L ^ " " ^ kind 5L ^ " " ^ fkind 0.5;
  print_endline (String.init 3 (String.get "abcdef"));
  match print_string "unit " with () -> print_endline "matched" | exception Stop -> print_endline "stop"
