(* allocation: lists made and mapped, the collector's work *)
let rec make n acc = if n = 0 then acc else make (n - 1) (n :: acc)

let rec sum l acc = match l with [] -> acc | x :: r -> sum r (acc + x)

let () =
  let l = ref (make 10000 []) in
  for i = 1 to 20 do l := List.map (fun x -> x + 1) !l done;
  print_int (sum !l 0); print_newline ()
