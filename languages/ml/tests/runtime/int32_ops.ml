(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Int32's operations in place (Lower.ints_in_place, Emit): each of
 * add, sub, mul, neg, and, or, xor and the three shifts on values at
 * the bounds (wrap, the sign, a logical shift of a negative), of_int
 * and to_int within 30 bits (an int's on arm), in a loop that keeps
 * them in blocks and makes more (the collector runs, ML_HEAP=64);
 * printed by %ld *)

let values = [ 0l; 1l; -1l; 7l; -12345l; 0x7fffffffl; 0x80000000l; 0x12345678l; 0xdeadbeefl ]

let () =
  List.iter (fun a ->
    List.iter (fun b ->
      Printf.printf "%ld %ld: %ld %ld %ld %ld %ld %ld\n" a b (Int32.add a b) (Int32.sub a b) (Int32.mul a b)
        (Int32.logand a b) (Int32.logor a b) (Int32.logxor a b)) values;
    Printf.printf "%ld: neg %ld not %ld" a (Int32.neg a) (Int32.lognot a);
    List.iter (fun k ->
      Printf.printf " <<%d %ld >>%d %ld >>>%d %ld" k (Int32.shift_left a k) k (Int32.shift_right a k) k
        (Int32.shift_right_logical a k)) [ 0; 1; 7; 16; 31 ];
    print_newline ()) values;
  List.iter (fun n -> Printf.printf "of_int %d %ld to_int %d\n" n (Int32.of_int n) (Int32.to_int (Int32.of_int n)))
    [ 0; 1; -1; 1000000; -1000000; 0x3fffffff; -0x40000000 ];
  (* a hash's loop: the state in int32s, a block each, across turns *)
  let h = ref 0x811c9dc5l and kept = ref [] in
  for i = 0 to 9999 do
    h := Int32.mul (Int32.logxor !h (Int32.of_int (i land 0xff))) 0x01000193l;
    h := Int32.logor (Int32.shift_left !h 5) (Int32.shift_right_logical !h 27);
    if i mod 1000 = 0 then kept := !h :: !kept
  done;
  Printf.printf "hash %ld\n" !h;
  List.iter (fun x -> Printf.printf "kept %ld\n" x) !kept
