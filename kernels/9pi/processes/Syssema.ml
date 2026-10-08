(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Syssema.mli *)

open Types
open Errors
open Usermem

(* the waiters' channel: the int's physical address *)
let sem_pa (p : proc) addr =
  if addr land 3 <> 0 then raise (Error ebadarg);
  Fault.validaddr p addr 4;
  match Mmu.lookup p.pgdir addr with Some pg -> pg.Page.pa + (addr land 0xfff) | None -> raise (Error ebadarg)

let sem_get p addr = Machine.get_le32 (user_read p addr 4) 0
let sem_set p addr v = user_write p addr (Machine.le32 v)

(* canacquire: the value decremented if positive *)
let canacquire p addr = let v = sem_get p addr in if v > 0 then begin sem_set p addr (v - 1); true end else false

let rec syssemacquire (p : proc) addr block =
  if canacquire p addr then 1
  else if not block then 0
  else begin Proc.sleep (Semaphore (sem_pa p addr)); syssemacquire p addr block end

let systsemacquire (p : proc) addr ms =
  let until = !Proc.ticks + ((ms + 9) / 10) in
  let rec go () =
    if canacquire p addr then 1
    else if !Proc.ticks >= until then 0
    else begin Proc.sleep Ticks; go () end in
  ignore (sem_pa p addr);
  go ()

let syssemrelease (p : proc) addr n =
  if n < 0 then raise (Error ebadarg);
  let v = sem_get p addr + n in
  sem_set p addr v;
  Proc.wakeup (Semaphore (sem_pa p addr));
  v
