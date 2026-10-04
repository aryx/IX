(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Auth.mli *)

open Types
open Errors
open Usermem

let sysfauth (p : proc) fd aname =
  let c = Chan.fdtochan p fd (Some Ordwr) in
  let ac = Devmnt.auth c aname in
  ac.opened <- Some { (Chan.mode_of_int 2) with cexec = true };
  Chan.fdalloc p ac

let sysfversion (p : proc) fd msize buf n =
  let v = user_read p buf n in
  if n = 0 || (try ignore (String.index v '\000'); false with Not_found -> true) then raise (Error ebadarg);
  Devmnt.version (Chan.fdtochan p fd (Some Ordwr)) msize v
