(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-ar: the librarian. A library is objects kept in one file, with
 * the names each defines, for mini-ld, which takes from it the objects
 * that define what a program still lacks. ar's command line (Plan 9's:
 * a key, the library, the files), not its file: a library is ix's, a
 * marshalled value, as an object is (Link's library). Its usage: [help],
 * what mini-ar -h prints.
 *
 * What makes a file of objects a library is the index: beside each
 * object, the names it defines, so that the linker can ask "who has
 * print?" without reading every member (Link.load takes a member
 * when one of its names is wanted, and Link.mli works an example).
 * A function defined by two members is the first's.
 *
 * cs-history:
 * ar, the archiver, is of the first Unix (1971), and was a general
 * tool, files kept in one file with their names, dates and modes,
 * before tar took that job and left it the libraries. Its first
 * format was binary; today's, a line of text for each member's
 * header, is 4BSD's and System V's, of the early 1980s, and has
 * barely changed since (mini-mk's Archive reads it, for the dates).
 * The index came
 * later and from another program: ranlib added a first member
 * listing the names, __.SYMDEF, and had to be run after each ar;
 * Plan 9's ar writes it itself.
 *
 * others:
 * A static library costs nothing at run time and is copied into
 * each program that uses it; a shared library (a .so, a DLL) is
 * bound when the program starts, by a dynamic loader, and is in
 * memory once for all. Plan 9 has only the first kind, and ix. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

(* -h: how, by examples, each one as it runs *)
let help = {|usage: mini-ar key lib.a [objects...]
Plan 9's ar, for mini-ld's libraries: the objects of mini-asm and mini-cc kept
in one file, lib.a, from which mini-ld takes those a program needs. The key:
  mini-ar u libc.a print.7 exits.7    the objects put in the library, made if
                                      it is not there; one of the same source
                                      takes the place of the older
  mini-ar vu libc.a print.7           and each said: a - print.c (r: replaced)
  mini-ar t libc.a                    its objects, by their sources: print.c
  mini-ar tv libc.a                   with the names each defines
The file is ix's own, not ar's: a marshalled value, as an object is.
|}

let main (caps : < caps; .. >) (argv : string array) : int =
  let name (o : Asm.obj) = Fpath.to_string o.file in
  match List.tl (Array.to_list argv) with
  | args when List.mem "-h" args || List.mem "--help" args -> Console.print caps help; 0
  | key :: lib :: files when key <> "" && String.for_all (fun c -> String.contains "utvc" c) key -> (
      let verbose = String.contains key 'v' in
      try
        let path s = match FS.path s with Ok p -> p | Error m -> failwith m in
        let lib = path lib in
        if String.contains key 't' then
          List.iter (fun ((o : Asm.obj), names) ->
            Console.print caps (name o ^ (if verbose then ": " ^ String.concat " " names else "") ^ "\n")) (Link.read_library caps lib)
        else begin
          let old = if Sys.file_exists (Fpath.to_string lib) then List.map fst (Link.read_library caps lib) else [] in
          let added = List.map (fun f -> Asm.load caps (path f)) files in
          let replaced (o : Asm.obj) = List.exists (fun (n : Asm.obj) -> name n = name o) added in
          if verbose then
            List.iter (fun (n : Asm.obj) ->
              Console.print caps (Printf.sprintf "%s - %s\n" (if List.exists (fun o -> name o = name n) old then "r" else "a") (name n))) added;
          (* an older object of the same source goes; the new ones last, in their order *)
          Link.write_library caps lib (List.filter (fun o -> not (replaced o)) old @ added)
        end;
        0
      with Link.Error m | Sys_error m | Failure m -> Console.eprint caps ("mini-ar: " ^ m ^ "\n"); 1)
  | _ -> Console.eprint caps "usage: mini-ar u|vu|t|tv lib.a [objects...]   (-h: how)\n"; 1

let () = Cap.main (fun caps -> Logging.setup caps ~name:"mini-ar"; CapStdlib.exit caps (main caps (CapSys.argv caps)))
