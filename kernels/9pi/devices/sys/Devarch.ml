(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Devarch.mli *)

open Types
open Errors

(* the cpu: the Pi1's ARM1176, the Pi2's Cortex-A7 or A53 (the board
 * revision's processor field, bits 12 to 15, of a revision in the new
 * form, bit 23: 1 a BCM2836, 2 a BCM2837), the Pi4's Cortex-A72 (its
 * programs 32-bit arm's) *)
let cpu =
  if Arch.name = "pi4" then "Cortex-A72"
  else
    let rev = Machine.board_rev () in
    match if rev land 0x800000 <> 0 then (rev lsr 12) land 0xf else 0 with
    | 1 -> "Cortex-A7" | 2 -> "Cortex-A53" | _ -> "1176JZF-S"
(* the firmware's revision (Machine.firmware_rev's two halves [lo] and
 * [hi], n = hi * 65536 + lo, the second its files were built at): in
 * decimal as 9pi's banner has it, and as the day it names, which says
 * which set of kernels/firmware is on a board's card. In ints of 31
 * bits: n = hi * 6 * 10000 + (hi * 5536 + lo), and n's days are
 * (hi * 512 + lo / 128) / 675, 86400 being 128 * 675; the day's year,
 * month and day by the years' cycle of 400 from March 1, 0000. *)
let firmware, firmware_date =
  let lo = Machine.firmware_rev 0 and hi = Machine.firmware_rev 1 in
  let t = hi * 5536 + lo in
  let q = hi * 6 + t / 10000 in
  let z = (hi * 512 + lo / 128) / 675 + 719468 in
  let era = z / 146097 in
  let doe = z - era * 146097 in
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365 in
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100) in
  let mp = (5 * doy + 2) / 153 in
  let m = if mp < 10 then mp + 3 else mp - 9 in
  (if q = 0 then string_of_int t else Printf.sprintf "%d%04d" q (t mod 10000)),
  Printf.sprintf "%d-%02d-%02d" (yoe + era * 400 + (if m <= 2 then 1 else 0)) m (doy - (153 * mp + 2) / 5 + 1)

(* (its speed in MHz the file's last word, measured once, here: 0 under
 * the emulators, 9pi's there. An emulator: its firmware's revision is
 * QEMU's number; QEMU's Pi 2 has a cycle counter, by its own clock,
 * and would say 1005) *)
let mhz = if firmware = "346337" then 0 else Machine.cpu_mhz ()
let files = [ "cputype", Printf.sprintf "ARM %s %d\n" cpu mhz; "cputemp", "0\n" ]

let root = { path = 0; vers = 0; typ = Qt_dir }

let entries path =
  if path <> 0 then raise (Error enotdir)
  else
    let rec go i l = match l with
      | [] -> []
      | (name, _) :: r ->
          { Dev.dname = name; Dev.dqid = { path = i; vers = 0; typ = Qt_file }; Dev.dlength = 0; Dev.dperm = 0o444 }
          :: go (i + 1) r in
    go 1 files

let init () =
  let d = Dev.default 'P' "arch" in
  Dev.register { d with
    Dev.attach = (fun _ -> Dev.attach 'P' 0 root);
    Dev.walk = Dev.tab_walk entries (fun _ -> root);
    Dev.stat = Dev.tab_stat "#P" entries (fun _ -> root);
    Dev.dirs = Dev.tab_dirs entries;
    Dev.open_ = Dev.tab_open;
    Dev.read = (fun c n off ->
      let s = snd (List.nth files (c.qid.path - 1)) in
      if off >= String.length s then "" else String.sub s off (min n (String.length s - off)));
  }
