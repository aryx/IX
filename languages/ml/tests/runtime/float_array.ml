(* Float.Array, its floats in the block (the runtime's Double_array_tag):
 * each function, the bounds checked, compared, marshalled (OCaml's
 * bytes), and many made while the collector runs; read and written in
 * a loop, where ssa's Unbox keeps them doubles *)

let show (a : Float.Array.t) : unit =
  Float.Array.iter (fun (x : float) -> Printf.printf " %g" x) a;
  print_newline ()

(* ys's floats, each time more of xs's: the doubles loaded and stored
 * (no handler in this function, so Unbox's) *)
let accumulate (xs : Float.Array.t) (ys : Float.Array.t) : unit =
  for i = 0 to Float.Array.length xs - 1 do
    Float.Array.unsafe_set ys i ((Float.Array.unsafe_get xs i *. 0.5) +. Float.Array.unsafe_get ys i)
  done

let () =
  let a = Float.Array.make 5 1.5 in
  Float.Array.set a 2 (-0.25);
  Printf.printf "%d %g %g\n" (Float.Array.length a) (Float.Array.get a 0) (Float.Array.get a 2);
  show a;
  let b = Float.Array.init 8 (fun (i : int) -> float_of_int (i * i) /. 2.) in
  show b;
  (* overlapping, both ways *)
  Float.Array.blit b 0 b 2 5;
  show b;
  Float.Array.blit b 3 b 1 4;
  show b;
  let c = Float.Array.copy b in
  Float.Array.fill c 1 3 9.;
  show c;
  show b;
  Printf.printf "%g\n" (Float.Array.fold_left ( +. ) 0. c);
  let l = Float.Array.to_list (Float.Array.of_list [ 3.; 1.; 4.; 1.; 5. ]) in
  List.iter (fun (x : float) -> Printf.printf " %g" x) l;
  print_newline ();
  Printf.printf "%d\n" (Float.Array.length (Float.Array.create 0));
  (* the bounds *)
  (try ignore (Float.Array.get a 5) with Invalid_argument m -> print_endline m);
  (try Float.Array.set a (-1) 0. with Invalid_argument m -> print_endline m);
  (try Float.Array.fill a 3 4 0. with Invalid_argument m -> print_endline m);
  (* compared *)
  let d = Float.Array.copy a in
  Printf.printf "%b %b %d %d\n" (a = d) (a = b) (compare a d) (compare (Float.Array.make 2 1.) (Float.Array.make 2 2.));
  (* marshalled: OCaml's bytes, and back *)
  let m = Marshal.to_string (Float.Array.of_list [ 1.; -2.5; 1e10 ], 7) [] in
  String.iter (fun (ch : char) -> Printf.printf "%02x" (Char.code ch)) m;
  print_newline ();
  let ((e, k) : Float.Array.t * int) = Marshal.from_string m 0 in
  Printf.printf "%d" k;
  show e;
  (* a loop's floats, with the collector running: each turn a list made *)
  let n = 1000 in
  let xs = Float.Array.init n (fun (i : int) -> float_of_int i) in
  let ys = Float.Array.make n 0. in
  let junk = ref [] in
  for turn = 1 to 50 do
    accumulate xs ys;
    junk := List.init 100 (fun (i : int) -> float_of_int (i + turn)) :: (if turn mod 10 = 0 then [] else !junk)
  done;
  Printf.printf "%g %g %d\n" (Float.Array.get ys 1) (Float.Array.fold_left ( +. ) 0. ys) (List.length !junk)
