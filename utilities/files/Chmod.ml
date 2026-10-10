(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-chmod: Plan 9's chmod (principia's utilities/files/chmod.c):
 * chmod 644 file ..., the permissions in octal; or chmod [who]op[what]
 * file ...: who is letters of u, g, o, a (the owner, the group, the
 * others, all: all when none), op is + (given), - (taken) or = (these
 * and no other), what is letters of r, w, x and of a (append only), l
 * (one opener at a time), t (temporary), which are the file's and not
 * someone's.
 *
 * plan9-is-cleaner:
 * What is not there: Unix's set-user-id bit, by which a program runs
 * with its owner's rights and not its caller's (Dennis Ritchie's
 * invention, and a patent of 1979), and with it the list of programs
 * that are root for a moment and must not be fooled. Plan 9 has no
 * root: what needs a right is asked of a file server that has it.
 * The three bits it adds say how a file is used, not by whom: append
 * only (a log nobody can rewrite), exclusive use (a lock: one opener
 * at a time), temporary (not in the nightly dump).
 *
 * References: chmod(1); stat(5), the mode's bits. *)

type caps = < Cap.open_out; Cap.readdir; Cap.stderr >

(* a mode's 32 bits but the directory's (bit 31, which arm's int does
 * not have, and chmod does not change): the permissions' 9, and the
 * top byte's append, exclusive and temporary *)
let all rwx = (rwx lsl 6) lor (rwx lsl 3) lor rwx
let dmappend = Sys_plan9.dmappend lsl 24 and dmexcl = Sys_plan9.dmexcl lsl 24 and dmtmp = Sys_plan9.dmtmp lsl 24

(* the bits a specification speaks of, and what it makes them; None
 * when it is not one *)
let parse spec =
  match int_of_string_opt ("0o" ^ spec) with
  | Some mode when String.for_all (fun c -> c >= '0' && c <= '7') spec -> Some (all 7, mode)
  | _ ->
      let n = String.length spec in
      let rec who k mask =
        if k >= n then None
        else match spec.[k] with
          | 'u' -> who (k + 1) (mask lor (7 lsl 6))
          | 'g' -> who (k + 1) (mask lor (7 lsl 3))
          | 'o' -> who (k + 1) (mask lor 7)
          | 'a' -> who (k + 1) (mask lor all 7)
          | op -> Some (k, op, mask) in
      match who 0 (dmappend lor dmexcl lor dmtmp) with
      | Some (k, (('+' | '-' | '=') as op), mask) ->
          let mask = if k = 0 then mask lor all 7 else mask in
          let what = String.sub spec (k + 1) (n - k - 1) in
          let bit = function 'r' -> all 4 | 'w' -> all 2 | 'x' -> all 1 | 'a' -> dmappend | 'l' -> dmexcl | 't' -> dmtmp | _ -> -1 in
          if String.exists (fun c -> bit c = -1) what then None
          else begin
            let mode = List.fold_left (fun m c -> m lor bit c) 0 (List.init (String.length what) (String.get what)) in
            Some ((if op = '=' then mask else mask land mode), (if op = '-' then lnot mode else mode))
          end
      | _ -> None

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  match List.tl (Array.to_list argv) with
  | spec :: (_ :: _ as files) -> (
      match parse spec with
      | None -> Console.eprint caps (Printf.sprintf "chmod: bad mode: %s\n" spec); Exit.Err "mode"
      | Some (mask, mode) ->
          List.iter (fun file ->
            match Sys_plan9.dirstat caps file with
            | exception Unix.Unix_error (e, _, _) -> Console.eprint caps (Printf.sprintf "chmod: can't stat %s: %s\n" file (Unix.error_message e))
            | (d : Sys_plan9.dir) ->
                let old = ((d.mode_type land 0x7f) lsl 24) lor d.perm in
                let now = (old land lnot mask) lor (mode land mask) in
                (try Sys_plan9.chmod caps file ((d.mode_type land 0x80) lor ((now lsr 24) land 0x7f)) (now land 0o777)
                 with Unix.Unix_error (e, _, _) -> Console.eprint caps (Printf.sprintf "chmod: can't wstat %s: %s\n" file (Unix.error_message e)))) files;
          Exit.OK)
  | _ -> Console.eprint caps "usage: chmod 0777 file ... or chmod [who]op[rwxalt] file ...\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
