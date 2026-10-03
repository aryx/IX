(* mlpp: the types are the .mli's *)
type point = _

(* the derived printers call it *)
let pp_point fmt p = Format.pp_print_string fmt (Printf.sprintf "(%d, %d)" p.x p.y)

type 'a shape = _ [@@deriving show]
type t = _ [@@deriving show]

let rec area = function
  | Dot _ -> 0
  | Circle (_, r) -> 3 * r * r
  | Group (_, l) -> List.fold_left (fun n s -> n + area s) 0 l
  | Tagged (_, s) -> (match s with Some s -> area s | None -> 0)

let () =
  let s = Group ("g", [ Dot { x = 1; y = 2 }; Circle ({ x = 0; y = 0 }, 2); Tagged (7, Some (Dot { x = 3; y = 4 })) ]) in
  print_endline (show_shape Format.pp_print_int s);
  print_endline (show (Shapes [ s; Tagged (0, None) ]));
  print_endline (show Nothing);
  Printf.printf "%d\n" (area s)
