(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-man: a page of the manual found and shown, as Plan 9's man(1)
 * (an rc script round nroff there; round mini-troff's modules here).
 *
 *   mini-man tr         every page named tr, of any section
 *   mini-man 2 open     the one of section 2
 *   mini-man 1          section 1 listed, its pages by groups
 *   mini-man            every section listed so
 *
 * A page is a file, dir/section/name (/sys/man/1/tr): the manual is a
 * tree, and finding a page is looking in eight directories. The tree
 * is /sys/man, Plan 9's place, or /lib/man where there is none (ix's
 * card: /sys is the kernel's there); -m dir: the manual is there
 * (principia's ROOT/docs/man; ix's own pages are docs/man, written in
 * the new format, which a page says by its first line). -T pdf: the page as a PDF file, on the standard output
 * (one page then). -v: what was not understood in the page is said,
 * on the standard error (mini-troff always says it).
 *
 * cs-history:
 * man was a shell script from the start: the pages were files, the
 * formatter a program, and the command the few lines that put the two
 * together. The sections' numbers are the first edition's (1971): 1
 * the commands, 2 the system calls, 3 the library, 4 the devices, 5
 * the file formats, 6 the games, 7 the rest, 8 for who maintains the
 * system. Plan 9 kept the order and changed what is in some (3 the
 * devices, 4 the file servers, 5 the protocol, 6 the formats).
 *
 * A section is listed by groups, a page in the new format saying its
 * own as the third part of its first line, \title{grep}{1}{text}:
 *
 *   files
 *     cat     one file after another, on the standard output
 *     ...
 *   text
 *     grep    the lines that match a pattern
 *
 * Section 1 is the /bin of the manual, a hundred commands in one
 * directory; the groups are what /progs's directories are on ix's
 * card, for the eye. A page that says none (Plan 9's, by man(6)'s
 * macros) is in "other", at the end.
 *
 * others:
 * Unix's man -k (apropos, 3BSD) looks for a word in a database of the
 * NAME lines (whatis, made by makewhatis); Plan 9's lookman, in an
 * index of the words. BSD's pages say a section's title in the
 * header's middle ("General Commands Manual"), as ix's say their
 * group. *)

type caps = < Cap.open_in ; Cap.readdir ; Cap.stdout ; Cap.stderr >

let usage = "usage: mini-man [-v] [-m dir] [-T pdf] [section] [title ...]\n"

exception Usage

let sections = [ "1"; "2"; "3"; "4"; "5"; "6"; "7"; "8" ]

(* the groups, in the order listed; then those not here, by name; then
 * "other" *)
let groups = [ "shell"; "files"; "text"; "calc"; "time"; "processes"; "system"; "devtools"; "languages"; "typesetting"; "apps"; "browsers"; "network"; "emulators"; "games" ]

(* A page's group and what its NAME says it is: \title's third part,
 * and the words after the dash of the line under NAME (# NAME in the
 * new format, .SH NAME by man(6)'s macros) *)
let summary (source : string) : string * string =
  let lines = String.split_on_char '\n' source in
  let group =
    match lines with
    | first :: _ when String.length first > 7 && String.sub first 0 7 = "\\title{" ->
        (match String.split_on_char '{' first with
         | [ _; _; _; g ] -> (match String.index_opt g '}' with Some i when i > 0 -> String.sub g 0 i | _ -> "other")
         | _ -> "other")
    | _ -> "other" in
  let rec after_name (l : string list) : string =
    match l with
    | ("# NAME" | ".SH NAME") :: rest ->
        (* (its paragraph: to a blank line, a heading or a request) *)
        let rec skip (l : string list) = match l with x :: more when String.trim x = "" -> skip more | l -> l in
        let rec para (l : string list) : string list =
          match l with
          | x :: more when String.trim x <> "" && x.[0] <> '#' && x.[0] <> '.' -> String.trim x :: para more
          | _ -> [] in
        String.concat " " (para (skip rest))
    | _ :: rest -> after_name rest
    | [] -> "" in
  let line = after_name lines in
  (* (after the dash: the new format's, or man(6)'s \-) *)
  let what =
    let cut (sep : string) (s : string) : string option =
      let n = String.length sep and m = String.length s in
      let rec go (i : int) : string option = if i + n > m then None else if String.sub s i n = sep then Some (String.trim (String.sub s (i + n) (m - i - n))) else go (i + 1) in
      go 0 in
    match cut "\xe2\x80\x93" line with Some w -> w | None -> (match cut "\\-" line with Some w -> w | None -> String.trim line) in
  (group, what)

(* [index caps dirs section]: the section's pages by groups, as text;
 * "" if it has none *)
let index (caps : < Cap.open_in ; Cap.readdir ; .. >) (dirs : string list) (section : string) : string =
  (* each name once, from the first tree that has it *)
  let pages = ref [] in
  List.iter (fun dir ->
    let entries = try Sys_plan9.dirread caps (dir ^ "/" ^ section) with Unix.Unix_error _ -> [] in
    List.iter (fun (e : Sys_plan9.dir) ->
      let name = if Filename.check_suffix e.name ".md" then Filename.chop_suffix e.name ".md" else e.name in
      (* (not a page: Plan 9's INDEX, lookman's) *)
      if not (List.mem_assoc name !pages) && name <> "INDEX" && name <> "" && name.[0] <> '.' then
        match FS.read_opt caps (Fpath.v (dir ^ "/" ^ section ^ "/" ^ e.name)) with
        | Some source -> pages := (name, summary source) :: !pages
        | None -> ()) entries) dirs;
  if !pages = [] then ""
  else begin
    let pages = List.sort compare !pages in
    let width = List.fold_left (fun w ((name, _) : string * (string * string)) -> max w (String.length name)) 0 pages in
    let named = List.sort_uniq compare (List.map (fun ((_, (g, _)) : string * (string * string)) -> g) pages) in
    let order = List.filter (fun g -> List.mem g named) groups @ List.filter (fun g -> not (List.mem g groups) && g <> "other") named @ (if List.mem "other" named then [ "other" ] else []) in
    let b = Buffer.create 4096 in
    Buffer.add_string b ("Section " ^ section ^ "\n");
    List.iter (fun g ->
      Buffer.add_string b ("\n  " ^ g ^ "\n");
      List.iter (fun ((name, (pg, what)) : string * (string * string)) ->
        if pg = g then Buffer.add_string b (Printf.sprintf "    %-*s  %s\n" width name what)) pages) order;
    Buffer.contents b
  end

let main (caps : < caps ; .. >) (argv : string array) : Exit.t =
  try
    let dirs = ref [ "/sys/man"; "/lib/man" ] and verbose = ref false and way = ref CLI.Text in
    let rec options (l : string list) : string list =
      match l with
      | "-m" :: d :: rest -> dirs := [ d ]; options rest
      | "-v" :: rest -> verbose := true; options rest
      | "-T" :: "pdf" :: rest -> way := CLI.Pdf; options rest
      | "-T" :: "text" :: rest -> way := CLI.Text; options rest
      | a :: _ when String.length a > 1 && a.[0] = '-' -> raise Usage
      | rest -> rest in
    let args = options (List.tl (Array.to_list argv)) in
    let wanted, titles = match args with s :: rest when List.mem s sections -> ([ s ], rest) | _ -> (sections, args) in
    let missing = ref false in
    (* no title: the sections listed *)
    if titles = [] then begin
      let lists = List.filter (fun s -> s <> "") (List.map (index caps !dirs) wanted) in
      if lists = [] then begin
        Console.eprint caps (Printf.sprintf "mini-man: no pages%s in %s\n" (match wanted with [ s ] -> " of section " ^ s | _ -> "") (String.concat " or " !dirs));
        missing := true
      end
      else Console.print caps (String.concat "\n" lists)
    end;
    List.iter (fun title ->
      let found = ref false in
      List.iter (fun section ->
        (* (the first tree that has it; a page in the new format may
         * keep its .md) *)
        let name = String.lowercase_ascii title in
        let files = List.concat_map (fun dir -> [ Printf.sprintf "%s/%s/%s" dir section name; Printf.sprintf "%s/%s/%s.md" dir section name ]) !dirs in
        match List.find_map (fun file -> match FS.read_opt caps (Fpath.v file) with Some source -> Some (file, source) | None -> None) files with
        | None -> ()
        | Some (file, source) ->
            found := true;
            let page, complaints = CLI.typeset !way None (fun _ -> None) file source in
            Console.print caps page;
            if !verbose then List.iter (fun c -> Console.eprint caps (c ^ "\n")) complaints) wanted;
      if not !found then begin Console.eprint caps (Printf.sprintf "mini-man: no page for %s in %s\n" title (String.concat " or " !dirs)); missing := true end) titles;
    if !missing then Exit.Err "no page" else Exit.OK
  with Usage -> Console.eprint caps usage; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
