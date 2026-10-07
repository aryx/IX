(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See CLI.mli *)

type caps = < Dc.caps; Cap.stderr >

let help = {|usage: mini-dc [FILE]
Plan 9's dc, the desk calculator: numbers of any size on a stack, the
operators after their operands; the file's commands, then the standard input's:
  echo '2 3 + p' | mini-dc                 5
  echo '20k 2 v p' | mini-dc               1.41421356237309504880
  echo '2 100 ^ p 16o 255 p' | mini-dc     1267650600228229401496703205376, ff
  echo '[la 1 + d sa p 5 >x]sx 0sa lxx' | mini-dc      1 to 5: a macro that runs itself
A number: digits, a point, _ for a minus. + - * / % ^ v (square root); p prints
the top, f the stack; d duplicates, c clears; sx and lx save to and load from
the register x (Sx, Lx: each register a stack); [text] is a string, x runs
it, <x >x =x run the register x if the two numbers on top compare so; k sets the
scale (the digits after the point), i and o the input and output bases; q quits.
|}

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  match List.tl (Array.to_list argv) with
  | [ "-h" ] | [ "--help" ] -> Console.print caps help; Exit.OK
  | args ->
      (* (an option, any, is the C's debugging) *)
      let files = List.filter (fun a -> a = "" || a.[0] <> '-') args in
      match files with
      | file :: _ when (try Unix.close (FS.open_in_fd caps file); (Unix.stat file).st_kind = Unix.S_DIR with Unix.Unix_error _ | Sys_error _ -> true) ->
          let is_dir = (try (Unix.stat file).st_kind = Unix.S_DIR with Unix.Unix_error _ -> false) in
          Console.eprint caps (if is_dir then Printf.sprintf "dc: file %s is a directory\n" file else Printf.sprintf "dc: can't open file %s\n" file);
          Exit.Code 1
      | _ -> (try Dc.run caps (match files with f :: _ -> Some f | [] -> None) with Dc.Quit -> ()); Exit.OK
