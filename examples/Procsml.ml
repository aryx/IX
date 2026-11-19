(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* procsml: procs.c in ML, what a shell does for echo ... | its reader,
 * with Unix's calls (lib_core's Unix, which on mini-9pi is written over
 * Plan 9's calls: lib_core/system/plan9/Unix.ml): a pipe; fork, 0 in
 * the child, its pid here; in the child, its standard output made the
 * pipe's writing end (dup2), then exec, the child becoming /bin/echo;
 * in the parent, the pipe read to its end, then wait for the child.
 * Each call that reaches the system takes the capability for it
 * (CapUnix), and main's type says which ones it needs. The mkfile
 * beside it builds it:
 *
 *     cd /src/examples; mk; ../_mk/5-plan9/examples/procsml
 *)

type caps = < Cap.pipe; Cap.fork; Cap.exec; Cap.wait; Cap.env; Cap.stdout >

(* (by the descriptor, not print_string: a line kept in a channel's
 * buffer at the fork would be the child's too) *)
let say (caps : < Cap.env; Cap.stdout; .. >) s =
  let line = Printf.sprintf "procsml %d: %s\n" (CapUnix.getpid caps ()) s in
  ignore (Unix.write_substring (Console.stdout_fd caps) line 0 (String.length line))

let main (caps : < caps; .. >) : Exit.t =
  let r, w = CapUnix.pipe caps ~cloexec:false () in
  match CapUnix.fork caps () with
  | 0 ->
      Unix.dup2 w Unix.stdout;
      Unix.close r;
      Unix.close w;
      (* (with no environment: echo reads none) *)
      CapUnix.execve caps "/bin/echo" [| "echo"; "hello,"; "through"; "a"; "pipe" |] [||]
  | pid ->
      say caps (Printf.sprintf "child %d forked" pid);
      Unix.close w;
      say caps ("read: " ^ String.trim (In_channel.input_all (Unix.in_channel_of_descr r)));
      ignore (CapUnix.waitpid caps [] pid);
      say caps (Printf.sprintf "child %d ended" pid);
      Exit.OK

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps)))
