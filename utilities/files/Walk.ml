(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-walk: what is under a directory, a path a line. Not one of
 * Plan 9's programs: 9front's walk, find's small cousin, written from
 * what it does and not from its source, so not byte for byte. The
 * selection is another program's (walk | grep '\.ml$'), as the action
 * (walk -f | xargs wc).
 *
 * A directory's entries, sorted by name, a directory before what it
 * holds; the directory named is not said itself, a file named is.
 * Without a name: the current directory's, the paths without "./".
 * -d only the directories, -f only the files, -n depth no deeper (1:
 * the entries, not theirs).
 *
 * Not 9front's -n min,max, -e (what to say of each: the size, the
 * time...), -t, -x, -u. A link to a directory is walked as one.
 *
 * others:
 * Unix's find walks and also selects (-name, -newer, -type) and acts
 * (-print, -exec, -delete), by a small language of its own that no
 * other program shares, with its own and, or, not and parentheses.
 * Plan 9 never had find: du -a | grep was the idiom, du's sizes cut
 * off. walk is the walk alone, with the shell's other programs for
 * the rest; what is lost is a test on something a path does not say
 * (a file's time) without a program more. *)

type caps = < Cap.readdir; Cap.stdout; Cap.stderr >

exception Usage

let help = "usage: walk [-df] [-n depth] [name ...]\n"

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
    let dirs = ref true and files = ref true and depth = ref max_int and ok = ref true in
    let rec options = function
      | "--" :: rest -> rest
      | "-n" :: n :: rest -> (match int_of_string_opt n with Some n when n >= 0 -> depth := n | _ -> raise Usage); options rest
      | a :: rest when String.length a > 1 && a.[0] = '-' ->
          String.iteri (fun k c -> if k > 0 then match c with 'd' -> files := false | 'f' -> dirs := false | _ -> raise Usage) a;
          options rest
      | rest -> rest in
    let names = options (List.tl (Array.to_list argv)) in
    let failed path e = ok := false; flush (Console.stdout caps); Console.eprint caps (Printf.sprintf "walk: %s: %s\n" path (Unix.error_message e)) in
    let is_dir (d : Sys_plan9.dir) = d.qid_type land Sys_plan9.dmdir <> 0 in
    let say (d : Sys_plan9.dir) path = if (if is_dir d then !dirs else !files) then Console.print caps (path ^ "\n") in
    (* the entries of [dir], which is [level - 1] deep; [prefix] before their names *)
    let rec walk dir prefix level =
      if level <= !depth then
        match Sys_plan9.dirread caps dir with
        | exception Unix.Unix_error (e, _, _) -> failed dir e
        | entries ->
            List.iter (fun (d : Sys_plan9.dir) ->
              let path = prefix ^ d.name in
              say d path;
              if is_dir d then walk path (path ^ "/") (level + 1))
              (List.sort (fun (a : Sys_plan9.dir) (b : Sys_plan9.dir) -> compare a.name b.name) entries) in
    (match names with
     | [] -> walk "." "" 1
     | _ ->
         List.iter (fun name ->
           match Sys_plan9.dirstat caps name with
           | exception Unix.Unix_error (e, _, _) -> failed name e
           | d -> if is_dir d then walk name (if name.[String.length name - 1] = '/' then name else name ^ "/") 1 else say d name)
           names);
    if !ok then Exit.OK else Exit.Err "errors"
  with Usage -> Console.eprint caps help; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
