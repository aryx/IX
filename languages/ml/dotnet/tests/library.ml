(* lib_core's units compiled with the program (stage 3c): List, String,
 * Bytes, Buffer, Printf, Hashtbl, Array, Char, Option; compare's
 * structural order; floats printed; a local let rec ... and *)

type color = Red | Green | Blue of int
type person = { name : string; age : int }

let people = [ { name = "bob"; age = 40 }; { name = "alice"; age = 30 }; { name = "carol"; age = 40 } ]

let () =
  (* List *)
  let l = [ 5; 3; 8; 1; 9; 2 ] in
  Printf.printf "sorted %s\n" (String.concat " " (List.map string_of_int (List.sort compare l)));
  Printf.printf "sum %d max %d\n" (List.fold_left ( + ) 0 l) (List.fold_left max 0 l);
  Printf.printf "filter %s\n" (String.concat "," (List.map string_of_int (List.filter (fun x -> x mod 2 = 1) l)));
  Printf.printf "assoc %s, mem %b, nth %d, rev %d\n" (List.assoc 2 [ (1, "one"); (2, "two") ]) (List.mem 8 l) (List.nth l 2) (List.hd (List.rev l));
  (try ignore (List.assoc 3 [ (1, "one") ]) with Not_found -> print_endline "Not_found");
  let by_age = List.sort (fun a b -> compare (a.age, a.name) (b.age, b.name)) people in
  List.iter (fun p -> Printf.printf "%s:%d " p.name p.age) by_age; print_newline ();
  Printf.printf "colors %s\n" (String.concat " " (List.map (fun c -> match c with Red -> "R" | Green -> "G" | Blue n -> "B" ^ string_of_int n) (List.sort compare [ Blue 2; Red; Blue 1; Green ])));
  (* String, Char, Bytes *)
  let s = "Hello, World" in
  Printf.printf "%s %s %d %c\n" (String.uppercase_ascii s) (String.sub s 7 5) (String.index s 'W') (Char.lowercase_ascii s.[0]);
  Printf.printf "split %s\n" (String.concat "|" (String.split_on_char ',' "a,b,,c"));
  Printf.printf "trim [%s] escaped [%s]\n" (String.trim "  x y  ") (String.escaped "a\tb\n");
  let b = Bytes.of_string "abcdef" in
  Bytes.set b 0 'X'; Bytes.blit_string "12" 0 b 4 2;
  Printf.printf "bytes %s %d\n" (Bytes.to_string b) (Bytes.length b);
  (* Buffer *)
  let buf = Buffer.create 4 in
  for i = 1 to 5 do Buffer.add_string buf (string_of_int i); Buffer.add_char buf ';' done;
  Printf.printf "buffer %s %d\n" (Buffer.contents buf) (Buffer.length buf);
  (* Printf's formats *)
  Printf.printf "[%5d] [%-5d] [%05d] [%x] [%X] [%o]\n" 42 42 42 255 255 8;
  Printf.printf "[%s] [%10s] [%-10s] [%c]\n" "ab" "ab" "ab" 'z';
  Printf.printf "[%f] [%.2f] [%e] [%g] [%g]\n" 3.14159 2.71828 12345.678 0.0001 1e20;
  Printf.printf "%s %s %s\n" (string_of_float 1.5) (string_of_float 0.1) (string_of_float 1e20);
  print_endline (Printf.sprintf "%d-%s-%b" 7 "x" true);
  (* Hashtbl: its contents sorted (the order is the hash's) *)
  let h = Hashtbl.create 8 in
  List.iter (fun p -> Hashtbl.replace h p.name p.age) people;
  Hashtbl.replace h "bob" 41;
  let kv = Hashtbl.fold (fun k v acc -> (k, v) :: acc) h [] in
  List.iter (fun (k, v) -> Printf.printf "%s=%d " k v) (List.sort compare kv); print_newline ();
  Printf.printf "find %d, mem %b, length %d\n" (Hashtbl.find h "alice") (Hashtbl.mem h "dave") (Hashtbl.length h);
  let h2 = Hashtbl.create 8 in
  Hashtbl.add h2 (1, Blue 3) "a"; Hashtbl.add h2 (2, Red) "b";
  Printf.printf "structural keys %s %s\n" (Hashtbl.find h2 (1, Blue 3)) (Hashtbl.find h2 (2, Red));
  (* Array *)
  let a = Array.init 6 (fun i -> i * i) in
  Array.sort (fun x y -> compare y x) a;
  Printf.printf "array %s %d\n" (String.concat " " (Array.to_list (Array.map string_of_int a))) (Array.fold_left ( + ) 0 a);
  let m = Array.make_matrix 2 3 0 in
  m.(1).(2) <- 7;
  Printf.printf "matrix %d %d\n" m.(1).(2) (Array.length m.(0));
  (* Option *)
  Printf.printf "option %b %b\n" (Option.map succ (Some 5) = Some 6) (Option.is_none None);
  (* a local let rec ... and *)
  let rec even n = n = 0 || odd (n - 1) and odd n = n <> 0 && even (n - 1) in
  Printf.printf "even %b odd %b\n" (even 10) (odd 7)
