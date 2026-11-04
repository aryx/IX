(* d22c56e4^, languages/ml/ssa/Unbox.ml: a double's box sunk to the block
 * that reads it, the reads walked by Hashtbl.iter: a block's boxes came
 * in the order of the hash function of the stdlib that built mini-ml
 * (OCaml's, lib_core's), the fixed point's programs not the same *)
let reads : (int, int list) Hashtbl.t = Hashtbl.create 16
let starts : int list array = Array.make 4 []

let sink () =
  Hashtbl.iter
    (fun (x : int) (blocks : int list) ->
      match blocks with b :: _ -> starts.(b) <- x :: starts.(b) | [] -> ())
    reads

let emit (out : out_channel) : unit =
  Array.iter
    (fun (l : int list) -> List.iter (fun x -> output_string out (string_of_int x)) l)
    starts

let () =
  Hashtbl.replace reads 1 [ 2 ];
  sink ();
  emit stdout
