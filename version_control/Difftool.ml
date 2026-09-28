(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Difftool.mli *)

type caps = < Cap.stdout; Cap.stderr; Cap.stdin; Cap.open_in; Cap.argv >

exception Fatal of string

let fatal fmt = Printf.ksprintf (fun s -> raise (Fatal s)) fmt

type kind = Regular | Directory | Other

let stat path =
  if path = "-" then Some Other
  else match Unix.stat path with
    | { st_kind = S_REG; _ } -> Some Regular
    | { st_kind = S_DIR; _ } -> Some Directory
    | _ -> Some Other
    | exception Unix.Unix_error _ -> None

let contents path =
  try if path = "-" then In_channel.input_all stdin else In_channel.with_open_bin path In_channel.input_all
  with Sys_error _ -> fatal "cannot open %s" path

(* --help: how, by examples, each one as it runs (-h, diff's, its usage) *)
let diff_help = {|usage: mini-diff [-abcefmnruw] file1 ... file2
Plan 9's diff, twin: the lines that differ; exit 0 the same, 1 some, 2 an error.
Files or directories ("-" standard input); several files against a directory.
  mini-diff a b          2c2 / < two / --- / > 2 : line 2 of a became b's line 2
  mini-diff -u a b       unified: --- a, +++ b, @@ -1,3 +1,4 @@, -two, +2, +four
  mini-diff -e a b       an ed script making b from a (-f: in forward order)
  mini-diff -n a b       a:2 c b:2, the files named at each change
  mini-diff -r d1 d2     directories, and their subdirectories (Only in d1: y)
-c -a: context, all of it; -w -b: blanks ignored, collapsed; -m: names shown.
|}

let merge3_help = {|usage: mini-merge3 mine base theirs
Plan 9's merge3, twin: two files changed from a common base, merged; exit 1
on a conflict, left in the output between <<<<<<<<<< mine, ========== original,
========== theirs, >>>>>>>>>>. For example:
  mini-merge3 mine base theirs > merged
|}

let diff_main (caps : < caps; .. >) =
  let args = List.tl (Array.to_list (CapSys.argv caps)) in
  if List.mem "--help" args then (Console.print caps diff_help; exit 0);
  let usage () = Console.eprint caps "usage: diff [-abcefmnrw] file1 ... file2\n"; exit 2 in
  let fl, files = try Flags.parse ~flags:"efncauwbrmh" ~with_arg:"" args with Flags.Usage -> usage () in
  if Flags.has fl 'h' then usage ();
  (* the last format flag wins *)
  let mode = List.fold_left (fun m (c, _) -> match c with
    | 'e' -> Diff.Ed | 'f' -> Forward | 'n' -> Numbered | 'c' -> Context | 'a' -> All | 'u' -> Unified | _ -> m) Diff.Normal fl in
  let ws = List.fold_left (fun w (c, _) -> match c with 'w' -> Diff.Strip | 'b' -> Collapse | _ -> w) Diff.Exact fl in
  let rflag = Flags.has fl 'r' in
  let mflag = ref (Flags.has fl 'm') in
  let anychange = ref false in
  (* Bprint's output waits in Bio's 8K buffer; print's (the binary
   * message) goes out at once, ahead of it *)
  let bio = Buffer.create 8192 in
  let flush () = Console.print caps (Buffer.contents bio); Buffer.clear bio in
  let out s = Buffer.add_string bio s; if Buffer.length bio >= 8192 then flush () in
  let diffreg f t =
    let a = contents f and b = contents t in
    match Diff.read ws f a, Diff.read ws t b with
    | Some x, Some y ->
        let d = Diff.compute ws x y in
        if Diff.differ d then anychange := true;
        out (Diff.output ~header:!mflag mode d)
    | _ -> if a <> b then Console.print caps (Printf.sprintf "binary files %s %s differ\n" f t) in
  let rec diff f t level =
    let fk = match stat f with Some k -> k | None -> fatal "cannot stat %s" f in
    let tk = match stat t with Some k -> k | None -> fatal "cannot stat %s" t in
    match fk, tk with
    | Directory, Directory ->
        if rflag || level = 0 then diffdir f t level
        else out (Printf.sprintf "Common subdirectories: %s and %s\n" f t)
    | (Regular | Other), (Regular | Other) -> diffreg f t
    | (Regular | Other), Directory -> diffreg f (Filename.concat t (Filename.basename f))
    | Directory, _ -> diffreg (Filename.concat f (Filename.basename t)) t
  and diffdir f t level =
    let scan d = try List.sort compare (Array.to_list (Sys.readdir d)) with Sys_error _ ->
      Console.eprint caps (Printf.sprintf "diff: can't open %s\n" d); [] in
    let rec go = function
      | x :: xs, y :: ys when x = y -> diff (f ^ "/" ^ x) (t ^ "/" ^ y) (level + 1); go (xs, ys)
      | x :: xs, (y :: _ as ys) when x < y -> only f x; go (xs, ys)
      | x :: xs, [] -> only f x; go (xs, [])
      | xs, y :: ys -> only t y; go (xs, ys)
      | [], [] -> ()
    and only d x = if mode = Normal || mode = Numbered then out (Printf.sprintf "Only in %s: %s\n" d x) in
    go (scan f, scan t)
  in
  try
    if List.length files < 2 then usage ();
    let last = List.nth files (List.length files - 1) in
    let firsts = List.filteri (fun i _ -> i < List.length files - 1) files in
    (match stat last with
     | None -> fatal "can't stat %s" last
     | Some tk ->
         if List.length files > 2 then (if tk <> Directory then fatal "not directory: %s" last; mflag := true)
         else (match stat (List.hd files) with
               | None -> fatal "can't stat %s" (List.hd files)
               | Some fk -> if fk = Directory && tk = Directory then mflag := true));
    List.iter (fun f -> diff f last 0) firsts;
    flush ();
    if !anychange then 1 else 0
  with Fatal m -> flush (); Console.eprint caps ("diff: " ^ m ^ "\n"); 2

let merge3_main (caps : < caps; .. >) =
  match List.tl (Array.to_list (CapSys.argv caps)) with
  | [ ("-h" | "--help") ] -> Console.print caps merge3_help; 0
  | [ ours; base; theirs ] -> (
      try
        let read f = match Diff.read Exact f (contents f) with Some x -> x | None -> fatal "cannot merge binaries" in
        let left = read ours and base = read base and right = read theirs in
        let text, conflict = Merge3.merge ~left ~base ~right in
        Console.print caps text;
        if conflict then 1 else 0
      with Fatal m -> Console.eprint caps ("merge3: " ^ m ^ "\n"); 2)
  | _ -> Console.eprint caps "usage: merge3 theirs base ours\n"; 2
