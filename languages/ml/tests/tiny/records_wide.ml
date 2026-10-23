(* A record and a tuple wider than 11 fields (tiny-machine's registers
 * for an expression: tiny-ml builds them in a block allocated first):
 * the fields computed right to left, as ocamlopt does, some of them
 * allocating (a collection may come between two); a copy by with; a
 * field read, a mutable one written *)
type wide = {
  f1 : int; f2 : string; f3 : int list; f4 : int; f5 : int; f6 : int;
  f7 : int; f8 : int; f9 : int; f10 : int; f11 : string;
  mutable f12 : int;
}

let say k = print_int k; print_char ' '; k

let make n =
  { f1 = say 1; f2 = String.make (say 2) 'b'; f3 = List.init (say 3) (fun i -> i);
    f4 = say 4; f5 = say 5; f6 = say 6; f7 = say 7; f8 = say 8; f9 = say 9;
    f10 = say 10; f11 = string_of_int (say 11 + n); f12 = say 12 }

let show r =
  print_newline ();
  print_int r.f1; print_string r.f2; print_int (List.length r.f3);
  print_int (r.f4 + r.f5 + r.f6 + r.f7 + r.f8 + r.f9 + r.f10);
  print_string r.f11; print_int r.f12; print_newline ()

let () =
  let rs = List.init 50 make in
  List.iter show [ List.hd rs; List.nth rs 49 ];
  let r = { (List.nth rs 7) with f2 = "copy"; f12 = 99 } in
  show r;
  r.f12 <- 100;
  show r;
  let t = (1, "a", 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13) in
  let (a, b, _, _, _, _, _, _, _, _, _, _, m) = t in
  print_int a; print_string b; print_int m; print_newline ()
