(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyMachineAsm's law, print and parse each other's inverse: each line
 * of each file given, as TinyMachineAsm parses it, printed then parsed
 * again, is the same line. A line that is not prints the file, its
 * line, and the two lines' texts; the exit status is the number of
 * them (0: the law holds). See TinyMachineAsm_test.sh. *)
module Asm = TinyMachineAsm

let () =
  let bad = ref 0 and lines = ref 0 in
  Array.iteri (fun i file ->
    if i > 0 then
      In_channel.with_open_bin file In_channel.input_all
      |> String.split_on_char '\n'
      |> List.iteri (fun n text ->
        Asm.parse text |> List.iter (fun (l : Asm.line) ->
          incr lines;
          let printed = Asm.print l in
          let again =
            Asm.parse (String.sub printed 0 (String.length printed - 1)) in
          if again <> [ l ] then begin
            incr bad;
            Printf.printf "%s:%d: %s -> %s" file (n + 1) (String.trim printed)
              (String.concat " | " (List.map Asm.print again))
          end)))
    Sys.argv;
  Printf.printf "%d lines, %d not the same printed and parsed again\n" !lines
    !bad;
  exit (min !bad 1)
