(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Devaudio.mli *)
(* The registers and their order are Circle's (pwmsoundbasedevice.cpp,
 * gpioclock.cpp), its waits kept: a real board wants time where an
 * emulator does not (Emmc's lesson). The Pi 4's jack (another PWM, at
 * 0x20c800, a clock of 125 MHz, the pins 40 and 41) is the plan's
 * stage 7: until then /dev/audio is the Pi 1's. *)

open Types
open Errors

(*****************************************************************************)
(* The registers *)
(*****************************************************************************)

(* offsets from the peripherals' base. A word is written as its two
 * halves: most of these values are past the Pi 1's ints *)
let set r hi lo = Machine.io_set32 r hi lo
let hi r = Machine.io_get16 r true
let lo r = Machine.io_get16 r false

let microdelay us =
  let t0 = Machine.timer_now () in
  while (Machine.timer_now () - t0) land 0x3fffffff < us do () done

(* the pins' functions, ten pins a word, three bits each: 40 to 49 *)
let gpfsel4 = 0x200010

(* the clock manager's clock for the PWM: its control and its divisor,
 * each write with the password in the top byte *)
let cm_ctl = 0x1010a0 and cm_div = 0x1010a4
let passwd = 0x5a00
let cm_enab = 1 lsl 4 and cm_kill = 1 lsl 5 and cm_busy = 1 lsl 7
(* the source: PLLD, 500 MHz on the Pi 1; halved *)
let cm_plld = 6
let clock_hz = 250000000

let pwm = 0x20c000
let pwm_ctl = pwm and pwm_dmac = pwm + 0x08 and pwm_rng1 = pwm + 0x10 and pwm_rng2 = pwm + 0x20
(* both channels on, each taking its words from the FIFO (a word for
 * the first, a word for the second, in turn); the FIFO emptied *)
let pwen1 = 1 and usef1 = 1 lsl 5 and clrf1 = 1 lsl 6 and pwen2 = 1 lsl 8 and usef2 = 1 lsl 13
(* the FIFO's own address as the DMA names it (a bus address: the
 * peripherals are at 0x7E000000 there) *)
let fif1_hi = 0x7e20 and fif1_lo = 0xc018

(* the DMA's channel: 5, one of those the firmware leaves the ARM and
 * the highest of the full ones Circle would take *)
let chan = 5
let dma = 0x7000 + (chan * 0x100)
let dma_cs = dma and dma_conblk = dma + 0x04 and dma_source = dma + 0x0c
let dma_enable = 0x7ff0
(* a control block's TI: a word to the peripheral 5 (the PWM) when it
 * asks (DEST_DREQ), each write acknowledged (WAIT_RESP), the source
 * moving on *)
let ti_hi = 5 and ti_lo = (1 lsl 3) lor (1 lsl 6) lor (1 lsl 8)
(* memory as the DMA names it: the Pi 1's bus alias (pi1/board.h) *)
let bus_hi pa = 0x4000 lor (pa lsr 16)

(*****************************************************************************)
(* The ring *)
(*****************************************************************************)

(* a page is 1,024 words: 512 pairs, 11.6 ms; the ring 371 ms. Powers
 * of two: a place in the ring is a mask and a shift (a division is a
 * function on this processor, and there would be three a sample) *)
let npages = 32
let page_shift = 9
let page_frames = 1 lsl page_shift
let total = npages * page_frames
(* where a write starts ahead of the DMA when the ring is empty (5.8
 * ms), and what is never filled: the page the DMA may be in *)
let lead = 256
let guard = page_frames

let pages = Array.make npages 0
let blocks = ref 0
let started = ref false

(* the next pair written; the DMA's place at the last look; the pairs
 * from the one to the other, still to play (the lead's silence among
 * them); whether any is a program's *)
let wr = ref 0
let seen = ref 0
let filled = ref 0
let dirty = ref false
let empties = ref 0
let is_open = ref false
(* a write's bytes that were not a whole pair *)
let carry = ref ""

let volume = ref 100
let speed = ref 44100
(* the PWM's period in its clock's ticks, to the nearest: 5,669 *)
let range_of speed = (clock_hz + (speed / 2)) / speed
let range = ref (range_of 44100)
(* the first channel's ear: the left one on the first boards (the
 * Model A and B of 2011 and 2012: GPIO 40 is the left ear, and GPIO
 * 40 is the first channel's pin everywhere), the right one since the
 * A+ and B+, whose jack has them the other way *)
let left_first = ref false

(* the firmware's word for the board: since 2014 a field (bits 4 to
 * 11: 0 the A, 1 the B), before a number (below 0x10: the A and B) *)
let first_boards rev =
  if rev = 0 then false
  else if rev land (1 lsl 23) <> 0 then (rev lsr 4) land 0xff <= 1
  else rev land 0xff < 0x10

(* a sample as the PWM's word: 0 .. range, silence in the middle; the
 * volume in 256ths (no division) *)
let gain = ref 256
let duty v = ((((v * !gain) asr 8) + 32768) * !range) lsr 16

let le32 hi lo = Machine.le16 lo ^ Machine.le16 hi

(* a page of silence, to copy *)
let silent = ref ""
let make_silent () =
  let w = le32 0 (duty 0) in
  let b = Buffer.create 4096 in
  for i = 1 to 1024 do ignore i; Buffer.add_string b w done;
  silent := Buffer.contents b

(* [n] pairs from [at] made silence *)
let rec silence at n =
  if n > 0 then begin
    let off = at mod page_frames in
    let k = min n (page_frames - off) in
    Machine.Phys.write_sub (pages.(at / page_frames) + (off * 8)) !silent 0 (k * 8);
    silence ((at + k) mod total) (n - k)
  end

(* The pair the DMA reads next. Its two registers: the block it is in
 * (CONBLK_AD), the address it reads next (SOURCE_AD, which moves as
 * the block is played). Read as halves, and not at one instant: the
 * block is read again after, and all of it again if it changed. *)
let position () =
  let word r = ((hi r land 0x3fff) lsl 16) lor lo r in
  let rec go tries =
    let b = word dma_conblk in
    let s = word dma_source in
    if word dma_conblk <> b then (if tries = 0 then None else go (tries - 1))
    else begin
      let i = (b - !blocks) / 32 in
      if i < 0 || i >= npages then None
      else begin
        let off = s - pages.(i) in
        if off < 0 || off > 4096 then (if tries = 0 then None else go (tries - 1))
        else Some (((i * page_frames) + (off / 8)) mod total)
      end
    end in
  go 3

(* what was played since the last look is silence again; the ring run
 * empty, the next write starts ahead of the DMA *)
let update () =
  match position () with
  | None -> ()
  | Some rd ->
      let played = (rd - !seen + total) mod total in
      if played > 0 then begin
        if !dirty then silence !seen (min played !filled);
        if played >= !filled then begin
          if !dirty && !is_open then incr empties;
          dirty := false;
          wr := (rd + lead) mod total;
          filled := lead
        end
        else filled := !filled - played;
        seen := rd
      end

let clock () = if !started then update ()

(*****************************************************************************)
(* The start *)
(*****************************************************************************)

let set_range () =
  range := range_of !speed;
  make_silent ();
  if !started then begin
    set pwm_rng1 0 !range;
    set pwm_rng2 0 !range;
    silence 0 total;
    dirty := false;
    wr := (!seen + lead) mod total;
    filled := lead
  end

let start () =
  if Arch.name <> "pi1" then raise (Error "no audio on this board yet");
  (* QEMU's raspi has no PWM, and a write to what is not there was the
   * kernel's end (the author, 2026-10-13, of a game's first sound
   * there: "why the freeze when running missilecommand?"): asked
   * first, and the open fails; a game goes on without its sound *)
  if not (Machine.io_probe pwm_rng1) then raise (Error "no audio device (an emulator without the PWM)");
  for i = 0 to npages - 1 do
    pages.(i) <- (match Mmu.kalloc () with Some pa -> pa | None -> raise (Error enovmem))
  done;
  blocks := (match Mmu.kalloc () with Some pa -> pa | None -> raise (Error enovmem));
  left_first := first_boards (Machine.board_rev ());
  make_silent ();
  silence 0 total;
  (* the control blocks, 8 words each: what, from where, to where, how
   * many bytes, a stride (none), the next block; written at once (the
   * DMA reads the memory, not the processor's cache: Phys.write) *)
  let b = Buffer.create 1024 in
  for i = 0 to npages - 1 do
    let next = !blocks + (32 * ((i + 1) mod npages)) in
    Buffer.add_string b (le32 ti_hi ti_lo);
    Buffer.add_string b (le32 (bus_hi pages.(i)) (pages.(i) land 0xffff));
    Buffer.add_string b (le32 fif1_hi fif1_lo);
    Buffer.add_string b (le32 0 4096);
    Buffer.add_string b (le32 0 0);
    Buffer.add_string b (le32 (bus_hi next) (next land 0xffff));
    Buffer.add_string b (le32 0 0);
    Buffer.add_string b (le32 0 0)
  done;
  Machine.Phys.write !blocks (Buffer.contents b);
  (* the two pins to the PWM (their function 4, alt0: bits 0 to 2 for
   * the pin 40, 15 to 17 for the pin 45) *)
  let h = hi gpfsel4 and l = lo gpfsel4 in
  set gpfsel4 ((h land lnot 3) lor 2) ((l land lnot 0x8007) lor 4);
  (* the clock: stopped, its divisor, its source, then on *)
  set cm_ctl passwd cm_kill;
  let t0 = Machine.timer_now () in
  while lo cm_ctl land cm_busy <> 0 && (Machine.timer_now () - t0) land 0x3fffffff < 10000 do () done;
  set cm_div passwd (2 lsl 12);
  microdelay 10;
  set cm_ctl passwd cm_plld;
  microdelay 10;
  set cm_ctl passwd (cm_plld lor cm_enab);
  microdelay 2000;
  set pwm_rng1 0 !range;
  set pwm_rng2 0 !range;
  set pwm_ctl 0 (pwen1 lor usef1 lor pwen2 lor usef2 lor clrf1);
  microdelay 2000;
  (* the PWM asks the DMA (ENAB), when its FIFO has 7 words or fewer *)
  set pwm_dmac 0x8000 0x0707;
  (* the channel: enabled, reset, given its first block, started (its
   * priorities Circle's) *)
  set dma_enable (hi dma_enable) (lo dma_enable lor (1 lsl chan));
  microdelay 1000;
  set dma_cs 0x8000 0;
  microdelay 1000;
  set dma_conblk (bus_hi !blocks) (!blocks land 0xffff);
  set dma_cs 0x10f1 1;
  wr := lead; seen := 0; filled := lead; dirty := false;
  started := true

(*****************************************************************************)
(* The files *)
(*****************************************************************************)

let s16 (s : string) o =
  let v = Char.code s.[o] lor (Char.code s.[o + 1] lsl 8) in
  if v >= 32768 then v - 65536 else v

(* [n] pairs of [s] from its pair [i], at wr.
 * (a call of Phys.set32 a word, which also writes it through the
 * cache: the simple way; a function in C for the whole run is the
 * faster one, if a measure asks) *)
let put (s : string) i n =
  for j = i to i + n - 1 do
    let l = duty (s16 s (4 * j)) and r = duty (s16 s ((4 * j) + 2)) in
    let pa = pages.(!wr lsr page_shift) + ((!wr land (page_frames - 1)) * 8) in
    Machine.Phys.set32 pa (if !left_first then l else r);
    Machine.Phys.set32 (pa + 4) (if !left_first then r else l);
    wr := (!wr + 1) land (total - 1)
  done;
  filled := !filled + n;
  dirty := true

let write (s : string) =
  let len = String.length s in
  let s = if !carry = "" then s else !carry ^ s in
  let n = String.length s / 4 in
  carry := String.sub s (4 * n) (String.length s - (4 * n));
  let i = ref 0 in
  while !i < n do
    update ();
    let free = total - guard - !filled in
    if free <= 0 then Proc.tsleep 10
    else begin
      (* (a page at most between two looks at the DMA: a write of a
       * megabyte does not go on behind it) *)
      let k = min page_frames (min free (n - !i)) in
      put s !i k;
      i := !i + k
    end
  done;
  len

let qdir = 0 and qaudio = 1 and qvolume = 2 and qstat = 3

let root = { path = qdir; vers = 0; typ = Qt_dir }

let entries path =
  if path <> qdir then raise (Error enotdir)
  else [ { Dev.dname = "audio"; Dev.dqid = { path = qaudio; vers = 0; typ = Qt_file }; Dev.dlength = 0; Dev.dperm = 0o666 };
         { Dev.dname = "volume"; Dev.dqid = { path = qvolume; vers = 0; typ = Qt_file }; Dev.dlength = 0; Dev.dperm = 0o666 };
         { Dev.dname = "audiostat"; Dev.dqid = { path = qstat; vers = 0; typ = Qt_file }; Dev.dlength = 0; Dev.dperm = 0o444 } ]

let text (s : string) n off =
  if off >= String.length s then "" else String.sub s off (min n (String.length s - off))

let control (s : string) =
  let number w = try int_of_string w with Failure _ -> raise (Error ebadarg) in
  let words = List.filter (fun w -> w <> "" && w <> "out")
      (String.split_on_char ' ' (String.map (fun c -> if c = '\n' then ' ' else c) s)) in
  let loud v =
    let v = number v in
    if v < 0 || v > 100 then raise (Error ebadarg);
    volume := v;
    gain := (v * 256) / 100 in
  match words with
  | [ "audio"; v ] -> loud v
  | [ v ] -> loud v
  | [ "speed"; v ] ->
      let v = number v in
      if v < 4000 || v > 48000 then raise (Error ebadarg);
      speed := v;
      set_range ()
  | _ -> raise (Error "unknown control message")

let init () =
  let d = Dev.default 'A' "audio" in
  Dev.register { d with
    Dev.attach = (fun _ -> Dev.attach 'A' 0 root);
    Dev.walk = Dev.tab_walk entries (fun _ -> root);
    Dev.stat = Dev.tab_stat "#A" entries (fun _ -> root);
    Dev.dirs = Dev.tab_dirs entries;
    Dev.open_ = (fun c (m : mode) ->
      if c.qid.path = qaudio then begin
        if m.access = Oread then raise (Error eperm);
        if !is_open then raise (Error einuse);
        if not !started then start ();
        is_open := true;
        carry := ""
      end;
      Dev.tab_open c m);
    Dev.close = (fun c -> if c.qid.path = qaudio then is_open := false);
    Dev.read = (fun c n off ->
      if c.qid.path = qvolume then text (Printf.sprintf "audio out %d\nspeed out %d\n" !volume !speed) n off
      else if c.qid.path = qstat then begin
        clock ();
        text (Printf.sprintf "bufsize %6d buffered %6d empty %d\n" (4 * (total - guard)) (4 * (if !dirty then !filled else 0)) !empties) n off
      end
      else raise (Error eperm));
    Dev.write = (fun c s _ ->
      if c.qid.path = qaudio then write s
      else if c.qid.path = qvolume then begin control s; String.length s end
      else raise (Error eperm));
  }
