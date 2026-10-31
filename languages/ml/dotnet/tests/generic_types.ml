(* types of parameters: generic classes, tree`1, used at types,
   tree`1<long>, tree`1<string>; Pervasives' ref and option, Stdlib's;
   functions over them generic methods *)
type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree
type ('k, 'v) entry = { key : 'k; mutable value : 'v }

let rec insert t x =
  match t with
  | Leaf -> Node (Leaf, x, Leaf)
  | Node (l, y, r) -> if x < y then Node (insert l x, y, r) else Node (l, y, insert r x)

let rec size t = match t with Leaf -> 0 | Node (l, _, r) -> size l + 1 + size r

let rec leftmost t = match t with Leaf -> None | Node (Leaf, x, _) -> Some x | Node (l, _, _) -> leftmost l

let rec sum t = match t with Leaf -> 0 | Node (l, x, r) -> sum l + x + sum r

let rec concat t = match t with Leaf -> "" | Node (l, x, r) -> concat l ^ x ^ concat r

let show_opt o = match o with None -> "none" | Some s -> "some " ^ s

let set e v = e.value <- v

let () =
  let t = insert (insert (insert (insert Leaf 5) 2) 8) 1 in
  print_int (size t); print_string " "; print_int (sum t); print_newline ();
  let s = insert (insert (insert Leaf "m") "a") "z" in
  print_endline (concat s);
  print_endline (show_opt (leftmost s));
  print_endline (match leftmost t with None -> "none" | Some n -> string_of_int n);
  print_endline (show_opt (leftmost Leaf));
  let e = { key = "count"; value = 1 } in
  set e 41; e.value <- e.value + 1;
  print_endline (e.key ^ " = " ^ string_of_int e.value);
  let r = ref 0 in
  for i = 1 to 10 do r := !r + i done;
  incr r; decr r; decr r;
  print_int !r; print_newline ();
  let i = ref 0 and acc = ref "" in
  while !i < 4 do acc := !acc ^ string_of_int !i; incr i done;
  print_endline !acc;
  print_string (if insert Leaf 3 = insert Leaf 3 then "T" else "F");
  print_string (if Some "a" = Some "b" then "T" else "F");
  print_string (if leftmost t = Some 1 then "T" else "F");
  print_newline ()
