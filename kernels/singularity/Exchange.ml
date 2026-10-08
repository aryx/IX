(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Exchange.mli *)

type block = {
  mutable owner : int;
  addr : int;
  size : int;
}
let in_message = -1
let freed = -2

(* the heap's memory, physical: from 96 MB to the programs' 128 (the
 * kernel's end is below: cross.c), in pages *)
external kernel_end : unit -> int = "sip_kernel_end"
let base = 96 * 1024 * 1024
let limit = 128 * 1024 * 1024
let page = 4096

(* the free pieces, each an address and its bytes, by address; first fit *)
let holes : (int * int) list ref = ref [ (base, limit - base) ]
let held = ref 0
let bytes () : int = !held

let () = if kernel_end () > base then Machine.panic "the kernel reaches the exchange heap"

let alloc (owner : int) (n : int) : block option =
  let size = max page ((n + page - 1) / page * page) in
  let rec take (l : (int * int) list) : (int * (int * int) list) option =
    match l with
    | [] -> None
    | (a, s) :: rest when s >= size -> Some (a, if s = size then rest else (a + size, s - size) :: rest)
    | h :: rest -> (match take rest with Some (a, rest) -> Some (a, h :: rest) | None -> None)
  in
  if n < 0 || n > limit - base then None
  else match take !holes with
    | None -> None
    | Some (addr, rest) ->
        holes := rest;
        held := !held + size;
        Machine.Phys.zero addr size;
        Some { owner; addr; size = n }

let free (b : block) : unit =
  if b.owner <> freed then begin
    let size = max page ((b.size + page - 1) / page * page) in
    b.owner <- freed;
    held := !held - size;
    (* back in its place, joined to the pieces it touches *)
    let rec put (l : (int * int) list) : (int * int) list =
      match l with
      | (a, s) :: rest when a + s = b.addr -> join ((a, s + size) :: rest)
      | (a, s) :: rest when a < b.addr -> (a, s) :: put rest
      | l -> join ((b.addr, size) :: l)
    and join (l : (int * int) list) : (int * int) list =
      match l with
      | (a, s) :: (a', s') :: rest when a + s = a' -> (a, s + s') :: rest
      | l -> l
    in
    holes := put !holes
  end
