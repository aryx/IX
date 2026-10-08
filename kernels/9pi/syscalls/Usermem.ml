(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Usermem.mli *)

open Types
open Errors

let errmax = 128
let maxpath = 1024

let user_string (p : proc) addr max =
  Fault.validaddr p addr max;
  match Mmu.read_string p.pgdir addr max with Some s -> s | None -> raise (Error ebadarg)

let user_read (p : proc) addr n =
  Fault.validaddr p addr n;
  match Mmu.read p.pgdir addr n with Some s -> s | None -> raise (Error ebadarg)

let user_write (p : proc) addr s =
  Fault.validaddr p addr (String.length s);
  if not (Mmu.copyout p.pgdir addr s) then raise (Error ebadarg)

let user_snprint (p : proc) addr n s =
  let s = if String.length s >= n then String.sub s 0 (max 0 (n - 1)) else s in
  if n > 0 then user_write p addr (s ^ "\000");
  String.length s

let offset lo hi =
  if lo = -1 && hi = -1 then None
  else if hi < 0 then raise (Error enegoff)
  else if hi > 0 || lo < 0 then raise (Error ebadarg)
  else Some lo
