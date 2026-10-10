(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-du: Plan 9's du (principia's utilities/misc/du.c): how much a
 * directory holds, in KB, and each directory in it: its files'
 * lengths, each rounded up to a block (1 KB), added. -a: each file
 * too; -s: only what is asked; -n: in bytes, each file; -b size: the
 * block's, in bytes (4k: 4096); -f: nothing said of what cannot be
 * read. A directory reached twice (a union, a bind) is counted once.
 * Not du.c's -e, -h, -p (other units), -q, -t, -u (a file's qid or
 * times in place of its size), -r. *)

type caps = < Cap.readdir; Cap.stdout; Cap.stderr >

exception Usage

(* %q: quoted when empty, or with a space, a control character or a quote *)
let quote name =
  if name <> "" && not (String.exists (fun c -> c <= ' ' || c = '\'') name) then name
  else "'" ^ String.concat "''" (String.split_on_char '\'' name) ^ "'"

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
    let all = ref false and only = ref false and quiet = ref false and block = ref 1024 and unit = ref 1024 in
    let rec options = function
      | "--" :: rest -> rest
      | a :: rest when String.length a > 1 && a.[0] = '-' ->
          let rec letters k rest =
            if k >= String.length a then options rest
            else match a.[k] with
              | 'a' -> all := true; letters (k + 1) rest
              | 's' -> only := true; letters (k + 1) rest
              | 'f' -> quiet := true; letters (k + 1) rest
              | 'n' -> all := true; block := 1; unit := 1; letters (k + 1) rest
              | 'b' ->
                  let v, rest =
                    if k + 1 < String.length a then String.sub a (k + 1) (String.length a - k - 1), rest
                    else match rest with v :: rest -> v, rest | [] -> raise Usage in
                  (* a number, then a k for each 1024 times *)
                  let rec ks n = if n > 0 && v.[n - 1] = 'k' then ks (n - 1) else n in
                  let digits = ks (String.length v) in
                  let size = match int_of_string_opt (String.sub v 0 digits) with Some n -> n | None -> 1 in
                  block := max 1 (size lsl (10 * (String.length v - digits)));
                  options rest
              | _ -> raise Usage in
          letters 1 rest
      | rest -> rest in
    let names = match options (List.tl (Array.to_list argv)) with [] -> [ "." ] | names -> names in
    (* (each line at once: a warning comes between two of them, where it happened) *)
    let print amount name =
      Console.print caps (Printf.sprintf "%d\t%s\n" ((amount + !unit - 1) / !unit) (quote name));
      flush (Console.stdout caps) in
    let warn name e = if not !quiet then Console.eprint caps (Printf.sprintf "du: %s: %s\n" name (Unix.error_message e)) in
    let rounded n = if !block = 1 then n else (n + !block - 1) / !block * !block in
    let is_dir (d : Sys_plan9.dir) = d.qid_type land Sys_plan9.dmdir <> 0 in
    (* the directories gone into, by their identity for their server *)
    let seen = Hashtbl.create 64 in
    let rec du name (d : Sys_plan9.dir) =
      if not (is_dir d) then rounded d.length
      else match Sys_plan9.dirread caps name with
        | exception Unix.Unix_error (e, _, _) -> warn name e; 0
        | entries ->
            List.fold_left (fun total (e : Sys_plan9.dir) ->
              let full = name ^ "/" ^ e.name in
              if not (is_dir e) then begin
                let size = rounded e.length in
                if !all then print size full;
                total + size
              end
              else begin
                let id = e.qid_path, e.dev_type, e.dev in
                if e.name = "." || e.name = ".." || Hashtbl.mem seen id then total
                else begin
                  Hashtbl.replace seen id ();
                  let size = du full e in
                  if not !only then print size full;
                  total + size
                end
              end) 0 entries in
    List.iter (fun name ->
      match Sys_plan9.dirstat caps name with
      | d -> print (du name d) name
      | exception Unix.Unix_error (e, _, _) -> warn name e; print 0 name) names;
    Exit.OK
  with Usage -> Console.eprint caps "usage: du [-aefhnqstu] [-b size] [-p si-pfx] [file ...]\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
