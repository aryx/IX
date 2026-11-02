(* the program: every way Kit's functions are reached *)
let total : int ref = ref 0

let run_all (x : int) : unit =
  let rec go (hs : Kit.handler list) : unit =
    match hs with [] -> () | h :: rest -> total := !total + h.run x; go rest in
  go Kit.handlers

let () =
  run_all 3;
  Kit.iter (fun (x : int) -> total := !total + !Kit.current x) [ 1; 2 ];
  total := Kit.fold Kit.add !total [ 4; 5 ];
  let half : int -> int = Kit.scale 2 in
  ignore half;
  (try ignore (Kit.last 1) with Kit.Stop f -> total := f !total);
  print_int !total
