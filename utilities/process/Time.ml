(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-time: Plan 9's time (principia's profilers/misc/time.c): a
 * command run, then on the standard error the time it took: in the
 * program (u), in the kernel for it (s), from its start to its end (r),
 * in seconds, and the command (its first words); its status after,
 * when it has one. The times are the kernel's, said with the child's
 * last words (Sys_plan9.last_times): zeros on another system. *)

type caps = < Cap.fork; Cap.exec; Cap.wait; Cap.stderr >

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  match List.tl (Array.to_list argv) with
  | [] -> Console.eprint caps "usage: time command\n"; Exit.Err "usage"
  | (prog :: _) as command ->
      let args = Array.of_list command in
      (match CapUnix.fork caps () with
       | 0 ->
           (* the command, as it is named; then in /bin when its name is no path *)
           let why = match CapUnix.execv caps prog args with _ -> "" | exception Unix.Unix_error (e, _, _) -> Unix.error_message e in
           let rooted p = String.length prog >= String.length p && String.sub prog 0 (String.length p) = p in
           let why = if rooted "/" || rooted "./" || rooted "../" then why
             else match CapUnix.execv caps ("/bin/" ^ prog) args with _ -> "" | exception Unix.Unix_error (e, _, _) -> Unix.error_message e in
           Console.eprint caps (Printf.sprintf "time: %s: %s\n" prog why);
           Sys_plan9.exits prog
       | pid ->
           let rec wait () = match CapUnix.waitpid caps [] pid with _ -> () | exception Unix.Unix_error (Unix.EINTR, _, _) -> wait () in
           wait ();
           let user, sys, real = Sys_plan9.last_times pid and words = Sys_plan9.last_words pid in
           let seconds ms letter = Printf.sprintf "%d.%02d%c" (ms / 1000) (ms mod 1000 / 10) letter in
           (* the command's five first words *)
           let shown = List.filteri (fun k _ -> k < 5) command @ (if List.length command > 5 then [ "..." ] else []) in
           (* its last words, without the name and the number before them *)
           let status =
             if words = "" then []
             else [ " # status=" ^ (match String.index_opt words ':' with
                                    | Some k when k + 1 < String.length words -> String.sub words (k + 1) (String.length words - k - 1)
                                    | _ -> words) ] in
           Console.eprint caps (String.concat " " ([ seconds user 'u'; seconds sys 's'; seconds real 'r'; "\t" ] @ shown @ status) ^ "\n");
           if words = "" then Exit.OK else Exit.Err words)

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
