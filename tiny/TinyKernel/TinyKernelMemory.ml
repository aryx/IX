(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyKernelMemory.mli *)

open TinyMemory

(* memory.tm's loops and runtime.c's words (TinyKernel.ml names them
 * too) *)
external k_copy : int -> int -> int -> unit = "k_copy"
external k_window : int -> int -> unit = "k_window"
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
 * a number, to tell two apart *)
type space = { sid : int; mutable sbase : int; mutable ssize : int }

(* the spaces that have a partition *)
let used = ref []
let next_sid = ref 1

(* no partition free now (TinyKernel.ml's with_room waits for one) *)
exception No_room

let mem_empty () =
  let sp = { sid = !next_sid; sbase = 0; ssize = 0 } in
  incr next_sid;
  sp

let mem_size sp = sp.ssize

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

let mem_release sp =
  used := List.filter (fun r -> r.sid <> sp.sid) !used;
  sp.ssize <- 0

(* dst a copy of src (fork's): a partition of src's size, src's bytes *)
let mem_copy dst src =
  mem_place dst src.ssize;
  k_copy dst.sbase src.sbase src.ssize

(* The kernel's address of a process's n bytes at va; -1 if they leave
 * its partition. A partition is one block: n bytes there are n bytes in
 * the machine, one after the other. *)
let mem_address sp va n =
  if va < 0 || n < 0 || va + n > sp.ssize then -1 else sp.sbase + va

(* a word, a byte, a string, n bytes of the kernel's at a, written at va;
 * a word read. The kernel has checked va ([mem_address]). *)
let mem_fetch sp va = peek (sp.sbase + va)
let mem_store sp va w = poke (sp.sbase + va) w
let mem_store_byte sp va b = pokeb (sp.sbase + va) b
let mem_write sp va s = row_bytes s 0 (sp.sbase + va) (String.length s)
let mem_blit sp va a n = row_copy (sp.sbase + va) a n

(* What the machine gets so that a process runs in sp: its window,
 * the start and the size; on core 0 (entry.tm's k_window), and in
 * another core's mailbox, two words at m *)
let mem_window sp = k_window sp.sbase sp.ssize
let mem_post sp m = poke m sp.sbase; poke (m + 4) sp.ssize
