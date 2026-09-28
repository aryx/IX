(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See CLI.mli *)

(* -h: the usage, and a session by example, as it runs *)
let help = {|usage: mini-ed [-] [-o] [file]
Plan 9's ed, faithfully: a buffer of lines, the commands on standard input,
one a line; file read into the buffer, and remembered, as e file would.
  -     quiet: no counts, no ! after a shell command; q and e even unwritten
  -o    a filter: the file is standard output, the rest standard error, and
        ed starts in input mode (ed -o < text, the commands after the ".")
A session, on no file:
  a                 lines appended after the current one, until a "."
  hello, world
  bye, world
  .
  ,p                all the lines printed (2p: the second; $p: the last)
  1s/world/ed/      the first world of line 1 made ed
  g/world/p         each line with a world printed
  w hello.txt       written, its size printed: 21
  q                 (an error is a ?, nothing more)
|}

type caps = < Command.caps; Cap.argv; Cap.exit; Cap.stdout >

let main (caps : < caps; .. >) (argv : string array) : int =
  match Array.to_list argv with
  | [ _; ("-h" | "--help") ] -> Console.print caps help; 0
  | _ ->
      let rec flags verbose filter = function
        | "-o" :: rest -> flags false true rest
        | "-" :: rest -> flags false filter rest
        | rest -> verbose, filter, rest
      in
      let verbose, filter, args = flags true false (List.tl (Array.to_list argv)) in
      let t = Command.create caps (Input.of_fd Unix.stdin) ~verbose ~filter in
      Sys.catch_break true;
      Sys.set_signal Sys.sighup (Sys.Signal_handle (fun _ -> Command.rescue t; Out.flush (); exit 0));
      let file = match args with f :: _ when not filter -> Some f | _ -> None in
      Command.run t ~file;
      0
