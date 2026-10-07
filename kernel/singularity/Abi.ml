(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Abi.mli *)

let exit = 0
let debug = 1

(* the call's word i; n bytes at the address its word i is (cross.c) *)
external arg : int -> int = "abi_arg"
external bytes : int -> int -> string = "abi_bytes"

let call () : int =
  let n = arg 0 in
  if n = exit then begin Process.exit (arg 1); 0 end
  else if n = debug then begin
    let len = arg 2 in
    Machine.print (bytes 1 len);
    len
  end
  else -1

(* nothing the kernel raises reaches a process's code: it ends *)
let () =
  Callback.register "abi" (fun () ->
    try call () with e -> Machine.print ("mini-singularity: " ^ Printexc.to_string e ^ " in a call\n"); Process.exit 2; -1)
