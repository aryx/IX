(* M.(e): M's names in e, before the others, a local variable's too;
 * nested modules; an operator of M's *)

module V = struct
  let zero = 0
  let x = 10
  let ( + ) a b = (a * 100) + b
  let twice f a = f (f a)
  module Inner = struct let x = 1000 end
end

let x = 1

let () =
  print_int V.(x + zero); print_newline ();
  print_int (x + V.(x)); print_newline ();
  (* a local x, and M's in front of it *)
  let x = 5 in
  print_int V.(twice (fun a -> a + x) 1); print_newline ();
  print_int V.Inner.(x + x); print_newline ();
  print_int (V.(x) + V.Inner.(x) + x); print_newline ();
  print_string String.(concat "," (List.map (make 2) [ 'a'; 'b' ])); print_newline ()
