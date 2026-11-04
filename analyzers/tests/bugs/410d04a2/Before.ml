(* 410d04a2^, languages/ml/Typing.ml and simple/Summary.ml: a unit's
 * places, a Hashtbl.fold into a list, marshalled in its summary
 * (X.inline) without No_sharing: the bytes not the same by mini-ml built
 * by OCaml and by ix (the table's order its hash's, the sharing the
 * compiler's) *)
let places : (string, int) Hashtbl.t = Hashtbl.create 16

let summary () : string =
  Marshal.to_string (Hashtbl.fold (fun g base acc -> (g, base) :: acc) places []) []

let () = Hashtbl.replace places "x" 1; print_string (summary ())
