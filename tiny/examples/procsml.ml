(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* procsml: procs.c in ML, what a shell does for echo ... | its reader:
 * a pipe; fork, None in the child, Some of its pid here; in the child,
 * its standard output made the pipe's writing end (dup2), then exec,
 * the child becoming /bin/echo; in the parent, the pipe read to its
 * end, then wait for the child. It links TinyLibSystem, from /lib/ml
 * (the Buildfile beside it):
 *
 *	cd /examples; build procsml; ./procsml
 *)
module TSys = TinyLibSystem

let say caps s =
  TSys.write TSys.fd_stdout
    ("procsml " ^ string_of_int (TSys.getpid caps) ^ ": " ^ s ^ "\n")

let () =
  TSys.main "procsml" (fun caps _ ->
      let r, w = TSys.pipe caps in
      match TSys.fork caps with
      | None ->
          TSys.dup2 w TSys.fd_stdout;
          TSys.close r;
          TSys.close w;
          let why =
            TSys.exec caps (Fpath.v "/bin/echo")
              [ "echo"; "hello,"; "through"; "a"; "pipe" ] [] in
          TSys.write TSys.fd_stderr ("procsml: /bin/echo: " ^ why ^ "\n");
          Exit.Code 1
      | Some pid ->
          say caps ("child " ^ string_of_int pid ^ " forked");
          TSys.close w;
          say caps ("read: " ^ String.trim (TSys.read_all r));
          ignore (TSys.wait caps pid);
          say caps ("child " ^ string_of_int pid ^ " ended");
          Exit.OK)
