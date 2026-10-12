(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Dma.mli *)

type channel = {
  mutable cs : int;
  mutable conblk : int;
  regs : int array;              (* ti source dest len stride next debug *)
  mutable waits : bool;          (* its block's words given when its peripheral asks ([pull]) *)
}

type t = { mem : Memory.t; io : int; chans : channel array; mutable enable : int; line : int -> bool -> unit; mutable paced : int list }

let create ~mem ~io ~line =
  { mem; io; chans = Array.init 15 (fun _ -> { cs = 0; conblk = 0; regs = Array.make 7 0; waits = false }); enable = 0x7fff; line; paced = [] }

let pace t ~permap = t.paced <- permap :: t.paced

(* a bus address, as the ARM sees it: the peripherals at 0x7E... are at
 * the board's [io] (old: 0x20000000, the Pi 1's, for every board); the
 * RAM under any of the VideoCore's aliases (0x4..., the Pi 2's 0xC...) *)
let phys t a = if a land 0xff000000 = 0x7e000000 then t.io lor (a land 0xffffff) else a land 0x3fffffff

let active = 1 and fin = 2 and int = 4

(* a block's end: the next one the channel's, the interrupt if TI asks *)
let block_done (c : channel) =
  c.conblk <- c.regs.(5);
  if c.regs.(0) land 1 <> 0 then c.cs <- c.cs lor int

(* the control blocks, one after another, each moved whole; but one to a
 * peripheral that asks for its words (DEST_DREQ, a PERMAP of [paced]):
 * the channel stays active, its words [pull]'s *)
let run t n =
  let c = t.chans.(n) in
  c.waits <- false;
  while c.cs land active <> 0 && c.conblk <> 0 && not c.waits do
    let cb = phys t c.conblk in
    let word i = Memory.load32 t.mem (cb + (4 * i)) in
    let ti = word 0 and src = word 1 and dst = word 2 and len = word 3 land 0x3fffffff and next = word 5 in
    c.regs.(0) <- ti; c.regs.(1) <- src; c.regs.(2) <- dst; c.regs.(3) <- len; c.regs.(4) <- word 4; c.regs.(5) <- next;
    if ti land (1 lsl 6) <> 0 && List.mem ((ti lsr 16) land 0x1f) t.paced && len >= 4 then c.waits <- true
    else begin
      let src_inc = ti land (1 lsl 8) <> 0 and dst_inc = ti land (1 lsl 4) <> 0 in
      let s = ref (phys t src) and d = ref (phys t dst) in
      for _i = 1 to len / 4 do
        Memory.store32 t.mem !d (Memory.load32 t.mem !s);
        if src_inc then s := !s + 4;
        if dst_inc then d := !d + 4
      done;
      for _i = 1 to len mod 4 do
        Memory.store8 t.mem !d (Memory.load8 t.mem !s);
        if src_inc then incr s;
        if dst_inc then incr d
      done;
      block_done c
    end
  done;
  if not c.waits then c.cs <- (c.cs land lnot active) lor fin;
  t.line (16 + n) (c.cs land int <> 0)

(* the channel giving its words to [permap], if one is *)
let waiting t ~permap =
  let found = ref None in
  Array.iteri (fun n (c : channel) ->
    if !found = None && c.waits && c.cs land active <> 0 && (c.regs.(0) lsr 16) land 0x1f = permap then found := Some n) t.chans;
  !found

let pull t ~permap =
  match waiting t ~permap with
  | None -> None
  | Some n ->
      let c = t.chans.(n) in
      let w = Memory.load32 t.mem (phys t c.regs.(1)) in
      if c.regs.(0) land (1 lsl 8) <> 0 then c.regs.(1) <- c.regs.(1) + 4;
      c.regs.(3) <- c.regs.(3) - 4;
      if c.regs.(3) < 4 then (block_done c; run t n);
      Some w

let left t ~permap = Option.map (fun n -> t.chans.(n).regs.(3) / 4) (waiting t ~permap)

let read t off _ =
  if off = 0xfe0 then Array.fold_left (fun (acc, i) c -> (if c.cs land int <> 0 then acc lor (1 lsl i) else acc), i + 1) (0, 0) t.chans |> fst
  else if off = 0xff0 then t.enable
  else
    let n = off / 0x100 and r = off land 0xff in
    if n >= 15 then 0
    else
      let c = t.chans.(n) in
      match r with 0x00 -> c.cs | 0x04 -> c.conblk | _ when r >= 0x08 && r <= 0x20 -> c.regs.((r - 0x08) / 4) | _ -> 0

let write t off _ v =
  if off = 0xff0 then t.enable <- v
  else if off = 0xfe0 then ()
  else
    let n = off / 0x100 and r = off land 0xff in
    if n < 15 then begin
      let c = t.chans.(n) in
      match r with
      | 0x00 ->
          if v land (1 lsl 31) <> 0 then (c.cs <- 0; c.conblk <- 0; c.waits <- false)
          else begin
            (* END and INT written 1 to clear; ACTIVE starts the chain *)
            c.cs <- (c.cs land lnot (v land (fin lor int))) land lnot active lor (v land active) lor (v land 0x0ff70000);
            if v land active <> 0 && not c.waits then run t n
          end;
          t.line (16 + n) (c.cs land int <> 0)
      | 0x04 -> c.conblk <- v
      | 0x20 -> ()
      | _ -> ()
    end

let device t = { Memory.read = read t; write = write t }
