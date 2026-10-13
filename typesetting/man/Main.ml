(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-man: a page of the manual found and shown, as Plan 9's man(1)
 * (an rc script round nroff there; round mini-troff's modules here).
 *
 *   mini-man tr         every page named tr, of any section
 *   mini-man 2 open     the one of section 2
 *
 * A page is a file, dir/section/name (/sys/man/1/tr): the manual is a
 * tree, and finding a page is looking in eight directories. -m dir:
 * the manual is there (principia's ROOT/docs/man, until ix has its
 * own pages). -v: what was not understood in the page is said, on the
 * standard error (mini-troff always says it).
 *
 * cs-history:
 * man was a shell script from the start: the pages were files, the
 * formatter a program, and the command the few lines that put the two
 * together. The sections' numbers are the first edition's (1971): 1
 * the commands, 2 the system calls, 3 the library, 4 the devices, 5
 * the file formats, 6 the games, 7 the rest, 8 for who maintains the
 * system. Plan 9 kept the order and changed what is in some (3 the
 * devices, 4 the file servers, 5 the protocol, 6 the formats). *)

type caps = < Cap.open_in ; Cap.stdout ; Cap.stderr >

let usage = "usage: mini-man [-v] [-m dir] [section] title ...\n"

exception Usage

let sections = [ "1"; "2"; "3"; "4"; "5"; "6"; "7"; "8" ]

let main (caps : < caps ; .. >) (argv : string array) : Exit.t =
  try
    let dir = ref "/sys/man" and verbose = ref false in
    let rec options (l : string list) : string list =
      match l with
      | "-m" :: d :: rest -> dir := d; options rest
      | "-v" :: rest -> verbose := true; options rest
      | a :: _ when String.length a > 1 && a.[0] = '-' -> raise Usage
      | rest -> rest in
    let args = options (List.tl (Array.to_list argv)) in
    let wanted, titles = match args with s :: rest when List.mem s sections -> ([ s ], rest) | _ -> (sections, args) in
    if titles = [] then raise Usage;
    let missing = ref false in
    List.iter (fun title ->
      let found = ref false in
      List.iter (fun section ->
        let file = Printf.sprintf "%s/%s/%s" !dir section (String.lowercase_ascii title) in
        match FS.read_opt caps (Fpath.v file) with
        | None -> ()
        | Some source ->
            found := true;
            let page, complaints = CLI.text file source in
            Console.print caps page;
            if !verbose then List.iter (fun c -> Console.eprint caps (c ^ "\n")) complaints) wanted;
      if not !found then begin Console.eprint caps (Printf.sprintf "mini-man: no page for %s in %s\n" title !dir); missing := true end) titles;
    if !missing then Exit.Err "no page" else Exit.OK
  with Usage -> Console.eprint caps usage; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
