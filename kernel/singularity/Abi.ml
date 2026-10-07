(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Abi.mli *)

(* the call's word i; n bytes at the address its word i is (cross.c) *)
external arg : int -> int = "abi_arg"
external bytes : int -> int -> string = "abi_bytes"

(* a name's bytes, at most *)
let max_name = 64

let call () : int =
  match arg 0 with
  | 0 -> Process.exit (arg 1); 0
  | 1 ->
      let len = arg 2 in
      Machine.print (bytes 1 len);
      len
  | 2 -> Process.yield (); 0
  | 3 -> if arg 2 < 0 || arg 2 > max_name then -1 else Process.create true (bytes 1 (arg 2))
  | 4 -> Process.start true (arg 1)
  | 5 -> Process.join (arg 1)
  | _ -> -1

(* nothing the kernel raises reaches a process's code: it ends *)
let () =
  Callback.register "abi" (fun () ->
    try call () with e -> Machine.print ("mini-singularity: " ^ Printexc.to_string e ^ " in a call\n"); Process.exit 2; -1)
