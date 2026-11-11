(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *
 * See TinyArchiver.mli
 *)
module M = TinyLibMachine
module TSys = TinyLibSystem

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

let usage = "usage: tiny-ar -o lib.a file.o... | tiny-ar -t lib.a"
let help = usage ^ {|

Objects (of tiny-ml, tiny-c or tiny-assembler) kept in one file, a library, by
their names, in their order; tiny-linker links them all, in that order, as if
each were given. With -t, the members' names. In tiny/TinyLibCore/:
  tiny-ar -o stdlib.a Stdlib.o Char.o List.o    a library of three units
  tiny-ar -t stdlib.a                           Stdlib.o Char.o List.o
  tiny-linker -o prog start.o prog.o stdlib.a
|}

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let read f = TSys.with_open_in caps (fun ch -> In_channel.input_all ch.ic) f in
  match List.tl (Array.to_list argv) with
  | ("-h" | "--help") :: _ -> TSys.print caps help; Exit.OK
  | [ "-t"; lib ] ->
      (try
         List.iter (fun (name, _) -> TSys.print caps (name ^ "\n"))
           (M.of_archive (read (Fpath.v lib)));
         Exit.OK
       with M.Error e -> Exit.Err (lib ^ ": " ^ e))
  | "-o" :: lib :: (_ :: _ as files) ->
      (try
         let members =
           List.map (fun f ->
             let p = Fpath.v f in
             Fpath.to_string (Fpath.base p), read p) files in
         TSys.write_file caps (Fpath.v lib) (M.to_archive members);
         Exit.OK
       with M.Error e -> Exit.Err e)
  | _ -> TSys.eprint caps (usage ^ "   (-h: how)\n"); Exit.Code 2

let () = TSys.main "tiny-ar" main
