(* for loops up and down, booleans and their short circuits, a value of
   the unit read by its functions, if without else *)
let width = 4

let row i =
  for j = 1 to width do
    print_int (i * j);
    if j < width then print_char ' '
  done;
  print_newline ()

let () =
  for i = 1 to 3 do row i done;
  for i = 3 downto 1 do print_int i done;
  print_newline ();
  for i = 5 to 4 do print_int i done

let loud b = print_string (if b then "t" else "f"); b

let () =
  if loud false && loud true then print_string "!";
  if loud true || loud false then print_string "!";
  print_newline ()
