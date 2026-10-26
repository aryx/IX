(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyKernelMemory.mli *)

open TinyMemory

(* memory.tm's loops and runtime.c's words (TinyKernel.ml names them
 * too) *)
external k_copy : int -> int -> int -> unit = "k_copy"
external k_window : int -> int -> int -> int -> unit = "k_window"
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
 * a number, to tell two apart; its text, with segments (below) *)
type space = {
  sid : int; mutable sbase : int; mutable ssize : int;
  mutable text : text option;
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
  let sp = { sid = !next_sid; sbase = 0; ssize = 0; text = None } in
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
let mem_load sp key stamp tsize size =
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

let mem_release sp = release sp; drop_text sp

(* dst a copy of src (fork's): a block of src's data's size, its bytes;
 * the text shared, but one of src's own (written), copied too *)
let mem_copy dst src =
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
let mem_address sp va n =
  let ts = text_size sp in
  if va < 0 || n < 0 || va + n > ts + sp.ssize then -1
  else if n > 0 && va < ts && va + n > ts then -1
  else at sp va

(* The n bytes at va as the blocks of the machine that hold them, in
 * order, each its kernel's address and its length; None if they leave
 * the process's memory. A partition's n bytes are one block, so one
 * piece; with segments, two when they cross from the text to the
 * data. *)
let mem_pieces sp va n =
  let ts = text_size sp in
  if va < 0 || n < 0 || va + n > ts + sp.ssize then None
  else if va < ts && va + n > ts then
    Some [ (at sp va, ts - va); (sp.sbase, va + n - ts) ]
  else Some [ at sp va, n ]

(* whether the kernel may write the n bytes at va for the process (a
 * read's buffer, a call's result): not in a text, which is read only *)
let mem_writable sp va n = n = 0 || va >= text_size sp

(* a word, a byte, a string, n bytes of the kernel's at a, written at va;
 * a word read. The kernel has checked va ([mem_address]). A word or a
 * byte written in the text makes it the process's own (a breakpoint);
 * a string and n bytes are the loader's, which writes a new text *)
let mem_fetch sp va = peek (at sp va)
let mem_store sp va w =
  if va < text_size sp then own_text sp;
  poke (at sp va) w
let mem_store_byte sp va b =
  if va < text_size sp then own_text sp;
  pokeb (at sp va) b
let pieces sp va n =
  match mem_pieces sp va n with Some l -> l | None -> []
let mem_write sp va s =
  ignore (List.fold_left (fun off (a, k) -> row_bytes s off a k; off + k) 0
            (pieces sp va (String.length s)))
let mem_blit sp va a n =
  ignore (List.fold_left (fun off (d, k) -> row_copy d (a + off) k; off + k) 0
            (pieces sp va n))

(* What the machine gets so that a process runs in sp: its window, the
 * data's start and size, and the text's (0 and 0 without one: the
 * window alone, as partitions have it); on core 0 (entry.tm's k_window), and
 * in another core's mailbox, at m, m + 4, m + 20, m + 24 *)
let text_base sp = match sp.text with Some t -> t.tblock.sbase | None -> 0
let mem_window sp = k_window sp.sbase sp.ssize (text_base sp) (text_size sp)
let mem_post sp m =
  poke m sp.sbase; poke (m + 4) sp.ssize;
  poke (m + 20) (text_base sp); poke (m + 24) (text_size sp)
