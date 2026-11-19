(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Sysseg.mli *)

open Types
open Errors

let pgsize = Mmu.pgsize

let overlap (p : proc) b len =
  try Some (List.find (fun s -> b < s.top && s.base < b + len) p.segs) with Not_found -> None

(* va 0: below the stack, then below each segment in the way, as
 * principia's segattach looks for a hole *)
let syssegattach (p : proc) attr cls va len =
  if cls <> "memory" && cls <> "shared" then raise (Error "bad segment class");
  let base = va land lnot (pgsize - 1) in
  let len = Mmu.pgroundup (len + (va - base)) in
  if len = 0 then raise (Error ebadarg);
  let base =
    if va <> 0 then begin
      if base < pgsize || overlap p base len <> None then raise (Error esoverlap);
      base
    end else begin
      let stack = try List.find (fun s -> s.kind = Stack) p.segs with Not_found -> raise (Error ebadarg) in
      let rec down b =
        if b < pgsize then raise (Error enovmem)
        else match overlap p b len with
          | Some s -> down (s.base - len)
          | None -> b in
      down (stack.base - len)
    end in
  p.segs <- p.segs @ [ Fault.create (Attached attr) base (base + len) None 0 0 ];
  base

let attached (p : proc) va =
  match Fault.segment p va with
  | Some s -> (match s.kind with Attached _ -> s | _ -> raise (Error ebadarg))
  | None -> raise (Error ebadarg)

let syssegdetach (p : proc) va = Fault.detach p (attached p va); 0

(* (any segment of the process but its text, as Plan 9's segfree: the
 * data and the bss too, whose pages given back are zeros, or the
 * file's, when touched again. mini-ml's runtime gives the half its
 * collector has just emptied (gc.c's major).
 * old: let s = attached p va, a segattach's segment only) *)
let syssegfree (p : proc) va len =
  let s = match Fault.segment p va with
    | Some s when s.kind <> Text -> s
    | _ -> raise (Error ebadarg) in
  Fault.free_range p s (Mmu.pgroundup va) ((va + len) land lnot (pgsize - 1));
  0

let syssegflush (p : proc) va len = Fault.sync p va len; 0
