(* Marshal's time (plan_ml_features.md, 3: Marshal in ML): a value of an
 * object file's shape, 5.7 MB of bytes, written 10 times and read 10
 * times; the seconds on the standard error.
 *   languages/ml/tests/run.sh 7 /tmp/w languages/ml/tests/bench/marshalling.ml
 *   /tmp/w/marshalling
 * (run.sh says FAIL: the seconds are in what it compares) *)
type sym = { name : string; value : int; kind : int; refs : string list }
type obj = { file : string; code : string; syms : sym list; table : (string * int) array }

let make (n : int) : obj =
  let names = Array.init 500 (fun i -> "sym" ^ string_of_int i) in
  { file = "x.o"; code = String.make (n * 20) 'c';
    syms = List.init n (fun i -> { name = names.(i mod 500); value = i * 12345; kind = i mod 7; refs = [ names.((i + 1) mod 500); string_of_int i ] });
    table = Array.init n (fun i -> (names.(i mod 500), i)) }

let () =
  let o = make 100000 in
  let t0 = Sys.time () in
  let s = ref "" in
  for _i = 1 to 10 do s := Marshal.to_string o [] done;
  let t1 = Sys.time () in
  let back = ref o in
  for _i = 1 to 10 do back := Marshal.from_string !s 0 done;
  let t2 = Sys.time () in
  Printf.printf "%d bytes %b\n" (String.length !s) (!back = o);
  Printf.eprintf "write %.2fs read %.2fs\n" (t1 -. t0) (t2 -. t1)
