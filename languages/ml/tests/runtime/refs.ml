(* refs a function keeps in its slots (Opti's refs, at -O) and refs
 * that stay blocks: captured by a function, passed, returned, in a
 * structure; each read, set, incremented, in a loop and in a handler.
 * The same answers both ways (-O3 and -O0) *)

let bump (r : int ref) : unit = r := !r + 10

let () =
  (* in a slot: a loop's int and float, incr and decr *)
  let n = ref 0 and x = ref 0.5 in
  for i = 1 to 10 do
    incr n;
    x := !x *. 1.5 +. float_of_int i
  done;
  decr n;
  Printf.printf "%d %.3f\n" !n !x;
  (* in a slot: set in a handler, read after it *)
  let k = ref 1 in
  (try
     for i = 1 to 5 do
       k := !k * 3;
       if i = 4 then raise Exit
     done
   with Exit -> k := !k + 1);
  Printf.printf "%d\n" !k;
  (* in a slot, with its type said; a function in it, applied *)
  let (s : string ref) = ref "a" in
  let f = ref (fun (y : int) -> y + 1) in
  for _i = 1 to 3 do
    s := !s ^ "b"
  done;
  f := (fun (y : int) -> y * 2);
  Printf.printf "%s %d\n" !s (!f 21);
  (* a block: captured by a function *)
  let c = ref 0 in
  let add (d : int) : unit = c := !c + d in
  List.iter add [ 1; 2; 3 ];
  Printf.printf "%d\n" !c;
  (* a block: passed, and returned in a pair *)
  let p = ref 5 in
  bump p;
  bump p;
  let pair = (p, 1) in
  incr (fst pair);
  Printf.printf "%d\n" !p;
  (* a block: in a list, and as the value of the let itself *)
  let q = ref 7 in
  let rs = [ q; ref 8 ] in
  List.iter incr rs;
  Printf.printf "%d %d\n" !q (List.fold_left (fun a r -> a + !r) 0 rs);
  (* a slot of a loop's body, made again at each turn *)
  let total = ref 0 in
  for i = 1 to 4 do
    let t = ref i in
    while !t > 0 do
      total := !total + !t;
      decr t
    done
  done;
  Printf.printf "%d\n" !total;
  (* (:=) given its ref alone: a block *)
  let z = ref 0 in
  let set = ( := ) z in
  set 42;
  Printf.printf "%d\n" !z
