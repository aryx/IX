(* mlpp's list comprehensions (pp/Pp): [%list e || x <- xs; y <- ys; c],
 * Haskell's [ e | x <- xs, y <- ys, c ] *)

let range a b = List.init (b - a + 1) (fun i -> a + i)

let show l = String.concat " " (List.map string_of_int l)

let () =
  let xs = [ 1; 2; 3; 4; 5; 6 ] in
  (* a map, a filter, both *)
  print_endline (show [%list x * x || x <- xs]);
  print_endline (show [%list x || x <- xs; x mod 2 = 0]);
  print_endline (show [%list x * 10 || x <- xs; x > 2; x < 6]);
  (* two generators: the second one's list may name the first's variable *)
  print_endline (String.concat " " [%list Printf.sprintf "%d%c" x c || x <- [ 1; 2 ]; c <- [ 'a'; 'b'; 'c' ]]);
  print_endline (String.concat " " [%list Printf.sprintf "(%d,%d)" x y || x <- range 1 4; y <- range x 4; x + y = 5]);
  (* Pythagorean triples, the classic *)
  let n = 20 in
  List.iter (fun (a, b, c) -> Printf.printf "%d %d %d\n" a b c)
    [%list (a, b, c) || a <- range 1 n; b <- range a n; c <- range b n; a * a + b * b = c * c];
  (* a comprehension over a comprehension's result, and one of several lines *)
  let evens = [%list x || x <- range 1 10; x mod 2 = 0] in
  print_endline (show [%list
    x + y
    || x <- evens;
       y <- [ 100; 200 ];
       x > 4 || y > 100]);
  (* no element *)
  print_endline (string_of_int (List.length [%list x || x <- xs; x > 10]))
