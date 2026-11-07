(* x |> List.iter f, the call List.iter f x: a table's bindings written
 * in its order, through a pipe, still found *)
let seen : (string, int) Hashtbl.t = Hashtbl.create 16

let dump () =
  Hashtbl.fold (fun k _ acc -> k :: acc) seen []
  |> List.iter (fun (k : string) -> print_string k)

let () =
  Hashtbl.replace seen "a" 1;
  dump ()
