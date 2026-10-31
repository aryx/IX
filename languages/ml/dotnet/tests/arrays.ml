(* arrays, .NET's own T[]: a literal newarr and its elements stored,
   a.(i) ldelem, a.(i) <- v stelem, Array.length ldlen *)
type point = { x : int; y : int }

let swap_ends a =
  let n = Array.length a in
  let t = a.(0) in
  a.(0) <- a.(n - 1);
  a.(n - 1) <- t

let sort a =
  let n = Array.length a in
  for i = 0 to n - 2 do
    for j = 0 to n - 2 - i do
      if a.(j) > a.(j + 1) then begin
        let t = a.(j) in
        a.(j) <- a.(j + 1);
        a.(j + 1) <- t
      end
    done
  done

let () =
  let a = [| 5; 3; 9; 1; 7 |] in
  sort a;
  for i = 0 to Array.length a - 1 do print_int a.(i); print_char ' ' done;
  print_newline ();
  let total = ref 0 in
  for i = 0 to Array.length a - 1 do total := !total + a.(i) done;
  print_int !total; print_newline ();
  let words = [| "first"; "middle"; "last" |] in
  swap_ends words;
  print_endline (words.(0) ^ " " ^ words.(1) ^ " " ^ words.(2));
  let pts = [| { x = 1; y = 2 }; { x = 3; y = 4 } |] in
  swap_ends pts;
  print_int (pts.(0).x * 10 + pts.(1).y); print_newline ()
