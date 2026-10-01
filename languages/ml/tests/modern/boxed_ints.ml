(* int32 and int64: the literals 3l and 3L, the types' names, the
 * stdlib's Int32 and Int64 over the runtime's boxed integers: their
 * arithmetic (wrapping), order, equality, hashing, patterns, text *)

let show64 (n : int64) = Int64.to_string n
let show32 (n : int32) = Int32.to_string n
let line s = print_string s; print_newline ()

let kind = function
  | 0L -> "zero"
  | 1L | -1L -> "unit"
  | 0x7fffffffffffffffL -> "max"
  | n when n < 0L -> "negative"
  | _ -> "positive"

let kind32 (n : int32) = match n with 0l -> "zero" | -1l -> "minus one" | _ -> "other"

let () =
  (* a constant wider than an int, and the arithmetic's wrap *)
  let big = 0x7fffffffffffffffL in
  line (show64 big);
  line (show64 (Int64.add big 1L));
  line (show64 (Int64.mul 0x100000000L 0x100000000L));
  line (show64 (Int64.sub 0L 0xffffffffL));
  line (show64 0xffffffffffffffffL);
  line (show64 (Int64.div (-7L) 2L) ^ " " ^ show64 (Int64.rem (-7L) 2L));
  (* bits *)
  line (Int64.format "%x" (Int64.logor (Int64.shift_left 0xabcdL 48) 0x1234L));
  line (Int64.format "%x" (Int64.shift_right (-256L) 4) ^ " " ^ Int64.format "%x" (Int64.shift_right_logical (-256L) 60));
  line (Int64.format "%x" (Int64.logxor (Int64.logand 0xff00ff00L 0x0ff00ff0L) (-1L)));
  (* conversions *)
  line (string_of_int (Int64.to_int (Int64.of_int 123456789)) ^ " " ^ show64 (Int64.of_string "-0x10"));
  line (show64 (Int64.of_int32 (-5l)) ^ " " ^ show32 (Int64.to_int32 0x1ffffffffL));
  (* order, equality, patterns *)
  line (String.concat " " (List.map kind [ 0L; 1L; -1L; big; -5L; 42L ]));
  line (string_of_bool (0x10L = Int64.of_int 16) ^ " " ^ string_of_bool (3L < 2L) ^ " " ^ string_of_int (compare (-1L) 1L));
  line (show64 (List.fold_left max 0L [ 3L; 0x100000000L; -9L ]));
  (* a table's keys *)
  let t = Hashtbl.create 7 in
  List.iter (fun (k, v) -> Hashtbl.replace t k v) [ 1L, "one"; 0x100000000L, "big"; 1L, "uno" ];
  line (Hashtbl.find t (Int64.of_int 1) ^ " " ^ Hashtbl.find t (Int64.shift_left 1L 32));
  (* int32 *)
  line (show32 (Int32.add 0x7fffffffl 1l) ^ " " ^ show32 (Int32.mul 0x10000l 0x10000l) ^ " " ^ show32 0xffffffffl);
  line (Int32.format "%x" (Int32.shift_right_logical (-1l) 28) ^ " " ^ show32 (Int32.shift_right (-256l) 4));
  line (String.concat " " (List.map kind32 [ 0l; -1l; 7l ]) ^ " " ^ string_of_bool (Int32.of_int 7 = 7l));
  (try line (show64 (Int64.div 1L 0L)) with Division_by_zero -> line "Division_by_zero");
  (try line (show32 (Int32.rem 1l 0l)) with Division_by_zero -> line "Division_by_zero")
