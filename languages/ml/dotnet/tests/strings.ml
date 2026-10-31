(* strings: concatenation, length, comparison by their characters,
   chars printed, numbers made strings *)
let greet name = "hello, " ^ name ^ "!"

let rec count n = if n = 0 then "" else string_of_int n ^ " " ^ count (n - 1)

let () =
  print_endline (greet "ix");
  print_endline (count 5);
  print_int (String.length (greet "world"));
  print_newline ();
  print_char 'a'; print_char 'z'; print_newline ();
  if "abc" < "abd" then print_endline "abc < abd";
  if "b" > "abc" then print_endline "b > abc";
  if "same" = "sa" ^ "me" then print_endline "equal by their text";
  if "x" <> "y" then print_endline "x <> y";
  print_endline (string_of_int (-42))
