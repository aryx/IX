(* the stdlib's Seq (lib_core/collections), OCaml 4.14's: sequences
 * computed as they are read *)

let line s = print_string s; print_newline ()
let show l = String.concat " " (List.map string_of_int l)
let of_seq = List.of_seq

(* what is computed, to see the laziness *)
let trace = ref []
let noted x = trace := x :: !trace; x

let () =
  let s = List.to_seq [ 1; 2; 3; 4; 5; 6 ] in
  line (show (of_seq (Seq.map (fun x -> x * x) s)));
  line (show (of_seq (Seq.filter (fun x -> x mod 2 = 0) s)) ^ " | " ^ show (of_seq (Seq.filter_map (fun x -> if x > 3 then Some (-x) else None) s)));
  line (show (of_seq (Seq.take 2 s)) ^ " | " ^ show (of_seq (Seq.take 0 s)) ^ " | " ^ show (of_seq (Seq.take 9 s)));
  line (show (of_seq (Seq.take_while (fun x -> x < 4) s)) ^ " | " ^ show (of_seq (Seq.drop_while (fun x -> x < 4) s)));
  line (show (of_seq (Seq.concat_map (fun x -> List.to_seq [ x; 10 * x ]) (Seq.take 3 s))));
  line (show (of_seq (Seq.init 4 (fun i -> i * 3))) ^ " | " ^ show (of_seq (Seq.append (Seq.init 2 succ) Seq.empty)));
  line (string_of_int (Seq.fold_left ( + ) 0 s) ^ " " ^ show (of_seq (Array.to_seq [| 7; 8; 9 |])));
  Seq.iter (fun x -> print_int x; print_char ';') (Seq.take 3 s);
  print_newline ();
  (* only what is read is computed *)
  let squares = Seq.map (fun x -> noted (x * x)) (Seq.init 1000 (fun i -> i)) in
  let odd = of_seq (Seq.take 3 (Seq.filter (fun x -> x mod 2 = 1) squares)) in
  line (show odd ^ " : " ^ show (List.rev !trace));
  (* a sequence by hand, and its node *)
  let rec from n () = if n > 3 then Seq.Nil else Seq.Cons (n, from (n + 1)) in
  (match from 2 () with Seq.Cons (x, rest) -> line (string_of_int x ^ " then " ^ show (of_seq rest)) | Seq.Nil -> line "empty");
  (try line (show (of_seq (Seq.take (-1) s))) with Invalid_argument m -> line ("Invalid_argument " ^ m))
