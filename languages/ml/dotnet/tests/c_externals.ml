(* the runtime unit (lib_core/dotnet/Runtime.ml): Pervasives'
 * externals of C in ML over .NET; format_float and format_int named
 * here as Pervasives names them, Printf's and string_of_float's *)

external format_float : string -> float -> string = "format_float"
external format_int : string -> int -> string = "format_int"

let g (x : float) = print_string (format_float "%.12g" x); print_newline ()
let f (fmt : string) (x : float) = print_string (format_float fmt x); print_string "|"; print_newline ()
let i (fmt : string) (n : int) = print_string (format_int fmt n); print_string "|"; print_newline ()

let int_of (s : string) =
  try print_int (int_of_string s); print_newline ()
  with Failure m -> print_string m; print_newline ()

let float_of (s : string) =
  try g (float_of_string s) with Failure m -> print_string m; print_newline ()

let rec iter (f : string -> unit) (l : string list) =
  match l with [] -> () | x :: r -> f x; iter f r

let () =
  (* math *)
  g (sqrt 2.0); g (exp 1.0); g (log 10.0); g (log10 1000.0);
  g (sin 1.0); g (cos 1.0); g (tan 1.0); g (asin 0.5); g (acos 0.5); g (atan 1.0);
  g (atan2 1.0 (-1.0)); g (sinh 1.0); g (cosh 1.0); g (tanh 1.0);
  g (2.0 ** 0.5); g (floor (-2.5)); g (ceil (-2.5)); g (ceil 2.1);
  g (mod_float 7.5 2.0); g (mod_float (-7.5) 2.0);
  (* (IEEE's remainder rounds the quotient to the even: 3/2 and 5/2) *)
  g (mod_float 3.0 2.0); g (mod_float 5.0 2.0); g (mod_float 5.5 (-2.0));
  g (mod_float (-5.0) 3.0); g (mod_float 1e300 3.0); g (mod_float 1.0 0.0);
  let m, e = frexp 12.0 in g m; print_int e; print_newline ();
  let m, e = frexp (-0.375) in g m; print_int e; print_newline ();
  g (ldexp 0.75 4); g (ldexp 1.0 (-3));
  let fr, it = modf 3.75 in g fr; g it;
  let fr, it = modf (-2.5) in g fr; g it;
  (* numbers read *)
  iter int_of [ "42"; "-17"; "0x1F"; "0o17"; "0b101"; "1_000"; "+5"; "12a"; ""; "-"; "0b2" ];
  iter float_of
    [ "3.25"; "1e3"; "-0.5"; ".5"; "5."; "1_000.5"; "0x1.8p1"; "0x10"; "inf"; "-inf"; "nan";
      " 2.5"; "abc"; "1.5x"; ""; "e5"; "."; "1e"; "2.5 " ];
  (* ints written *)
  i "%d" (-42); i "%5d" 42; i "%-5d" 42; i "%05d" (-42); i "%+d" 5; i "% d" 3;
  i "%x" 255; i "%X" 255; i "%#x" 255; i "%o" 8; i "%u" 7; i "%d" 0; i "%x" 0;
  (* (.NET's int64: the native int's 63 bits print otherwise) *)
  i "%d" (1 lsl 63); i "%d" ((1 lsl 63) - 1); i "%x" (-1);
  (* floats written *)
  g 0.1; g 1e20; g 1e-5; g 123456789012345.0; g 0.0; g (-0.0); g 100.0;
  f "%f" 3.14159; f "%.2f" (-0.005); f "%e" 12345.678; f "%.3E" 0.000123;
  f "%g" 100000.0; f "%g" 1000000.0; f "%g" 0.0001; f "%g" 0.00001;
  f "%10.3f" 3.14159; f "%-10.2f" 3.14159; f "%010.2f" (-3.5); f "%+.1f" 2.25;
  f "%.0f" 2.5; f "%.0f" 3.5; f "%.0e" 15.0;
  f "%f" nan; f "%g" infinity; f "%5g" neg_infinity; f "%#g" 1.0; f "%G" 1e-10;
  f "%.17g" 0.1; f "%.3g" 1234.5; f "%.15g" 1e15; f "%f" 1e300
