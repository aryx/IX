(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Usermem.mli *)

open Types
open Errors

let errmax = 128
let maxpath = 1024

let user_read (p : proc) addr n =
  Fault.validaddr p addr n;
  match Mmu.read p.pgdir addr n with Some s -> s | None -> raise (Error ebadarg)

(* a page at a time, each faulted in when reached: max may be the
 * stack's 256 KB (exec's arguments), and only the pages up to the NUL
 * are touched
 * old: Fault.validaddr p addr max;
 *      match Mmu.read_string p.pgdir addr max with
 *      | Some s -> s | None -> raise (Error ebadarg) *)
let user_string (p : proc) addr max =
  let b = Buffer.create 64 in
  let rec go a left =
    if left <= 0 then raise (Error ebadarg);
    let k = min left (Mmu.pgsize - (a land (Mmu.pgsize - 1))) in
    let s = user_read p a k in
    try Buffer.add_string b (String.sub s 0 (String.index s '\000')); Buffer.contents b
    with Not_found -> Buffer.add_string b s; go (a + k) (left - k) in
  go addr max

let user_write (p : proc) addr s =
  Fault.validaddr p addr (String.length s);
  if not (Mmu.copyout p.pgdir addr s) then raise (Error ebadarg)

(* another process's memory, for its debugger (/proc/n/mem): its pages
 * made where they are not yet, read and written by their physical
 * addresses, so the text too (a breakpoint; the instructions' cache
 * kept right). A text a fork shares is written for both (Plan 9's
 * txt2data copies it: not yet; a debugger's process is an exec's) *)
let debug_page (p : proc) a =
  match Fault.segment p a with
  | None -> raise (Error ebadarg)
  | Some s ->
      let pg = a land lnot (Mmu.pgsize - 1) in
      if not (Mmu.mapped p.pgdir pg) then Fault.page p.pgdir s a;
      (match Mmu.lookup p.pgdir pg with Some page -> page.pa + (a - pg) | None -> raise (Error ebadarg))

let rec debug_read (p : proc) a n =
  if n <= 0 then ""
  else begin
    let m = min n (Mmu.pgsize - (a land (Mmu.pgsize - 1))) in
    let s = Machine.Phys.read (debug_page p a) m in
    s ^ debug_read p (a + m) (n - m)
  end

let rec debug_write (p : proc) a s =
  let n = String.length s in
  if n > 0 then begin
    let m = min n (Mmu.pgsize - (a land (Mmu.pgsize - 1))) in
    let pa = debug_page p a in
    Machine.Phys.write pa (String.sub s 0 m);
    Machine.Phys.sync pa m;
    debug_write p (a + m) (String.sub s m (n - m))
  end

let user_snprint (p : proc) addr n s =
  let s = if String.length s >= n then String.sub s 0 (max 0 (n - 1)) else s in
  if n > 0 then user_write p addr (s ^ "\000");
  String.length s

let offset lo hi =
  if lo = -1 && hi = -1 then None
  else if hi < 0 then raise (Error enegoff)
  else if hi > 0 || lo < 0 then raise (Error ebadarg)
  else Some lo
