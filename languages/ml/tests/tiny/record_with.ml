(* { e with l = v; ... }: a copy with some fields changed; the original
 * unchanged, even its mutable fields; e an expression, not only a
 * name; inside a closure; a polymorphic record; a label shared by two
 * records *)
type piece = { kind : int; turn : int; x : int; y : int }
type 'a box = { mutable contents : 'a; count : int }
type a = { name : string; size : int }
type b = { name2 : string; size : int; extra : int }

let show p =
  List.iter (fun n -> print_int n; print_char ' ') [ p.kind; p.turn; p.x; p.y ]; print_newline ()
let origin k = { kind = k; turn = 0; x = 0; y = 0 }
let down p = { p with y = p.y + 1 }

let () =
  let p = { kind = 3; turn = 1; x = 4; y = 0 } in
  show (down (down p));
  show { p with turn = (p.turn + 1) mod 4; x = p.x - 1 };
  show { (origin 6) with x = 5 };
  show p;
  let moves = List.map (fun dx -> { p with x = p.x + dx }) [ -1; 0; 1 ] in
  List.iter show moves;
  let b = { contents = "a"; count = 1 } in
  let c = { b with count = 2 } in
  c.contents <- "c";
  print_string b.contents; print_string c.contents; print_int (b.count + c.count); print_newline ();
  let r : b = { name2 = "r"; size = 1; extra = 2 } in
  let r2 = { r with size = 10 } in
  print_int (r2.size + r2.extra); print_string r2.name2; print_newline ();
  let q : a = { name = "q"; size = 1 } in
  print_int { q with name = "z" }.size; print_newline ()
