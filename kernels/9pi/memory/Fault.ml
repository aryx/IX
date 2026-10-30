(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Fault.mli *)

open Types
open Errors

let pgsize = Mmu.pgsize

let create kind base top image fstart flen =
  { kind = kind; base = base; top = top; image = image; fstart = fstart; flen = flen;
    pages = Hashtbl.create 16; sref = 1 }

let segment (p : proc) va = try Some (List.find (fun s -> va >= s.base && va < s.top) p.segs) with Not_found -> None

(* all of [n] bytes at [off] (fewer: the file's end) *)
let read_image c off n =
  let d = Dev.find c.dev in
  let b = Buffer.create n in
  let rec go () =
    if Buffer.length b < n then begin
      let s = d.Dev.read c (n - Buffer.length b) (off + Buffer.length b) in
      if s <> "" then begin Buffer.add_string b s; go () end
    end in
  go ();
  Buffer.contents b

let map pgdir pg pa = if not (Mmu.map pgdir pg pa) then raise (Error enovmem)

(* SG_RONLY, segattach's attribute: the segment's pages mapped to be
 * read only, a write the program's trap *)
let sg_ronly = 0o40

let map_seg pgdir s pg pa =
  match s.kind with
  | Attached a when a land sg_ronly <> 0 -> if not (Mmu.map_ro pgdir pg pa) then raise (Error enovmem)
  | _ -> map pgdir pg pa

(* a page of s made: zeroed, or read from the image; recorded, mapped *)
let make pgdir s pg =
  (* the image read first: a read may sleep, another sharer make it *)
  let data = match s.image with
    | Some c when pg - s.base < s.flen -> Some (read_image c (s.fstart + pg - s.base) (min pgsize (s.flen - (pg - s.base))))
    | _ -> None in
  if not (Hashtbl.mem s.pages pg) then begin
    let pa = match Mmu.kalloc () with Some pa -> pa | None -> raise (Error enovmem) in
    (match data with Some d -> Machine.Phys.write pa d | None -> ());
    Hashtbl.add s.pages pg pa
  end;
  map_seg pgdir s pg (Hashtbl.find s.pages pg)

let fill pgdir s pg =
  try map_seg pgdir s pg (Hashtbl.find s.pages pg) with Not_found -> make pgdir s pg

(* Copy on write (Plan 9's fork and fixfault): a fork gives the child
 * the data and bss pages of its parent, mapped to be read only in
 * both, and a page is copied when one of them writes it. How many
 * segments hold a physical page, when more than one; the others hold
 * theirs alone. A segment that several processes share (RFMEM) holds
 * only pages of its own (dup), so that a copy is seen by all who share
 * it. The stack is copied at the fork as before: the kernel writes the
 * child's in it (its pid, Sysproc).
 * What it saves: every Playground program forks four helpers at its
 * start (Plan9_loop: the keys, the mouse, the clock, the keys held),
 * and each had a copy of all the parent had touched, 20 MB for
 * mini-page. `page /lib/pdf/tex.pdf` under QEMU, the user's pages in
 * use (/dev/swap): 43,691 (170 MB of the Pi1's 352) before, 28,327
 * (110 MB) after (2026-10-22). Before it, troff.pdf's start failed at
 * a fork, and a zoom ended mini-page, or rio, the next to ask. *)
let holders : (int, int) Hashtbl.t = Hashtbl.create 1024
let held pa = try Hashtbl.find holders pa with Not_found -> 1

(* a binding changed (Hashtbl.replace: ocaml-light's never grows the
 * table and goes down a bucket by a call per binding, and a table of
 * thousands of pages took a process's kernel stack, 16 KB, and the
 * next one's: docs/plans/bugs/ocaml_light.md) *)
let set (t : (int, int) Hashtbl.t) k v = Hashtbl.remove t k; Hashtbl.add t k v

(* one holder less: the page freed by its last *)
let let_go pa =
  match held pa with
  | 1 -> Mmu.kfree pa
  | 2 -> Hashtbl.remove holders pa
  | n -> set holders pa (n - 1)

let shareable s = s.kind = Data || s.kind = Bss

(* the page at pg of s made the segment's own, mapped to be written:
 * copied if another holds it too *)
let own pgdir s pg =
  let pa = Hashtbl.find s.pages pg in
  let pa =
    if held pa = 1 then pa
    else begin
      let npa = match Mmu.kalloc () with Some x -> x | None -> raise (Error enovmem) in
      Machine.Phys.copy npa pa pgsize;
      let_go pa;
      set s.pages pg npa;
      npa
    end in
  map pgdir pg pa

(* a page mapped to be read only, of a segment that may share it *)
let shared pgdir s pg =
  shareable s && (match Mmu.lookup pgdir pg with Some page -> page.perm = Page.User_ro | None -> false)

let fault (p : proc) va =
  match segment p va with
  | None -> false
  | Some s ->
      let pg = va land lnot (pgsize - 1) in
      (* a mapped page's fault is its rights': a write to a page shared
       * since a fork, or the program's error *)
      if shared p.pgdir s pg then begin own p.pgdir s pg; Machine.mmu_switch p.pgdir; true end
      else if Mmu.mapped p.pgdir pg then false
      else begin fill p.pgdir s pg; true end

(* (a page shared since a fork is made the process's own here, though
 * the call may only read it: the kernel then writes a user's page
 * through its physical address, and a semaphore's address is its
 * page's) *)
let validaddr (p : proc) addr len =
  let owned = ref false in
  let rec go pg =
    if pg < addr + len then begin
      (match segment p pg with
       | Some s ->
           if shared p.pgdir s pg then begin own p.pgdir s pg; owned := true end
           else if not (Mmu.mapped p.pgdir pg) then fill p.pgdir s pg
       | None -> ());
      go (pg + pgsize)
    end in
  if len > 0 then go (addr land lnot (pgsize - 1));
  if !owned then Machine.mmu_switch p.pgdir

let page pgdir s va = fill pgdir s (va land lnot (pgsize - 1))

let release pgdir segs =
  List.iter (fun s ->
    s.sref <- s.sref - 1;
    if s.sref = 0 then begin
      Hashtbl.iter (fun _ pa -> let_go pa) s.pages;
      Hashtbl.clear s.pages;
      match s.image with Some c -> Kchan.close c | None -> ()
    end) segs;
  if pgdir <> 0 then Mmu.free_tables pgdir

let dup s from pgdir share =
  if share then begin
    (* (its pages made its own first: one copied later would be the
     * copier's only) *)
    if shareable s then begin
      let pgs = Hashtbl.fold (fun pg _ acc -> pg :: acc) s.pages [] in
      List.iter (fun pg -> if held (Hashtbl.find s.pages pg) > 1 then own from s pg) pgs
    end;
    s.sref <- s.sref + 1;
    Hashtbl.iter (fun pg pa -> map_seg pgdir s pg pa) s.pages;
    s
  end else if shareable s && s.sref = 1 then begin
    (match s.image with Some c -> Kchan.incref c | None -> ());
    let n = create s.kind s.base s.top s.image s.fstart s.flen in
    (try
       Hashtbl.iter (fun pg pa ->
         set holders pa (held pa + 1);
         Hashtbl.add n.pages pg pa;
         if not (Mmu.map_ro from pg pa && Mmu.map_ro pgdir pg pa) then raise (Error enovmem)) s.pages
     with e -> release 0 [ n ]; raise e);
    n
  end else begin
    (match s.image with Some c -> Kchan.incref c | None -> ());
    let n = create s.kind s.base s.top s.image s.fstart s.flen in
    Hashtbl.iter (fun pg pa ->
      let npa = match Mmu.kalloc () with Some x -> x | None -> raise (Error enovmem) in
      Machine.Phys.copy npa pa pgsize;
      Hashtbl.add n.pages pg npa;
      map pgdir pg npa) s.pages;
    n
  end

let shrink (p : proc) s newtop =
  if s.sref > 1 then raise (Error einuse);
  let gone = ref [] in
  Hashtbl.iter (fun pg pa -> if pg >= newtop then gone := (pg, pa) :: !gone) s.pages;
  List.iter (fun (pg, pa) -> Hashtbl.remove s.pages pg; Mmu.unmap p.pgdir pg; let_go pa) !gone;
  (* the TLB flushed *)
  Machine.mmu_switch p.pgdir

(* segdetach: the segment out of the process, its pages out of its
 * table, freed by the segment's last process *)
let detach (p : proc) s =
  Hashtbl.iter (fun pg _ -> Mmu.unmap p.pgdir pg) s.pages;
  p.segs <- List.filter (fun x -> x != s) p.segs;
  release 0 [ s ];
  Machine.mmu_switch p.pgdir

(* segfree: the pages wholly in [lo, hi) freed, zeros at their next
 * touch (Error einuse when shared) *)
let free_range (p : proc) s lo hi =
  if s.sref > 1 then raise (Error einuse);
  let gone = ref [] in
  Hashtbl.iter (fun pg pa -> if pg >= lo && pg + pgsize <= hi then gone := (pg, pa) :: !gone) s.pages;
  List.iter (fun (pg, pa) -> Hashtbl.remove s.pages pg; Mmu.unmap p.pgdir pg; let_go pa) !gone;
  Machine.mmu_switch p.pgdir

(* segflush: the bytes of [va, va+len) the process wrote, through to
 * the memory and out of the instructions' cache, page by page (a page
 * not touched yet has nothing to tell); Error ebadarg outside the
 * process's segments *)
let sync (p : proc) va len =
  let rec go a =
    if a < va + len then begin
      let pg = a land lnot (pgsize - 1) in
      let n = min (pg + pgsize) (va + len) - a in
      (match segment p a with
       | Some s -> (try Machine.Phys.sync (Hashtbl.find s.pages pg + (a - pg)) n with Not_found -> ())
       | None -> raise (Error ebadarg));
      go (pg + pgsize)
    end in
  go va
