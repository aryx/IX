(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* bytes, what is written, apart from strings, what is not
 * (plan_kernel_ocaml4.md, step 8): made, set, given as a string. *)

let hex (b : bytes) : string = String.concat " " (List.map (fun c -> Printf.sprintf "%02x" (Char.code c)) (List.init (Bytes.length b) (Bytes.get b)))

let () =
  let b = Bytes.create 4 in
  Bytes.fill b 0 4 'a';
  Bytes.set b 1 'b';
  Bytes.unsafe_set b 2 'c';
  b.[3] <- 'd';
  print_endline (Bytes.to_string b);
  (* a copy: the string does not change with the bytes *)
  let s = Bytes.to_string b in
  Bytes.set b 0 'z';
  Printf.printf "%s %s %s\n" s (Bytes.sub_string b 0 2) (Bytes.unsafe_to_string (Bytes.sub b 2 2));
  let c = Bytes.of_string "hello" in
  Bytes.blit_string "HE" 0 c 0 2;
  Bytes.blit c 0 c 3 2;
  Printf.printf "%s %d %b %d\n" (Bytes.to_string c) (Bytes.length c) (Bytes.equal c (Bytes.of_string "HElHE")) (compare c b);
  print_endline (Bytes.to_string (Bytes.cat (Bytes.make 2 'x') (Bytes.concat (Bytes.of_string ", ") [ b; c; Bytes.empty ])));
  let n = Bytes.create 8 in
  Bytes.set_int64_le n 0 0x0102030405060708L;
  Printf.printf "%s %x %lx\n" (hex n) (Bytes.get_uint16_be n 0) (Bytes.get_int32_le n 4);
  let buf = Buffer.create 2 in
  Buffer.add_bytes buf c;
  Buffer.add_subbytes buf b 1 2;
  Buffer.add_string buf "!";
  let out = Bytes.create 3 in
  Buffer.blit buf 4 out 0 3;
  Printf.printf "%s %s %s %c\n" (Buffer.contents buf) (Bytes.to_string (Buffer.to_bytes buf)) (Bytes.to_string out) (Buffer.nth buf 7);
  print_endline (String.capitalize_ascii (String.map Char.uppercase_ascii "ab") ^ String.make 2 '-' ^ String.init 3 (fun i -> Char.chr (48 + i)))
