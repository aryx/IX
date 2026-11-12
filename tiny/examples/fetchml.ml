(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* fetchml: fetch.c in ML, a document of another machine's by Gopher,
 * on the standard output: its port 70, the name written as a line, what
 * comes read to the end. TinyLibSystem.dial gives the connection's
 * descriptor (a Failure when nothing answers), by an address: the
 * wire's other end, 10.0.0.1, without one (tiny-machine -net dir serves
 * dir's files). It links TinyLibSystem, from /lib/ml (the Buildfile
 * beside it):
 *
 *	cd /examples; build fetchml; ./fetchml hello.txt
 *)
module TSys = TinyLibSystem

(* what comes, to the other end's end *)
let rec copy fd =
  let s = TSys.read fd 1024 in
  if s <> "" then (TSys.write TSys.fd_stdout s; copy fd)

let () =
  TSys.main "fetchml" (fun caps argv ->
      if Array.length argv < 2 then (
        TSys.write TSys.fd_stderr "usage: fetchml name [address]\n";
        Exit.Code 1)
      else begin
        let address = if Array.length argv > 2 then argv.(2) else "10.0.0.1" in
        let fd = TSys.dial caps address 70 in
        TSys.write fd (argv.(1) ^ "\r\n");
        copy fd;
        TSys.close fd;
        Exit.OK
      end)
