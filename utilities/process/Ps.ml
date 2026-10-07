(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-ps: Plan 9's ps (principia's utilities/process/ps.c): the
 * processes, a line each, by their numbers: the owner, the number, the
 * time spent in the program and in the kernel for it (minutes and
 * seconds), its memory, its state, its name. -a: its arguments and not
 * its name alone; -p: its two priorities; -r: the time since it started.
 * All of it read in /proc (a directory a process, its status a line of
 * words): on another system there is none. *)

type caps = < Cap.readdir; Cap.open_in; Cap.stdout; Cap.stderr >

exception Fatal of string * string

(* a small file's text; None when it cannot be read *)
let contents (caps : < caps; .. >) file =
  match FS.open_in_fd caps file with
  | exception Unix.Unix_error _ -> None
  | fd ->
      let buf = Bytes.create 4096 in
      let n = try Unix.read fd buf 0 4096 with Unix.Unix_error _ -> -1 in
      Unix.close fd;
      if n < 0 then None else Some (Bytes.sub_string buf 0 n)

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
    let args = ref false and priorities = ref false and real = ref false in
    List.iter (fun a ->
      if String.length a > 1 && a.[0] = '-' then
        String.iter (function 'a' -> args := true | 'p' -> priorities := true | 'r' -> real := true | _ -> ()) a) (List.tl (Array.to_list argv));
    let failed what e = raise (Fatal (what, Unix.error_message e)) in
    let entries = try Sys_plan9.dirread caps "/proc" with Unix.Unix_error (e, _, _) -> failed "/proc" e in
    if entries = [] then begin Console.eprint caps "ps: empty directory /proc\n"; raise (Fatal ("empty", "")) end;
    let number s = match int_of_string_opt s with Some n -> n | None -> 0 in
    let pids = List.sort (fun a b -> compare (number a) (number b)) (List.map (fun (d : Sys_plan9.dir) -> d.name) entries) in
    let out = Buffer.create 4096 in
    List.iter (fun pid ->
      match contents caps ("/proc/" ^ pid ^ "/status") with
      | None | Some "" -> ()
      | Some status ->
          (* its words: the name, the owner, the state, six times, the memory, two priorities *)
          let w = Array.of_list (List.filter (fun x -> x <> "") (String.split_on_char ' ' (String.map (fun c -> if c = '\n' || c = '\t' then ' ' else c) status))) in
          if Array.length w < 11 then raise (Fatal ("not enough entries", ""));
          let seconds k = number w.(k) / 1000 in
          let user = seconds 3 and sys = seconds 4 and since = seconds 5 in
          let since =
            if not !real then ""
            else Printf.sprintf "%12s"
                (if since >= 86400 then Printf.sprintf " %d:%02d:%02d:%02d" (since / 86400) (since / 3600 mod 24) (since / 60 mod 60) (since mod 60)
                 else if since >= 3600 then Printf.sprintf " %d:%02d:%02d" (since / 3600) (since / 60 mod 60) (since mod 60)
                 else Printf.sprintf " %d:%02d" (since / 60) (since mod 60)) in
          let pri = if !priorities then Printf.sprintf " %2d %2d" (number w.(9)) (number w.(10)) else "" in
          let state = if String.length w.(2) > 8 then String.sub w.(2) 0 8 else w.(2) in
          Buffer.add_string out (Printf.sprintf "%-10s %8s%s %4d:%02d %3d:%02d %s %7dK %-8s " w.(1) pid since (user / 60) (user mod 60) (sys / 60) (sys mod 60) pri (number w.(8)) state);
          let said =
            if not !args then w.(0)
            else match contents caps ("/proc/" ^ pid ^ "/args") with
              | None -> w.(0) ^ " ?"
              | Some "" -> w.(0)
              | Some a -> String.map (fun c -> if c = '\n' then ' ' else c) a in
          Buffer.add_string out (said ^ "\n")) pids;
    if Buffer.length out = 0 then raise (Fatal ("no processes; bad #p", ""));
    Console.print caps (Buffer.contents out);
    Exit.OK
  with Fatal (what, why) ->
    if what <> "empty" then Console.eprint caps (Printf.sprintf "ps: %s: error: %s\n" what why);
    Exit.Err what

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
