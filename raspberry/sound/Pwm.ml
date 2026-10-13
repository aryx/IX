(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Pwm.mli *)

type t = {
  pi4 : bool;
  dma : Dma.t;
  yield : unit -> unit;              (* the guest waits for the FIFO: let the board's time pass *)
  mutable ctl : int;
  mutable sta : int;                 (* the bits written 1 to clear *)
  mutable dmac : int;
  rng : int array;                   (* a channel's range, its data *)
  dat : int array;
  fifo : int Queue.t;
  last : int array;                  (* what a channel played last *)
  mutable cm_ctl : int;              (* the clock: its source and ENAB, its divisor *)
  mutable cm_div : int;
  mutable owed : float;              (* the clock's ticks not yet a period *)
  mutable output : rate:int -> int -> int -> unit;
}

let depth = 8

let create ~pi4 ~dma ~yield =
  { pi4; dma; yield; ctl = 0; sta = 0; dmac = 0; rng = [| 0x20; 0x20 |]; dat = [| 0; 0 |]; fifo = Queue.create (); last = [| 0; 0 |];
    cm_ctl = 0; cm_div = 0; owed = 0.; output = (fun ~rate:_ _ _ -> ()) }

let set_output t f = t.output <- f

(* CTL's bits, channel 1's; channel 2's are 8 higher *)
let pwen = 1 and usef = 1 lsl 5 and clrf = 1 lsl 6
let on t ch bit = t.ctl land (bit lsl (8 * ch)) <> 0

(* STA's *)
let full = 1 and empt = 2 and werr = 4 and gapo = 1 lsl 4

(* the request line the FIFO asks the DMA controller on *)
let permap t = if t.pi4 then 1 else 5

(* the clock's rate, ticks a second: a source over a divisor of 12 bits
 * and 12 more of fraction; 0 when it is not enabled *)
let clock_rate t =
  let source = match t.cm_ctl land 0xf with
    | 1 -> if t.pi4 then 54e6 else 19.2e6
    | 5 -> 1000e6
    | 6 -> if t.pi4 then 750e6 else 500e6
    | _ -> 0. in
  let divisor = float_of_int ((t.cm_div lsr 12) land 0xfff) +. (float_of_int (t.cm_div land 0xfff) /. 4096.) in
  if t.cm_ctl land 0x10 = 0 || divisor = 0. then 0. else source /. divisor

(* the periods a second, the first channel on's *)
let playing t = on t 0 pwen || on t 1 pwen
let range t = max 1 (if on t 0 pwen then t.rng.(0) else t.rng.(1))
let rate t = if playing t then clock_rate t /. float_of_int (range t) else 0.

(* a channel's next word: the FIFO's, the DMA's when the FIFO has none,
 * or what it played last and a gap noted *)
let word t ch =
  if not (on t ch usef) then t.dat.(ch)
  else if not (Queue.is_empty t.fifo) then Queue.pop t.fifo
  else
    match if t.dmac land (1 lsl 31) <> 0 then Dma.pull t.dma ~permap:(permap t) else None with
    | Some w -> w
    | None -> t.sta <- t.sta lor (gapo lsl ch); t.last.(ch)

(* a number below its range as 16 bits around zero; a channel that is
 * off is silent *)
let sample t ch =
  if not (on t ch pwen) then 0
  else begin
    let w = word t ch and r = max 1 t.rng.(ch) in
    t.last.(ch) <- w;
    let w = min w r in
    (w * 65535 / r) - 32768
  end

let advance t us =
  let r = rate t in
  if r > 0. then begin
    t.owed <- t.owed +. (float_of_int us *. r /. 1e6);
    let rounded = int_of_float (r +. 0.5) in
    while t.owed >= 1. do
      t.owed <- t.owed -. 1.;
      let first = sample t 0 in
      t.output ~rate:rounded first (sample t 1)
    done
  end

let until_next t =
  let r = rate t and far = 1 lsl 30 in
  if r <= 0. || t.dmac land (1 lsl 31) = 0 then far
  else
    match Dma.left t.dma ~permap:(permap t) with
    | None -> far
    | Some words ->
        let each = (if on t 0 pwen && on t 0 usef then 1 else 0) + (if on t 1 pwen && on t 1 usef then 1 else 0) in
        if each = 0 then far
        else
          let periods = float_of_int ((words + each - 1) / each) -. t.owed in
          max 1 (int_of_float (ceil (periods *. 1e6 /. r)))

let read t off _ =
  match off with
  | 0x00 -> t.ctl
  | 0x04 ->
      let n = Queue.length t.fifo in
      if n >= depth then t.yield ();
      t.sta lor (if n >= depth then full else 0) lor (if n = 0 then empt else 0)
      lor (if on t 0 pwen then 1 lsl 9 else 0) lor (if on t 1 pwen then 1 lsl 10 else 0)
  | 0x08 -> t.dmac
  | 0x10 -> t.rng.(0)
  | 0x14 -> t.dat.(0)
  | 0x20 -> t.rng.(1)
  | 0x24 -> t.dat.(1)
  | _ -> 0

let write t off _ v =
  match off with
  | 0x00 ->
      if v land clrf <> 0 then Queue.clear t.fifo;
      t.ctl <- v land lnot clrf
  | 0x04 -> t.sta <- t.sta land lnot v
  | 0x08 -> t.dmac <- v
  | 0x10 -> t.rng.(0) <- v
  | 0x14 -> t.dat.(0) <- v
  | 0x18 -> if Queue.length t.fifo >= depth then (t.sta <- t.sta lor werr; t.yield ()) else Queue.push v t.fifo
  | 0x20 -> t.rng.(1) <- v
  | 0x24 -> t.dat.(1) <- v
  | _ -> ()

let device t = { Memory.read = read t; write = write t }

(* the clock manager's CTL and DIV: a write without the password (0x5A
 * in the top byte) is not taken; KILL (bit 5) stops the clock; BUSY
 * (bit 7) reads as ENAB, the clock running as soon as it is asked *)
let clock t =
  let read off _ =
    match off with
    | 0 -> t.cm_ctl lor (if t.cm_ctl land 0x10 <> 0 then 0x80 else 0)
    | 4 -> t.cm_div
    | _ -> 0
  and write off _ v =
    if (v lsr 24) land 0xff = 0x5a then
      match off with
      | 0 -> t.cm_ctl <- (if v land 0x20 <> 0 then 0 else v land 0x71f)
      | 4 -> t.cm_div <- v land 0xffffff
      | _ -> ()
  in
  { Memory.read; write }
