(* 410d04a2, its fix: the places sorted, Marshal with No_sharing *)
let places : (string, int) Hashtbl.t = Hashtbl.create 16

let summary () : string =
  let l = Hashtbl.fold (fun g base acc -> (g, base) :: acc) places [] in
  Marshal.to_string (List.sort compare l) [ Marshal.No_sharing ]

let () = Hashtbl.replace places "x" 1; print_string (summary ())
