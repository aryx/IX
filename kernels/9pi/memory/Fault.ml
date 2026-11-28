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

(* opti: a program's text kept after its last process, for the next
 * exec of the same file (Plan 9's cached images, its imagereclaim's
 * other half). The segment itself is kept, by one more reference, and
 * an exec that finds it maps all its pages at once: none is read from
 * the file again, and none faults. m-IX built on the card runs ml 700
 * times, each one's text 400 pages read, copied and faulted in, a
 * third of the build's page faults; and under QEMU a page that held
 * code is slow to write again, and its code is translated again
 * (plan_9pi_self_speed.md).
 * By the file: its device's number, its qid's path and version (Kfs
 * counts a file's changes), the text's length. Kfs's files, and the
 * kernel's own in /boot (Devroot: rc, echo and bind, which never
 * change, were most of the texts' pages still read); not a
 * server's, which may give no version. All are let go when their pages are
 * more than text_max, 64 MB, and when no page is left (Mmu.on_empty).
 * A kept text's pages are mapped to be read only, and a write to one
 * (a program's own, a debugger's breakpoint) takes the text out of the
 * cache first: unkeep.
 * old: exec's Fault.create Text ..., a new segment each time *)
let texts : (string, segment) Hashtbl.t = Hashtbl.create 61
let text_max = 16384

let text_key (s : segment) =
  match s.kind, s.image with
  | Text, Some c when c.dev = 'x' || c.dev = '/' -> Printf.sprintf "%c %d %d %d %d" c.dev c.devno c.qid.path c.qid.vers s.flen
  | _ -> ""
let kept s = let k = text_key s in k <> "" && (try Hashtbl.find texts k == s with Not_found -> false)

let map pgdir pg pa = if not (Mmu.map pgdir pg pa) then raise (Error enovmem)

(* SG_RONLY, segattach's attribute: the segment's pages mapped to be
 * read only, a write the program's trap *)
let sg_ronly = 0o40

let map_seg pgdir s pg pa =
  match s.kind with
  | Attached a when a land sg_ronly <> 0 -> if not (Mmu.map_ro pgdir pg pa) then raise (Error enovmem)
  | Text when kept s -> if not (Mmu.map_ro pgdir pg pa) then raise (Error enovmem)
  | _ -> map pgdir pg pa

(* A page for a process's fault. When none is left the process waits
 * for one, a tenth of a second at a time: another's exit gives its
 * pages back. Plan 9's newpage sleeps the same way (on palloc.r,
 * woken by a page's free; here the clock looks again, which needs no
 * wakeup in Mmu). A minute at most with no page given back by
 * anyone (Mmu.freed): every process may be waiting, and the one whose
 * minute ends first is refused as before, its pages then the others'.
 * While others give pages back it waits on: two mini-ld waited their
 * minute and were refused beside a build of games that went on for
 * ten (old: go (n - 1) whatever the others did). A note ends the wait
 * (Proc.tsleep raises it).
 * Seen in the whole build of ix on the card with four cores
 * (2026-11-18): four mini-ld at once, a copying collector's two
 * halves each, filled the Pi 2's 847 MB, and seven directories failed
 * with "virtual memory allocation failed"; one core never has two.
 * old: match Mmu.kalloc () with Some pa -> pa | None -> raise (Error enovmem) *)
let page_wait = 600
let page () =
  (* (the time slept counted: /dev/waits) *)
  let waited () =
    let t0 = Machine.timer_now () in
    Proc.tsleep 100;
    Proc.add_wait Proc.page_waited Proc.page_us ((Machine.timer_now () - t0) land 0x3fffffff) in
  let rec go n seen =
    match Mmu.kalloc () with
    | Some pa -> pa
    | None when !Mmu.freed <> seen -> waited (); go page_wait !Mmu.freed
    | None when n > 0 -> waited (); go (n - 1) seen
    | None -> raise (Error enovmem) in
  go page_wait !Mmu.freed

(* a page of s made: zeroed, or read from the image; recorded, mapped
 * (the time to get a zeroed one counted: /dev/lockstat's "in zeroing",
 * of the faults' and the calls' time) *)
let zeroing_part = Proc.part "zeroing"
let make pgdir s pg =
  (* the image read first: a read may sleep, another sharer make it *)
  let data = match s.image with
    | Some c when pg - s.base < s.flen -> Some (read_image c (s.fstart + pg - s.base) (min pgsize (s.flen - (pg - s.base))))
    | _ -> None in
  if not (Hashtbl.mem s.pages pg) then begin
    let t0 = Machine.timer_now () in
    let pa = page () in
    if data = None then Proc.part_add zeroing_part ((Machine.timer_now () - t0) land 0x3fffffff);
    (* (made by a sharer while this one waited for a page: given back) *)
    if Hashtbl.mem s.pages pg then Mmu.kfree pa
    else begin
      (match data with Some d -> Machine.Phys.write pa d | None -> ());
      Hashtbl.add s.pages pg pa
    end
  end;
  map_seg pgdir s pg (Hashtbl.find s.pages pg)

let fill pgdir s pg =
  try map_seg pgdir s pg (Hashtbl.find s.pages pg) with Not_found -> make pgdir s pg

(* opti: fault-around (Linux's fault_around_bytes, which maps a file's
 * pages already in its cache; here a heap's zeros). A zero fault of the
 * bss whose page below is the segment's already, a program walking up
 * its heap, makes the pages after it too, up to [around] in all: a
 * fault costs 70 µs under QEMU, the zeroing 19 of them (make self,
 * 2026-11-27: 9.3 million zero faults, 658 s of the lock), and a
 * copying collector's halves are walked up again after each segfree
 * (mini-ml's GIVEBACK: mini-ld's were half of those faults). Only the
 * walk up: a page made and never touched costs a fork its copy (dup),
 * and rc forks the most. Pages from the free list alone, while more
 * than [around_spare] are left: never a wait for one, nor the kept
 * texts given back (Mmu.on_empty). around = 1: none.
 * old: each page its own fault *)
let around = 16
let around_spare = 2048
let fill_around pgdir s pg =
  if around > 1 && s.kind = Bss && Hashtbl.mem s.pages (pg - pgsize) then begin
    let rec go q n =
      if n > 0 && q < s.top && Mmu.nfree () > around_spare
         && not (Hashtbl.mem s.pages q) then
        match Mmu.kalloc () with
        | Some pa ->
            Hashtbl.add s.pages q pa; map pgdir q pa; go (q + pgsize) (n - 1)
        | None -> () in
    go (pg + pgsize) (around - 1)
  end

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
(* (1021 buckets, not a power of two: a key is a page's address, a multiple
 * of 4096, and hashes to itself, so with 1024 all were in bucket 0 until
 * the table grew at 2,048. Hashtbl.remove goes down a bucket by a call per
 * binding: about 1,000 shared pages took a process's kernel stack, and the
 * next one's, whose return then jumped anywhere: docs/plans/bugs/ix.md.
 * old: Hashtbl.create 1024) *)
let holders : (int, int) Hashtbl.t = Hashtbl.create 1021
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

let release pgdir segs =
  List.iter (fun s ->
    s.sref <- s.sref - 1;
    if s.sref = 0 then begin
      Hashtbl.iter (fun _ pa -> let_go pa) s.pages;
      Hashtbl.clear s.pages;
      match s.image with Some c -> Kchan.close c | None -> ()
    end) segs;
  if pgdir <> 0 then Mmu.free_tables pgdir

(* a kept text out of the cache: the cache's reference given back *)
let unkeep s =
  if kept s then begin
    Hashtbl.remove texts (text_key s);
    release 0 [ s ]
  end

let unkeep_all () = List.iter unkeep (Hashtbl.fold (fun _ s l -> s :: l) texts [])

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
      if shared p.pgdir s pg then begin
        Proc.reaccount p Proc.a_fault_copy;
        own p.pgdir s pg; Machine.mmu_switch p.pgdir; true end
      (* (a write to a text's page mapped to be read only, a kept
       * text's, or one that was when this process mapped it: the text
       * no longer kept, the page the process's to write as any text's) *)
      else if s.kind = Text && (match Mmu.lookup p.pgdir pg with Some page -> page.perm = Page.User_ro | None -> false) then begin
        Proc.reaccount p Proc.a_fault_text;
        unkeep s;
        map p.pgdir pg (Hashtbl.find s.pages pg);
        Machine.mmu_switch p.pgdir;
        true
      end
      else if Mmu.mapped p.pgdir pg then false
      else begin
        (* (/dev/lockstat: a page there, mapped; or one made, read from
         * the image or zeroed: make's) *)
        let read = match s.image with Some _ -> pg - s.base < s.flen | None -> false in
        let zero = not read && not (Hashtbl.mem s.pages pg) in
        Proc.reaccount p (if Hashtbl.mem s.pages pg then Proc.a_fault_map
                          else if read then Proc.a_fault_read else Proc.a_fault_zero);
        fill p.pgdir s pg;
        if zero then fill_around p.pgdir s pg;
        true end

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

(* exec's text: the kept one of this file, all its pages mapped, or a
 * new one, kept from now on. c is the caller's reference to the file,
 * the segment's when it is new, closed when it is not. *)
let text pgdir base top (c : chan) flen =
  let s = create Text base top (Some c) 0 flen in
  let k = text_key s in
  match (if k = "" then None else try Some (Hashtbl.find texts k) with Not_found -> None) with
  | Some t when t.base = base && t.top = top ->
      t.sref <- t.sref + 1;
      (try Hashtbl.iter (fun pg pa -> if not (Mmu.map_ro pgdir pg pa) then raise (Error enovmem)) t.pages
       with e -> t.sref <- t.sref - 1; raise e);
      Kchan.close c;
      t
  | _ ->
      if k <> "" then begin
        if Hashtbl.fold (fun _ t n -> n + Hashtbl.length t.pages) texts 0 > text_max then unkeep_all ();
        (* (one of the same file at another address: not met, let go) *)
        (try unkeep (Hashtbl.find texts k) with Not_found -> ());
        Hashtbl.add texts k s;
        s.sref <- 2
      end;
      s

(* (and what was hooked before: Kfs's cache gives back some too.
 * old: Mmu.on_empty := unkeep_all) *)
let () = let next = !Mmu.on_empty in Mmu.on_empty := (fun () -> unkeep_all (); next ())

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
