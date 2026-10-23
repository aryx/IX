(* an array or a string larger than a block can be: Invalid_argument,
 * as OCaml's (4M words on 32 bits; the header's size has 22 bits),
 * not a block whose header says another size *)

let () =
  let n = if Sys.word_size = 32 then 1 lsl 22 else 1 lsl 54 in
  (try ignore (Array.make n 0); print_endline "made" with Invalid_argument m -> print_endline m);
  (try ignore (Bytes.create (n * (Sys.word_size / 8))); print_endline "made" with Invalid_argument m -> print_endline m);
  print_int (Array.length (Array.make 1000 0)); print_newline ()
