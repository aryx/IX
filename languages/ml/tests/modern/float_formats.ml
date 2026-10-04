(* floats printed and read back: libc's formatter (lib_core/libc/ix/fmt.c)
 * against OCaml's, which is glibc's *)
let seed = ref 88172645463325252L
let rnd () =
  let s = !seed in
  let s = Int64.logxor s (Int64.shift_left s 13) in
  let s = Int64.logxor s (Int64.shift_right_logical s 7) in
  let s = Int64.logxor s (Int64.shift_left s 17) in
  seed := s; s

let show (x : float) =
  Printf.printf "%g %.12g %.17g %f %.0f %.3f %e %.0e %.20e %G %10.2f|%-12.4e|%+g|% g|%010.3f|%.1g\n" x x x x x x x x x x x x x x x x;
  let back = float_of_string (Printf.sprintf "%.17g" x) in
  if Int64.bits_of_float back <> Int64.bits_of_float x then Printf.printf "  not read back: %h\n" x;
  let near = float_of_string (Printf.sprintf "%.25e" x) in
  if Int64.bits_of_float near <> Int64.bits_of_float x then Printf.printf "  not read back (25): %h\n" x

let () =
  List.iter show [ 0.; -0.; 1.; -1.; 0.5; 1.5; 2.5; 0.125; 9.5; 9.95; 99.5; 1e-4; 1e-5; 123456.; 1234567.; 1e15; 1e16; 1e17; 1e21; 1e22; 1e23; 1e100;
    max_float; min_float; epsilon_float; 4.9e-324; 1. /. 3.; 0.1; 0.2; 0.3; 999999.5; 0.15; 0.25; 0.35 ];
  (* (not %010.3f: OCaml pads an infinity with zeros, C with spaces) *)
  List.iter (fun x -> Printf.printf "%g %.3f %e %G %8.2f|%-8g|%+g\n" x x x x x x x) [ infinity; neg_infinity ];
  for _i = 1 to 40 do
    show (Int64.float_of_bits (rnd ()));
    show (Int64.to_float (Int64.rem (rnd ()) 1000000L) /. 1000.);
    (* the usual sizes, then a denormal *)
    show (Int64.float_of_bits (Int64.logor (Int64.logand (rnd ()) 0x800fffffffffffffL) (Int64.shift_left (Int64.add 983L (Int64.rem (Int64.logand (rnd ()) 0xffffL) 80L)) 52)));
    show (Int64.float_of_bits (Int64.logand (rnd ()) 0x800fffffffffffffL))
  done;
  List.iter (fun s -> Printf.printf "%s -> %h\n" s (float_of_string s))
    [ "1e400"; "1e-400"; "1.7976931348623158e308"; "1.7976931348623159e308"; "2.4703282292062327e-324"; "2.4703282292062328e-324";
      "9007199254740993"; "9007199254740992.5"; "9007199254740993.0000000000000000000000000000000001"; "123456789012345678901234567890";
      ".5"; "1."; "-1.5E-3"; "inf"; "-infinity"; "nan" ]
