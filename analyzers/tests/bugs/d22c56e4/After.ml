(* d22c56e4, its fix: the values sorted first; and what must stay quiet:
 * a sum over a table, a table filled from another, a message to stderr.
 * Before's report names this emit too: Array.iter, not modeled, has one
 * closure's l for both, Before's cells in it *)
let reads : (int, int list) Hashtbl.t = Hashtbl.create 16
let starts : int list array = Array.make 4 []

let sink () =
  List.iter
    (fun ((x, blocks) : int * int list) ->
      match blocks with b :: _ -> starts.(b) <- x :: starts.(b) | [] -> ())
    (List.sort compare
       (Hashtbl.fold (fun x blocks acc -> (x, blocks) :: acc) reads []))

let emit (out : out_channel) : unit =
  Array.iter
    (fun (l : int list) -> List.iter (fun x -> output_string out (string_of_int x)) l)
    starts

(* a string built in a Buffer of its own, in the table's order but not
 * written: what is not followed *)
let names () : string =
  let b = Buffer.create 16 in
  Hashtbl.iter (fun x _ -> Buffer.add_string b (string_of_int x)) reads;
  Buffer.contents b

let total () : int =
  Hashtbl.fold (fun _ (l : int list) n -> n + List.length l) reads 0

let copy () : (int, int list) Hashtbl.t =
  let t = Hashtbl.create 16 in
  Hashtbl.iter (fun x l -> Hashtbl.replace t x l) reads;
  t

let warn () = Hashtbl.iter (fun x _ -> prerr_endline (string_of_int x)) reads

let () =
  Hashtbl.replace reads 1 [ 2 ];
  sink ();
  emit stdout;
  ignore (copy ());
  warn ();
  print_string (names () ^ string_of_int (total ()))
