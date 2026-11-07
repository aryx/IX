(* the fix, the keys sorted first; and what must stay quiet: another
 * list walked by |> List.iter and written, in no table's order (old:
 * each l |> List.iter f a closure of List.iter called by the external,
 * Before's write found in List.iter's code, model.ml:List.iter, one walk
 * for all of a program's pipes: in tiny/, TinyMLTypes.opened's keys
 * reached TinyMLMachine's output) *)
let seen : (string, int) Hashtbl.t = Hashtbl.create 16

let dump () =
  Hashtbl.fold (fun k _ acc -> k :: acc) seen []
  |> List.sort compare
  |> List.iter (fun (k : string) -> print_string k)

let code : string list ref = ref []

let emit () = List.rev !code |> List.iter (fun (l : string) -> print_string l)

let () =
  Hashtbl.replace seen "a" 1;
  code := [ "x"; "y" ];
  dump ();
  emit ()
