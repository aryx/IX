(* floor and ceil of the numbers around the runtime's two ways (an
 * int's range, then the C library's): halves, whole numbers, -0., the
 * edges of 32 bits, large ones, infinities and nan *)

let () =
  let xs = [ 0.; -0.; 0.5; -0.5; 1.; -1.; 1.5; -1.5; 2.999; -2.999; 1e-300; -1e-300;
             2147483646.5; 2147483647.5; -2147483647.5; -2147483648.5; 4294967296.75; -4294967296.75;
             1e15 +. 0.5; -1e15 -. 0.5; 1e300; infinity; neg_infinity; nan ] in
  List.iter (fun x ->
    Printf.printf "%h %h %h\n" x (floor x) (ceil x)) xs
