(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* bigmem: a test of a partition bigger than 1 MB. The Makefile links it
 * as an a.out that asks for 8 MB (tiny-linker -a 8), and mlsys.c sizes the
 * heap from the partition. It keeps 3 MB of strings alive at once, which
 * the heap of a 1 MB partition (two halves of 256 KB) cannot hold, then
 * prints how many bytes it kept. *)
let () =
  let rec make n acc = if n = 0 then acc else make (n - 1) (String.make 1000 'x' :: acc) in
  let kept = make 3000 [] in
  print_string ("bigmem: " ^ string_of_int (List.fold_left (fun s x -> s + String.length x) 0 kept) ^ " bytes kept\n")
