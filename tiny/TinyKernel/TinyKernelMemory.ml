(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyKernelMemory.mli *)

open TinyMemory

(* memory.tm's loops and runtime.c's words (TinyKernel.ml names them
 * too) *)
external k_copy : int -> int -> int -> unit = "k_copy"
external k_window : int -> int -> int -> int -> int -> unit = "k_window"
external k_zero : int -> int -> unit = "k_zero"
external peek : int -> int = "peek"
external poke : int -> int -> unit = "poke"

(*****************************************************************************)
(* Partitions *)
(*****************************************************************************)

(* The processes' memory is above the kernel's first 32 MB, up to 64 KB
 * below the top of the machine's 256 MB (the devices'). A partition's
 * size is a whole number of megabytes. *)
let part = 0x100000
let mem_low = 0x2000000
let mem_high = 0xfff0000

(* a process's memory: its partition's start and size (0: none yet);
 * a number, to tell two apart; its text, with segments (below); with
 * pages (further below), its root table, its size and its text's *)
type space = {
  sid : int; mutable sbase : int; mutable ssize : int;
  mutable text : text option;
  mutable root : int; mutable vsize : int; mutable tsz : int;
}
(* a program's text, shared by its runs: its block, the file it came
 * from (key, "" for none) and that file's date and size then (stamp),
 * its runs, and whether an exec may still take it: not when its file
 * was written since, or the text itself (a breakpoint) *)
and text = {
  tblock : space; key : string; stamp : string;
  mutable users : int; mutable known : bool;
}

(* the blocks given: the spaces' and the texts' *)
let used = ref []
let next_sid = ref 1

(* no partition free now (TinyKernel.ml's with_room waits for one) *)
exception No_room

let mem_empty () =
  let sp = { sid = !next_sid; sbase = 0; ssize = 0; text = None;
             root = 0; vsize = 0; tsz = 0 } in
  incr next_sid;
  sp

(* The first gap of [size] bytes between the partitions in use, ordered
 * by address, but the one of [except] (exec replaces it). *)
let room size except =
  let others = List.filter (fun sp -> sp.sid <> except) !used in
  let rec insert sp = function
    | [] -> [ sp ]
    | r :: rest ->
        if sp.sbase <= r.sbase then sp :: r :: rest else r :: insert sp rest in
  let sorted = List.fold_left (fun l sp -> insert sp l) [] others in
  let rec go at = function
    | [] -> if at + size <= mem_high then at else raise No_room
    | sp :: rest ->
        if at + size <= sp.sbase then at
        else go (max at (sp.sbase + sp.ssize)) rest in
  go mem_low sorted

(* sp given a partition of [size] bytes, its old one let go: the same
 * when it has that size already; No_room, sp as it was *)
let mem_place sp size =
  let b = if size = sp.ssize then sp.sbase else room size sp.sid in
  if sp.ssize = 0 then used := !used @ [ sp ];
  sp.sbase <- b;
  sp.ssize <- size

let release sp =
  used := List.filter (fun r -> r.sid <> sp.sid) !used;
  sp.ssize <- 0

(*****************************************************************************)
(* Segments *)
(*****************************************************************************)

(* Chosen at the boot (TinyKernel.ml: /lib/memory says segments). Off,
 * no space has a text, and every function below is the partition's *)
let segments = ref false

(* the texts given, which an exec looks in *)
let texts = ref []

let text_size sp = match sp.text with Some t -> t.tblock.ssize | None -> 0

(* sp's text let go: its block too when sp was its last run *)
let drop_text sp =
  (match sp.text with
   | Some t ->
       t.users <- t.users - 1;
       if t.users = 0 then begin
         release t.tblock;
         texts := List.filter (fun u -> u.tblock.sid <> t.tblock.sid) !texts
       end
   | None -> ());
  sp.text <- None

(* a copy of t, one process's, which no exec takes; No_room *)
let copy_text t =
  let b = mem_empty () in
  mem_place b t.tblock.ssize;
  k_copy b.sbase t.tblock.sbase b.ssize;
  let mine = { tblock = b; key = ""; stamp = ""; users = 1; known = false } in
  texts := mine :: !texts;
  mine

(* a text of its own for a process that writes in its text (the kernel
 * does, for a tracer's breakpoint): the one it shares copied, or the one
 * it alone runs no longer taken by an exec *)
let own_text sp =
  match sp.text with
  | Some t when t.users > 1 ->
      let mine = copy_text t in
      t.users <- t.users - 1;
      sp.text <- Some mine
  | Some t -> t.known <- false
  | None -> ()

(* The program of a file given to sp: tsize bytes of text (0: none, or
 * no segments), the rest of size its data. A text that runs already,
 * from the same file unchanged, is shared; else a block of its own. True
 * when the text is new, for the caller to write; No_room, sp as it was *)
let seg_load sp key stamp tsize size =
  if not !segments || tsize = 0 then (mem_place sp size; drop_text sp; true)
  else begin
    let found =
      if key = "" then None
      else List.find_opt (fun t -> t.known && t.key = key && t.stamp = stamp)
             !texts in
    let t = match found with
      | Some t -> t
      | None ->
          let b = mem_empty () in
          mem_place b tsize;
          { tblock = b; key; stamp; users = 0; known = key <> "" } in
    (try mem_place sp (size - tsize)
     with No_room -> (if found = None then release t.tblock); raise No_room);
    if found = None then texts := t :: !texts;
    t.users <- t.users + 1;
    drop_text sp;
    sp.text <- Some t;
    found = None
  end

(* the texts of a file no longer taken by an exec: it is being written *)
let mem_forget key =
  List.iter (fun t -> if t.key = key then t.known <- false) !texts

let seg_release sp = release sp; drop_text sp

(* dst a copy of src (fork's): a block of src's data's size, its bytes;
 * the text shared, but one of src's own (written), copied too *)
let seg_copy dst src =
  mem_place dst src.ssize;
  k_copy dst.sbase src.sbase src.ssize;
  drop_text dst;
  match src.text with
  | Some t when t.known -> t.users <- t.users + 1; dst.text <- Some t
  | Some t ->
      (try dst.text <- Some (copy_text t)
       with No_room -> release dst; raise No_room)
  | None -> ()

(*****************************************************************************)
(* Pages *)
(*****************************************************************************)

(* Chosen at the boot (/lib/memory says pages). A process's memory is
 * pages of 4 KB anywhere, by its tables (the machine's Sv32: a root of
 * 1024 entries, each a table of 1024, each a page), given when touched
 * (zeroed), shared by a fork until one side writes (copy-on-write).
 * The machine's satp has the user-only bit (tiny-machine's user_only):
 * the kernel's addresses stay physical, the tables it walks itself. *)
let pages = ref false
let page = 4096

(* The frames, the pages of the machine's memory from mem_low: a free
 * one's first word is the next free (0: none), as xv6's kalloc; those
 * never given yet are above [untouched], so the boot makes no list of
 * 57,000. A frame's users, a byte each from 0xb51000 (TinyKernel.mli's
 * layout): a table, or the processes that map it *)
let free_frames = ref 0
let untouched = ref mem_low
let nfree = ref ((mem_high - mem_low) / page)
let refs_at = 0xb51000
let refs f = peekb (refs_at + ((f - mem_low) / page))
let set_refs f n = pokeb (refs_at + ((f - mem_low) / page)) n

(* a frame, zeroed, one user; No_room *)
let frame () =
  let f =
    if !free_frames <> 0 then (let f = !free_frames in free_frames := peek f; f)
    else if !untouched < mem_high then
      (let f = !untouched in untouched := f + page; f)
    else raise No_room in
  decr nfree;
  k_zero f page;
  set_refs f 1;
  f

(* a user of frame f gone: f free with the last *)
let unref f =
  let n = refs f - 1 in
  set_refs f n;
  if n = 0 then (poke f !free_frames; free_frames := f; incr nfree)

(* an entry: a frame's number above ten bits of flags, the machine's
 * V R W X U, and one of the software's, copy-on-write (Sv32's RSW) *)
let v = 1 and r = 2 and w = 4 and x = 8 and u = 16 and cow = 256
let frame_of e = (e lsr 10) lsl 12
let entry f flags = ((f lsr 12) lsl 10) lor flags

(* the kernel's address of va's entry in sp's tables, its table made
 * when [make] (No_room); 0 without one *)
let entry_at sp va make =
  let a1 = sp.root + (4 * (va lsr 22)) in
  let e1 = peek a1 in
  let index = 4 * ((va lsr 12) land 0x3ff) in
  if e1 land v <> 0 then frame_of e1 + index
  else if make then (let t = frame () in poke a1 (entry t v); t + index)
  else 0

(* va's page there, a new one given when it was not (zeroed: memory
 * given when touched): its entry's address. The text's read only, the
 * rest writable. No_room *)
let present sp va =
  let a = entry_at sp va true in
  if peek a land v = 0 then
    poke a (entry (frame ()) (if va < sp.tsz then v lor r lor x lor u
                              else v lor r lor w lor x lor u));
  a

(* va's page the process's alone, to be written: a copy of a frame
 * another maps (a fork's, before either wrote; a text's, for a
 * breakpoint), writable again when it was before the fork *)
let unshare sp va =
  let a = present sp va in
  let e = peek a in
  if refs (frame_of e) > 1 then begin
    let g = frame () in
    k_copy g (frame_of e) page;
    unref (frame_of e);
    poke a (entry g (e land 1023))
  end;
  let e = peek a in
  if e land cow <> 0 then poke a ((e land lnot cow) lor w);
  a

(* the kernel's address of va, its page given if it was not *)
let physical sp va = frame_of (peek (present sp va)) + (va land (page - 1))

(* every page and table of sp let go *)
let pg_release sp =
  if sp.root <> 0 then begin
    for i = 0 to 1023 do
      let e1 = peek (sp.root + (4 * i)) in
      if e1 land v <> 0 then begin
        let t = frame_of e1 in
        for j = 0 to 1023 do
          let e = peek (t + (4 * j)) in
          if e land v <> 0 then unref (frame_of e)
        done;
        unref t
      end
    done;
    unref sp.root;
    sp.root <- 0
  end

(* A program of isize bytes (its image), size its memory, tsize its
 * text: a root, nothing else yet (the loader's writes give the image's
 * pages, the arguments' the top's). There must be room for all of
 * them first, so that the loader does not fail half way: No_room, sp
 * as it was *)
let pg_load sp tsize isize size =
  let tables = (size + (page * 1024) - 1) / (page * 1024) in
  if (isize / page) + 4 + tables > !nfree then raise No_room;
  pg_release sp;
  sp.root <- frame ();
  sp.vsize <- size;
  sp.tsz <- tsize

(* dst a copy of src (fork's): its tables, every page shared, a
 * writable one made read only in both, copy-on-write; the first to
 * write it gets a copy ([pg_fault]). No_room, before anything *)
let pg_copy dst src =
  let tables = ref 1 in
  for i = 0 to 1023 do
    if peek (src.root + (4 * i)) land v <> 0 then incr tables
  done;
  if !tables > !nfree then raise No_room;
  pg_release dst;
  dst.root <- frame ();
  dst.vsize <- src.vsize;
  dst.tsz <- src.tsz;
  for i = 0 to 1023 do
    let e1 = peek (src.root + (4 * i)) in
    if e1 land v <> 0 then begin
      let t = frame_of e1 and t' = frame () in
      poke (dst.root + (4 * i)) (entry t' v);
      for j = 0 to 1023 do
        let e = peek (t + (4 * j)) in
        if e land v <> 0 then begin
          let e = if e land w <> 0 then (e land lnot w) lor cow else e in
          poke (t + (4 * j)) e;
          poke (t' + (4 * j)) e;
          set_refs (frame_of e) (refs (frame_of e) + 1)
        end
      done
    end
  done

(* A fault of the process at va: a page it may have, given now (not
 * touched yet), or a copy-on-write page, its own now; true when the
 * process goes on, false when it dies (no such page, a store in its
 * text, no room) *)
let pg_fault sp va =
  if va < 0 || va >= sp.vsize then false
  else
    try
      let a = entry_at sp va false in
      if a = 0 || peek a land v = 0 then (ignore (present sp va); true)
      else if peek a land cow <> 0 then (ignore (unshare sp va); true)
      else false
    with No_room -> false

(* satp for sp: on, user mode only, its root (an ML int of 31 bits:
 * the top two bits the sign's) *)
let satp sp = if sp.root = 0 then 0 else -0x40000000 lor (sp.root lsr 12)

(*****************************************************************************)
(* The way chosen *)
(*****************************************************************************)

let mem_load sp key stamp tsize isize size =
  if !pages then (pg_load sp tsize isize size; true)
  else seg_load sp key stamp tsize size
let mem_release sp = if !pages then pg_release sp else seg_release sp
let mem_copy dst src = if !pages then pg_copy dst src else seg_copy dst src
let mem_fault sp va = !pages && pg_fault sp va

(*****************************************************************************)
(* A process's addresses *)
(*****************************************************************************)

(* A process's address va: below its text's size the text's (none with
 * partitions), above the data's, from its start. *)
let at sp va =
  match sp.text with
  | Some t when va < t.tblock.ssize -> t.tblock.sbase + va
  | Some t -> sp.sbase + va - t.tblock.ssize
  | None -> sp.sbase + va

(* The kernel's address of a process's n bytes at va; -1 if they leave
 * its memory, or (segments) are some in the text, some in the data. A
 * partition is one block: n bytes there are n bytes in the machine, one
 * after the other. *)
let pg_address sp va n =
  if va < 0 || n < 0 || va + n > sp.vsize then -1
  else if n > 0 && va / page <> (va + n - 1) / page then -1
  else try physical sp va with No_room -> -1

let mem_address sp va n =
  let ts = text_size sp in
  if !pages then pg_address sp va n
  else if va < 0 || n < 0 || va + n > ts + sp.ssize then -1
  else if n > 0 && va < ts && va + n > ts then -1
  else at sp va

(* The n bytes at va as the blocks of the machine that hold them, in
 * order, each its kernel's address and its length; None if they leave
 * the process's memory. A partition's n bytes are one block, so one
 * piece; with segments, two when they cross from the text to the
 * data. *)
let pg_pieces sp va n =
  let rec go va n =
    let k = min n (page - (va land (page - 1))) in
    if n <= k then [ physical sp va, n ]
    else (physical sp va, k) :: go (va + k) (n - k) in
  if va < 0 || n < 0 || va + n > sp.vsize then None
  else try Some (go va n) with No_room -> None

let mem_pieces sp va n =
  let ts = text_size sp in
  if !pages then pg_pieces sp va n
  else if va < 0 || n < 0 || va + n > ts + sp.ssize then None
  else if va < ts && va + n > ts then
    Some [ (at sp va, ts - va); (sp.sbase, va + n - ts) ]
  else Some [ at sp va, n ]

(* whether the kernel may write the n bytes at va for the process (a
 * read's buffer, a call's result): not in a text, which is read only.
 * With pages, each page made the process's own then (copy-on-write) *)
let pg_writable sp va n =
  let rec go p =
    if p * page >= va + n then true
    else if peek (present sp (p * page)) land (w lor cow) = 0 then false
    else (ignore (unshare sp (p * page)); go (p + 1)) in
  n = 0
  || (va >= 0 && va + n <= sp.vsize
      && (try go (va / page) with No_room -> false))

let mem_writable sp va n =
  if !pages then pg_writable sp va n else n = 0 || va >= text_size sp

(* a word, a byte, a string, n bytes of the kernel's at a, written at va;
 * a word read. The kernel has checked va ([mem_address]). A word or a
 * byte written in the text makes it the process's own (a breakpoint);
 * a string and n bytes are the loader's, which writes a new text *)
let mem_fetch sp va = if !pages then peek (physical sp va) else peek (at sp va)
(* (the kernel's address of va to be written: its page the process's
 * own, with pages; its text, with segments) *)
let own sp va =
  if !pages then frame_of (peek (unshare sp va)) + (va land (page - 1))
  else (if va < text_size sp then own_text sp; at sp va)
let mem_store sp va word = poke (own sp va) word
let mem_store_byte sp va b = pokeb (own sp va) b
let pieces sp va n =
  match mem_pieces sp va n with Some l -> l | None -> []
let mem_write sp va s =
  ignore (List.fold_left (fun off (a, k) -> row_bytes s off a k; off + k) 0
            (pieces sp va (String.length s)))
let mem_blit sp va a n =
  ignore (List.fold_left (fun off (d, k) -> row_copy d (a + off) k; off + k) 0
            (pieces sp va n))

(* What the machine gets so that a process runs in sp: its window, the
 * data's start and size, the text's (0 and 0 without one: the window
 * alone, as partitions have it), and satp (0 but with pages); on core 0
 * (entry.tm's k_window), and in another core's mailbox, at m, m + 4,
 * m + 20, m + 24, m + 28 *)
let text_base sp = match sp.text with Some t -> t.tblock.sbase | None -> 0
let mem_window sp =
  k_window sp.sbase sp.ssize (text_base sp) (text_size sp) (satp sp)
let mem_post sp m =
  poke m sp.sbase; poke (m + 4) sp.ssize;
  poke (m + 20) (text_base sp); poke (m + 24) (text_size sp);
  poke (m + 28) (satp sp)
