(* int64's arithmetic as OCaml's: division and mod toward zero, the
   shifts, the bits; floats through conversions; comparisons *)
let show s n = print_string s; print_string " "; print_int n; print_newline ()

let big = 1000000 * 1000000

let () =
  show "add" (3 + 4);
  show "sub" (3 - 40);
  show "mul" (-6 * 7);
  show "div" (-7 / 2);
  show "mod" (-7 mod 2);
  show "neg" (- big);
  show "big" big;
  show "lsl" (1 lsl 40);
  show "asr" (-1024 asr 3);
  show "lsr" ((1 lsl 40) lsr 37);
  show "land" (12 land 10);
  show "lor" (12 lor 10);
  show "lxor" (12 lxor 10);
  show "lnot" (lnot 5);
  show "succ" (succ 41);
  show "pred" (pred 43);
  show "float" (int_of_float (float_of_int 7 *. 2.5 +. 0.75));
  show "trunc" (int_of_float (-3.9));
  show "fdiv" (int_of_float (10.0 /. 4.0 *. 100.0))

let yes b = if b then print_string "T" else print_string "F"

let () =
  yes (1 < 2); yes (2 < 1); yes (2 <= 2); yes (3 >= 4); yes (5 > 4);
  yes (3 = 3); yes (3 <> 3); yes (1.5 < 2.5); yes (nan <= nan); yes (nan >= nan);
  yes (not (nan < nan));
  print_newline ()
