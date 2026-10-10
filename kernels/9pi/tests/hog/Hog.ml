(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* A program that asks for memory and keeps it: hog n holds n megabytes
 * of bytes, written, and says so. For mini-9pi's test of a machine
 * with no page left (../session-hog.cmds: several at once ask for
 * more than the board has; the kernel ends those it cannot serve and
 * goes on). mini-ml's collector holds two halves, each at least twice
 * what is alive: hog 40 touches about 128 MB. *)

let () =
  let n = if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 1 in
  let held = ref [] in
  for _i = 1 to n do
    held := Bytes.make 1000000 'x' :: !held
  done;
  Printf.printf "hog: %d MB held\n" (List.length !held)
