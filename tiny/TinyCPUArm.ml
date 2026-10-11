(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyCPUArm.mli *)

let usage = "usage: tiny-arm program [args...]"

(* -h: how, by examples, each one as it runs *)
let help = usage ^ {|
An ARM CPU (arm64) run as Linux runs a program: an executable of
tiny-assembler's loaded and interpreted; read, write, exit and getpid its
system calls. For example, with libc/*.s as tiny-c -h makes it:
  tiny-c -o fact.s fact.c && tiny-assembler -o fact fact.s libc/*.s
  tiny-arm fact                  fact 10 = 3628800
  ./fact (or mini-5i fact)       the same, on the real CPU (or mini-5i's)
  tiny-arm fact one two          its arguments
An instruction outside the subset stops it, with its word and its address.
|}

exception Error of string
let error fmt = Printf.ksprintf (fun s -> raise (Error s)) fmt

(*****************************************************************************)
(* The machine *)
(*****************************************************************************)

type machine = {
  x : Bytes.t;                             (* x0 to x30, then sp: 64 bits each *)
  mutable pc : int;
  mutable n : bool; mutable z : bool; mutable c : bool; mutable v : bool;
  mem : Bytes.t;                           (* from address 0 *)
}

let create size =
  { x = Bytes.make (32 * 8) '\000'; pc = 0; n = false; z = false; c = false; v = false; mem = Bytes.make size '\000' }

(* register 31 is the stack pointer or zero: the instruction says *)
let sp m r = Bytes.get_int64_le m.x (8 * r)
let set_sp m r v = Bytes.set_int64_le m.x (8 * r) v
let reg m r = if r = 31 then 0L else sp m r
let set m r v = if r <> 31 then set_sp m r v

let check m a n = if a < 0 || a + n > Bytes.length m.mem then error "segmentation fault at 0x%x (pc 0x%x)" a m.pc

(* [size]: 0 to 3, for 1, 2, 4 and 8 bytes; a load is zero-extended *)
let load m size a =
  check m a (1 lsl size);
  match size with
  | 0 -> Int64.of_int (Bytes.get_uint8 m.mem a)
  | 1 -> Int64.of_int (Bytes.get_uint16_le m.mem a)
  | 2 -> Int64.logand (Int64.of_int32 (Bytes.get_int32_le m.mem a)) 0xffffffffL
  | _ -> Bytes.get_int64_le m.mem a

let store m size a v =
  check m a (1 lsl size);
  match size with
  | 0 -> Bytes.set_uint8 m.mem a (Int64.to_int v land 0xff)
  | 1 -> Bytes.set_uint16_le m.mem a (Int64.to_int v land 0xffff)
  | 2 -> Bytes.set_int32_le m.mem a (Int64.to_int32 v)
  | _ -> Bytes.set_int64_le m.mem a v

(*****************************************************************************)
(* Values: 64 bits or 32, the instruction's top bit says *)
(*****************************************************************************)

let ones n = if n >= 64 then -1L else Int64.pred (Int64.shift_left 1L n)

(* a 32-bit result fills its register zero-extended *)
let trunc sf v = if sf then v else Int64.logand v 0xffffffffL

(* from its low [bits], sign-extended *)
let sext bits v = let k = 64 - bits in Int64.shift_right (Int64.shift_left v k) k

let negative sf v = Int64.compare (if sf then v else sext 32 v) 0L < 0

(* a + b + cin, and the flags when [s]; a and b in the width *)
let add m sf s a b cin =
  let sum = Int64.add (Int64.add a b) cin in
  let r = trunc sf sum in
  if s then begin
    m.n <- negative sf r; m.z <- r = 0L;
    m.c <- (if sf then (let u = Int64.unsigned_compare r a in if cin = 0L then u < 0 else u <= 0)
            else Int64.unsigned_compare sum 0xffffffffL > 0);
    m.v <- negative sf (Int64.logand (Int64.logxor a r) (Int64.logxor b r))
  end;
  r

let sub m sf s a b = add m sf s a (trunc sf (Int64.lognot b)) 1L

(* and (0), orr (1), eor (2), and with the flags (3: ands, tst) *)
let logic m sf op a b =
  let r = match op with 1 -> Int64.logor a b | 2 -> Int64.logxor a b | _ -> Int64.logand a b in
  if op = 3 then (m.n <- negative sf r; m.z <- r = 0L; m.c <- false; m.v <- false);
  r

(* lsl (0), lsr (1), asr (2), ror (3) by n < the width *)
let shift sf v kind n =
  let v = trunc sf v in
  if n = 0 then v
  else trunc sf (match kind with
    | 0 -> Int64.shift_left v n
    | 1 -> Int64.shift_right_logical v n
    | 2 -> Int64.shift_right (if sf then v else sext 32 v) n
    | _ -> Int64.logor (Int64.shift_right_logical v n) (Int64.shift_left v ((if sf then 64 else 32) - n)))

(* a register's low byte, half, word or all of it, zero (0 to 3) or
 * sign-extended (4 to 7): uxtb ... sxtx *)
let extend v option =
  let bits = 8 lsl (option land 3) in
  if option land 4 <> 0 then sext bits v else Int64.logand v (ones bits)

(* the logical immediate: an element of 2 to 64 bits, its low S+1 bits
 * set, rotated right by R, repeated across the register (the manual's
 * DecodeBitMasks); None when the fields name no value *)
let bitmask sf n immr imms =
  let v = (n lsl 6) lor (lnot imms land 0x3f) in
  let rec high k = if k < 0 then -1 else if (v lsr k) land 1 = 1 then k else high (k - 1) in
  let len = high 6 in
  let levels = (1 lsl (max len 0)) - 1 in
  if len < 1 || (n = 1 && not sf) || imms land levels = levels then None
  else
    let s = imms land levels and r = immr land levels and esize = 1 lsl len in
    let elem = ones (s + 1) in
    let elem = if r = 0 then elem else Int64.logand (ones esize) (Int64.logor (Int64.shift_right_logical elem r) (Int64.shift_left elem (esize - r))) in
    let rec rep acc k = if k >= 64 then acc else rep (Int64.logor acc (Int64.shift_left elem k)) (k + esize) in
    Some (trunc sf (rep 0L 0))

(* eq ne, cs cc, mi pl, vs vc, hi ls, ge lt, gt le, al: a test and its
 * opposite by the low bit *)
let passed m cond =
  let r = match cond lsr 1 with
    | 0 -> m.z | 1 -> m.c | 2 -> m.n | 3 -> m.v | 4 -> m.c && not m.z | 5 -> m.n = m.v | 6 -> m.n = m.v && not m.z
    | _ -> true in
  if cond land 1 = 1 && cond < 14 then not r else r

(*****************************************************************************)
(* One step *)
(*****************************************************************************)

exception Undefined

(* the word at pc decoded and run, an svc being [svc]'s to answer. The
 * groups are the manual's, by the word's bits 28 to 25. *)
let step svc m =
  let pc = m.pc in
  check m pc 4;
  let w = Int32.to_int (Bytes.get_int32_le m.mem pc) land 0xffffffff in
  let f lo n = (w lsr lo) land ((1 lsl n) - 1) and bit n = (w lsr n) land 1 = 1 in
  let signed lo n = (f lo n lxor (1 lsl (n - 1))) - (1 lsl (n - 1)) in
  let sf = bit 31 and rd = f 0 5 and rn = f 5 5 and rm = f 16 5 in
  let width = if sf then 64 else 32 in
  let branch d = m.pc <- pc + (4 * d) in
  m.pc <- pc + 4;
  try
    match f 25 4 with
    (* an immediate operand *)
    | 8 | 9 ->
        (match f 23 3 with
         | 0 | 1 ->                        (* adr, adrp: an address near pc, or its page *)
             let d = (signed 5 19 lsl 2) lor f 29 2 in
             set m rd (Int64.of_int (if bit 31 then (pc land lnot 0xfff) + (d lsl 12) else pc + d))
         | 2 ->                            (* add, sub, cmp: 12 bits, maybe shifted by 12 *)
             let a = trunc sf (sp m rn) and b = Int64.of_int (f 10 12 lsl (if bit 22 then 12 else 0)) in
             let r = if bit 30 then sub m sf (bit 29) a b else add m sf (bit 29) a b 0L in
             if bit 29 then set m rd r else set_sp m rd r
         | 4 ->                            (* and, orr, eor, tst: a bitmask *)
             (match bitmask sf (f 22 1) (f 16 6) (f 10 6) with
              | None -> raise Undefined
              | Some b ->
                  let r = logic m sf (f 29 2) (trunc sf (reg m rn)) b in
                  if f 29 2 = 3 then set m rd r else set_sp m rd r)
         | 5 ->                            (* movn, movz, movk: 16 bits at 0, 16, 32 or 48 *)
             let at = 16 * f 21 2 in
             let v = Int64.shift_left (Int64.of_int (f 5 16)) at in
             (match f 29 2 with
              | 0 -> set m rd (trunc sf (Int64.lognot v))
              | 2 -> set m rd v
              | 3 -> set m rd (trunc sf (Int64.logor (Int64.logand (reg m rd) (Int64.lognot (Int64.shift_left 0xffffL at))) v))
              | _ -> raise Undefined)
         | 6 ->                            (* sbfm, bfm, ubfm: a field of rn, moved *)
             let r = f 16 6 and s = f 10 6 and src = trunc sf (reg m rn) in
             (* bits s to r of rn to the bottom; or, when s < r, its low
              * s+1 bits up to width - r: lsl, lsr, asr, sxtw, ubfx are these *)
             let len, bits, at = if s >= r then s - r + 1, Int64.shift_right_logical src r, 0 else s + 1, src, width - r in
             let field = Int64.shift_left (Int64.logand bits (ones len)) at in
             set m rd (trunc sf (match f 29 2 with
               | 0 -> sext (at + len) field
               | 1 -> Int64.logor (Int64.logand (reg m rd) (Int64.lognot (Int64.shift_left (ones len) at))) field
               | 2 -> field
               | _ -> raise Undefined))
         | _ -> raise Undefined)
    (* branches, and the calls of the system *)
    | 10 | 11 ->
        if w land 0x7c000000 = 0x14000000 then begin                 (* b, bl *)
          if bit 31 then set m 30 (Int64.of_int (pc + 4));
          branch (signed 0 26)
        end
        else if w land 0x7e000000 = 0x34000000 then                  (* cbz, cbnz *)
          (if (trunc sf (reg m rd) = 0L) <> bit 24 then branch (signed 5 19))
        else if w land 0x7e000000 = 0x36000000 then                  (* tbz, tbnz: one bit *)
          (let b = (f 31 1 lsl 5) lor f 19 5 in
           if (Int64.logand (Int64.shift_right_logical (reg m rd) b) 1L = 0L) <> bit 24 then branch (signed 5 14))
        else if w land 0xff000010 = 0x54000000 then (if passed m (f 0 4) then branch (signed 5 19))
        else if w land 0xffe0001f = 0xd4000001 then svc m
        else if w land 0xff9ffc1f = 0xd61f0000 && f 21 2 < 3 then begin (* br, blr, ret *)
          let target = Int64.to_int (reg m rn) in
          if f 21 2 = 1 then set m 30 (Int64.of_int (pc + 4));
          m.pc <- target
        end
        else raise Undefined
    (* loads and stores *)
    | 4 | 6 | 12 | 14 ->
        if w land 0x3b000000 = 0x18000000 && not (bit 26) then begin (* a literal near pc *)
          let v = load m (if f 30 2 = 1 then 3 else 2) (pc + (4 * signed 5 19)) in
          set m rd (if f 30 2 = 2 then sext 32 v else v)
        end
        else if w land 0x3a000000 = 0x28000000 && not (bit 26) && f 30 2 <> 1 && f 30 2 <> 3 then begin
          (* stp, ldp: two registers, at an offset or pre or post-indexed *)
          let size = if sf then 3 else 2 and base = Int64.to_int (sp m rn) in
          let moved = base + (signed 15 7 lsl size) in
          let a = match f 23 2 with 1 -> base | 2 | 3 -> moved | _ -> raise Undefined in
          if bit 22 then (set m rd (load m size a); set m (f 10 5) (load m size (a + (1 lsl size))))
          else (store m size a (reg m rd); store m size (a + (1 lsl size)) (reg m (f 10 5)));
          if f 23 2 <> 2 then set_sp m rn (Int64.of_int moved)
        end
        else if f 27 3 = 7 && not (bit 26) then begin
          let size = f 30 2 and base = Int64.to_int (sp m rn) in
          (* the address, and the base's new value when it is written back *)
          let a, back =
            if bit 24 then base + (f 10 12 lsl size), None                         (* scaled *)
            else if bit 21 then
              (if f 10 2 <> 2 then raise Undefined;                                (* a register's *)
               base + Int64.to_int (Int64.shift_left (extend (reg m rm) (f 13 3)) (if bit 12 then size else 0)), None)
            else match f 10 2 with
              | 0 -> base + signed 12 9, None                                      (* unscaled: ldur, stur *)
              | 1 -> base, Some (base + signed 12 9)                               (* post-indexed *)
              | 3 -> base + signed 12 9, Some (base + signed 12 9)                 (* pre-indexed *)
              | _ -> raise Undefined in
          (match f 22 2 with
           | 0 -> store m size a (reg m rd)
           | 1 -> set m rd (load m size a)
           | 2 when size < 3 -> set m rd (sext (8 lsl size) (load m size a))
           | 3 when size < 2 -> set m rd (trunc false (sext (8 lsl size) (load m size a)))
           | _ -> raise Undefined);
          Option.iter (fun b -> set_sp m rn (Int64.of_int b)) back
        end
        else raise Undefined
    (* registers *)
    | 5 | 13 ->
        let a = trunc sf (reg m rn) in
        if not (bit 28) then begin
          if not (bit 24) then begin       (* and, orr, eor, tst; bic, orn, eon: rm shifted, maybe inverted *)
            let b = shift sf (reg m rm) (f 22 2) (f 10 6) in
            set m rd (logic m sf (f 29 2) a (if bit 21 then trunc sf (Int64.lognot b) else b))
          end
          else begin                       (* add, sub, cmp: rm shifted, or extended *)
            let a, b = if bit 21 then trunc sf (sp m rn), trunc sf (Int64.shift_left (extend (reg m rm) (f 13 3)) (f 10 3))
                       else a, shift sf (reg m rm) (f 22 2) (f 10 6) in
            let r = if bit 30 then sub m sf (bit 29) a b else add m sf (bit 29) a b 0L in
            if bit 21 && not (bit 29) then set_sp m rd r else set m rd r
          end
        end
        else begin
          let b = trunc sf (reg m rm) in
          match f 21 4 with
          | 4 when not (bit 29) && not (bit 11) ->   (* csel, csinc, csinv, csneg *)
              set m rd (if passed m (f 12 4) then a
                        else trunc sf (match bit 30, bit 10 with
                          | false, false -> b | false, true -> Int64.succ b
                          | true, false -> Int64.lognot b | true, true -> Int64.neg b))
          | 6 when not (bit 30) ->
              (match f 10 6 with
               | 2 -> set m rd (if b = 0L then 0L else Int64.unsigned_div a b)                        (* udiv *)
               | 3 ->                                                                                    (* sdiv *)
                   let a = if sf then a else sext 32 a and b = if sf then b else sext 32 b in
                   set m rd (if b = 0L then 0L else trunc sf (Int64.div a b))
               | 8 | 9 | 10 | 11 -> set m rd (shift sf a (f 10 2) (Int64.to_int b land (width - 1)))  (* by a register *)
               | _ -> raise Undefined)
          | 8 ->                           (* madd, msub: mul is madd with zero *)
              let p = Int64.mul a b and acc = reg m (f 10 5) in
              set m rd (trunc sf (if bit 15 then Int64.sub acc p else Int64.add acc p))
          | _ -> raise Undefined
        end
    | _ -> raise Undefined
  with Undefined -> m.pc <- pc; error "unimplemented instruction %08x at 0x%x" w pc

(*****************************************************************************)
(* Linux: the system calls, the executable, running *)
(*****************************************************************************)

exception Exit of int

type caps = < Cap.stdin; Cap.stdout; Cap.stderr >

let syscall (caps : < caps; .. >) (m : machine) =
  let arg n = Int64.to_int (reg m n) in
  let return v = set m 0 (Int64.of_int v) in
  match arg 8 with
  | 93 | 94 -> raise (Exit (arg 0 land 0xff))
  | 63 ->
      let (_ : < Cap.stdin; .. >) = caps in
      check m (arg 1) (arg 2);
      return (try input stdin m.mem (arg 1) (arg 2) with Sys_error _ -> -5)
  | 64 ->
      check m (arg 1) (arg 2);
      let s = Bytes.sub_string m.mem (arg 1) (arg 2) in
      if arg 0 = 2 then Console.eprint caps s else (Console.print caps s; flush stdout);
      return (arg 2)
  | 172 -> return 1                         (* getpid: the one process there is *)
  | n -> error "unimplemented system call %d" n

let stack = 8 * 1024 * 1024

(* the ELF's loadable segments copied at their addresses in a memory
 * that ends with the stack; the machine and the entry *)
let load file =
  let u16 a = String.get_uint16_le file a and u32 a = Int32.to_int (String.get_int32_le file a) land 0xffffffff
  and u64 a = Int64.to_int (String.get_int64_le file a) in
  if String.length file < 64 || String.sub file 0 5 <> "\127ELF\002" || u16 18 <> 183 then error "not an arm64 ELF executable";
  let segments = List.filter_map (fun i ->
    let p = u64 32 + (i * u16 54) in
    if u32 p = 1 then Some (u64 (p + 8), u64 (p + 16), u64 (p + 32), u64 (p + 40)) else None) (List.init (u16 56) Fun.id) in
  let top = List.fold_left (fun top (_, vaddr, _, memsz) -> max top (vaddr + memsz)) 0 segments in
  let m = create (((top + 0xfff) land lnot 0xfff) + stack) in
  List.iter (fun (offset, vaddr, filesz, _) -> Bytes.blit_string file offset m.mem vaddr filesz) segments;
  m.pc <- u64 24;
  m

let run caps file args =
  let m = load file in
  (* the stack as Linux's execve leaves it: argc, argv, nil, envp's nil,
   * the auxiliary vector's end *)
  let strs = List.fold_left (fun top s -> let top = top - String.length s - 1 in Bytes.blit_string s 0 m.mem top (String.length s); top) (Bytes.length m.mem) args in
  let ptrs = snd (List.fold_left (fun (a, acc) s -> a + String.length s + 1, a :: acc) (strs, []) (List.rev args)) in
  let sp = (strs - (8 * (List.length args + 5))) land lnot 15 in
  List.iteri (fun i v -> store m 3 (sp + (8 * i)) (Int64.of_int v)) (List.length args :: ptrs);
  set_sp m 31 (Int64.of_int sp);
  try while true do step (syscall caps) m done; 0 with Exit n -> n

let main (caps : < caps; Cap.argv; Cap.open_in; .. >) =
  try
    match List.tl (Array.to_list (CapSys.argv caps)) with
    | ("-h" | "--help") :: _ -> Console.print caps help; 0
    | file :: _ as args when file.[0] <> '-' -> run caps (FS.read caps (Fpath.v file)) args
    | _ -> Console.eprint caps (usage ^ "   (-h: how)\n"); 2
  with Error e | Sys_error e -> Console.eprint caps ("tiny-arm: " ^ e ^ "\n"); 1

let () = Cap.main (fun caps -> CapStdlib.exit caps (main caps))
