(* a float's bits (Int64's, Int32's), the floats' limits, Float's
 * rounding and its min and max; OCaml's output by mini-ml (arm64) *)

let x64 f = Printf.sprintf "%016Lx" (Int64.bits_of_float f)

let () =
  List.iter (fun f -> Printf.printf "%s " (x64 f)) [ 0.0; -0.0; 1.0; -1.5; 0.1; 1e300; 5e-324 ];
  print_newline ();
  Printf.printf "%s %s %s\n" (x64 infinity) (x64 neg_infinity) (x64 nan);
  Printf.printf "%s %s %s\n" (x64 max_float) (x64 min_float) (x64 epsilon_float);
  Printf.printf "%b %b %b\n" (max_float = 1.79769313486231571e+308) (min_float = 2.22507385850720138e-308)
    (1.0 +. epsilon_float > 1.0 && 1.0 +. epsilon_float /. 2.0 = 1.0);
  Printf.printf "%g %g %g\n" (Int64.float_of_bits 0x4009_21fb_5444_2d18L) (Int64.float_of_bits 0xbff8_0000_0000_0000L)
    (Int64.float_of_bits (Int64.bits_of_float 2.5));
  Printf.printf "%08lx %08lx %08lx %08lx\n" (Int32.bits_of_float 1.0) (Int32.bits_of_float (-2.5)) (Int32.bits_of_float 0.1)
    (Int32.bits_of_float infinity);
  Printf.printf "%g %g %b\n" (Int32.float_of_bits 0x40490fdbl) (Int32.float_of_bits 0xc0200000l)
    (Int32.float_of_bits (Int32.bits_of_float 0.1) = 0.1);
  Printf.printf "%Ld %Ld %Ld %g %g %g\n" (Int64.of_float 3.99) (Int64.of_float (-3.99)) (Int64.of_float 1e15)
    (Int64.to_float 42L) (Int64.to_float (-1L)) (Int32.to_float (-7l));

  (* Float *)
  Printf.printf "%b %b %b %b\n" (Float.is_nan nan) (Float.is_nan 1.0) (Float.is_nan infinity) (nan = nan);
  (* = and < are IEEE's (a nan equal to nothing, itself too, and in a
   * structure); compare's order is total, and List.mem's is compare's *)
  let x = nan in
  Printf.printf "%b %b %b %b %b %b %b\n" (x = x) (x <> x) (x < 1.0) (x > 1.0) (1.0 <= x) ([ x ] = [ x ]) ((1, x) <> (1, x));
  Printf.printf "%d %d %d %b %b %b\n" (compare x x) (compare x 1.0) (compare 1.0 x) (List.mem x [ 1.0; x ])
    (List.assoc x [ (x, 7) ] = 7) (0.0 = -0.0);
  Printf.printf "%b %b %b %b\n" (1.5 < 2.5) (2.5 <= 2.5) ((1.5, "a") < (1.5, "b")) (Some 2.0 > Some 1.0);
  let show f l = print_endline (String.concat " " (List.map (fun x -> x64 (f x)) l)) in
  let l = [ 0.0; -0.0; 0.3; -0.3; 0.5; -0.5; 1.5; 2.5; -2.5; 0.49999999999999994; 4503599627370497.0; 1e300; infinity ] in
  show Float.round l;
  show Float.trunc l;
  Printf.printf "%b %b\n" (Float.is_nan (Float.round nan)) (Float.is_nan (Float.trunc nan));
  let pairs = [ (1.0, 2.0); (2.0, 1.0); (0.0, -0.0); (-0.0, 0.0); (neg_infinity, 3.0); (nan, 1.0); (1.0, nan) ] in
  print_endline (String.concat " " (List.map (fun (a, b) -> x64 (Float.min a b)) pairs));
  print_endline (String.concat " " (List.map (fun (a, b) -> x64 (Float.max a b)) pairs));
  (* x * y + z rounded once: where x *. y +. z rounds twice, and the plain cases *)
  let e = epsilon_float in
  print_endline (String.concat " " (List.map (fun (x, y, z) -> x64 (Float.fma x y z))
    [ (1.0 +. e, 1.0 -. e, -1.0); (1.0 +. e, 1.0 +. e, -1.0); (0.1, 10.0, -1.0); (3.0, 4.0, 5.0); (1e200, 1e-200, 1.0);
      (0.1, 0.1, -0.01); (1.0 /. 3.0, 3.0, -1.0); (-0.7, 0.3, 0.21); (5.0, 0.0, -0.0); (0.0, 3.0, 7.5); (infinity, 2.0, 1.0);
      (nan, 1.0, 1.0); (2.0, 3.0, neg_infinity); (1e308, 10.0, neg_infinity) ]));
  let seed = ref 12345 in
  let rnd () = seed := (!seed * 1103515245 + 12345) land 0x3fffffff; Float.of_int (!seed - 0x20000000) /. 1048576.0 in
  let sum = ref 0L in
  for _i = 1 to 2000 do
    let x = rnd () and y = rnd () and z = rnd () in
    sum := Int64.add (Int64.mul !sum 31L) (Int64.bits_of_float (Float.fma x y (-. (x *. y) +. z /. 1e12)))
  done;
  Printf.printf "%Lx\n" !sum;
  (* a zero's sign: negated, in a product, its absolute value *)
  let zero = Float.of_int 0 and one = Float.of_int 1 in
  print_endline (String.concat " " (List.map x64 [ -. zero; -. (-. zero); zero *. (-. one); Float.abs (-. zero); zero -. zero;
    Float.neg zero; -. nan; Float.abs (-. nan); ceil (-0.3); floor (-. zero) ]));
  let m, e = Float.frexp 12.0 in
  Printf.printf "%g %d %g %g %d %g\n" m e (Float.of_int 3) (Float.abs (-2.5)) (Float.to_int 9.99) (Float.sqrt 16.0)

(* the square root, correctly rounded (the last bit), and of a negative *)
let () =
  Printf.printf "%Lx %Lx %Lx %h\n" (Int64.bits_of_float (sqrt 0.5)) (Int64.bits_of_float (sqrt 2.0))
    (Int64.bits_of_float (sqrt 1e-300)) (sqrt 3.0);
  Printf.printf "%b %b %g %g\n" (Float.is_nan (sqrt (-1.0))) (sqrt infinity = infinity) (sqrt 0.0) (sqrt 1e300)
