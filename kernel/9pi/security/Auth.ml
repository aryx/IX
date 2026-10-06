(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Auth.mli *)

open Types
open Errors
open Usermem

let sysfauth (p : proc) fd aname =
  let c = Kchan.fdtochan p fd (Some Ordwr) in
  let ac = Devmnt.auth c aname in
  ac.opened <- Some { (Kchan.mode_of_int 2) with cexec = true };
  Kchan.fdalloc p ac

let sysfversion (p : proc) fd msize buf n =
  let v = user_read p buf n in
  if n = 0 || (try ignore (String.index v '\000'); false with Not_found -> true) then raise (Error ebadarg);
  Devmnt.version (Kchan.fdtochan p fd (Some Ordwr)) msize v
