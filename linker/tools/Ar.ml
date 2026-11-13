(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-ar is the librarian. A library is a set of objects kept in one
 * file, with the names each object defines. mini-ld takes from it the
 * objects that define what a program still lacks. mini-ar has ar's
 * command line (Plan 9's: a key, the library, the files), but not ar's
 * file: a library is ix's own, a marshalled value, as an object is (see
 * the library in Link). Its usage is [help], which is what mini-ar -h
 * prints.
 *
 * What makes a file of objects a library is the index. Beside each
 * object it lists the names the object defines, so that the linker can
 * ask "who has print?" without reading every member (Link.load takes a
 * member when one of its names is wanted, and Link.mli works through an
 * example). When two members define a function, it is the first one's.
 *
 * cs-history:
 * ar, the archiver, comes from the first Unix (1971). It was a general
 * tool that kept files in one file with their names, dates and modes,
 * before tar took over that job and left it the libraries. Its first
 * format was binary. Today's format, with a line of text for each
 * member's header, comes from 4BSD and System V in the early 1980s, and
 * it has barely changed since (mini-mk's Archive reads it, for the
 * dates). The index came later and from another program: ranlib added
 * a first member listing the names, __.SYMDEF, and it had to be run
 * after each ar. Plan 9's ar writes the index itself.
 *
 * others:
 * A static library costs nothing at run time and is copied into each
 * program that uses it. A shared library (a .so, a DLL) is bound when
 * the program starts, by a dynamic loader, and it is in memory once for
 * all the programs. Plan 9 has only the first kind, and so does ix. *)

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
  let name = Link.member_file in
  match List.tl (Array.to_list argv) with
  | args when List.mem "-h" args || List.mem "--help" args -> Console.print caps help; 0
  | key :: lib :: files when key <> "" && String.for_all (fun c -> String.contains "utvc" c) key -> (
      let verbose = String.contains key 'v' in
      try
        let path s = match FS.path s with Ok p -> p | Error m -> failwith m in
        let lib = path lib in
        if String.contains key 't' then begin
          (* (the members as they are in the file: none read as an object) *)
          let l = Link.read_library caps lib in
          List.iter2 (fun m (_, names) ->
            Console.print caps (name m ^ (if verbose then ": " ^ String.concat " " names else "") ^ "\n")) l (Link.index l)
        end else begin
          let old = if Sys.file_exists (Fpath.to_string lib) then Link.read_library caps lib else [] in
          let added = List.map (fun f -> Link.member_of (Asm.load caps (path f))) files in
          let replaced m = List.exists (fun n -> name n = name m) added in
          if verbose then
            List.iter (fun n ->
              Console.print caps (Printf.sprintf "%s - %s\n" (if List.exists (fun o -> name o = name n) old then "r" else "a") (name n))) added;
          (* an older object of the same source goes; the new ones last, in their order *)
          Link.write_library caps lib (List.filter (fun o -> not (replaced o)) old @ added)
        end;
        0
      with Link.Error m | Sys_error m | Failure m -> Console.eprint caps ("mini-ar: " ^ m ^ "\n"); 1)
  | _ -> Console.eprint caps "usage: mini-ar u|vu|t|tv lib.a [objects...]   (-h: how)\n"; 1

let () = Cap.main (fun caps -> Logging.setup caps ~name:"mini-ar"; CapStdlib.exit caps (main caps (CapSys.argv caps)))
