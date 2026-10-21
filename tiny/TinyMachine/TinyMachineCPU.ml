(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMachineCPU.mli. Its laws are checked by tests/TinyCPU_test.sh:
 * the first on the programs of tests/TinyCPU_tests/, the second on
 * random programs of every instruction. *)

(* The instructions, their words: TinyMachineISA's, in what tiny-ml
 * compiles too, for tiny-assembler and tiny-linker on tiny-kernel *)
open TinyMachineISA
let error fmt = Printf.ksprintf (fun s -> raise (Error s)) fmt

let m32 v = v land 0xffffffff
let signed v = ((v land 0xffffffff) lxor 0x80000000) - 0x80000000
(* a < b, both unsigned words. A word is 0 to 2^32-1 where an int has
 * 63 bits; where it has 32 (js_of_ocaml: TinyMachineWeb.ml) the same
 * bits are a signed int, m32 and signed change nothing, and a plain <
 * would be the signed one: the top bit turned first is right for both *)
let ult a b = a lxor min_int < b lxor min_int

(*****************************************************************************)
(* The machine: the interpreter *)
(*****************************************************************************)

(* 2^20 bytes, TinyCPU's; a machine around the CPU may have more
 * (TinyMachine's 16 MB), set before its boot *)
let memsize = ref (1 lsl 20)

type machine = { r : int array; mutable pc : int; mem : Bytes.t }

(* what the program that runs the CPU decides *)
type env = {
  fetch : machine -> int -> int;           (* the instruction's word at pc *)
  load : machine -> size -> int -> int;
  store : machine -> size -> int -> int -> unit;
  sys : machine -> int -> unit;            (* the call's number, pc past the sys *)
  illegal : machine -> int -> unit;        (* the word, pc still on it *)
}

let addr a = a land (!memsize - 1)
let word a = addr a land lnot 3
(* old: let load m = function W -> fun a -> ... | B -> fun a -> ...
 * A function given m and the size returned a function of the address:
 * a closure made at every load, and at every fetch, which is a load
 * (js_of_ocaml: 11% of the time in it, and the collector after it;
 * 4.5 million instructions a second became 5.2, natively 11.5 became
 * 13.5: tests/TinyMachine_bench.sh). *)
let load m s a = match s with
  | W -> Int32.to_int (Bytes.get_int32_le m.mem (word a)) land 0xffffffff
  | B -> Char.code (Bytes.get m.mem (addr a))
let store m s a v = match s with
  | W -> Bytes.set_int32_le m.mem (word a) (Int32.of_int (m32 v))
  | B -> Bytes.set m.mem (addr a) (Char.chr (v land 0xff))

let alu op a b =
  let sa = signed a and sb = signed b in
  m32 (match op with
    | Add -> a + b | Sub -> a - b | Mul -> a * b
    | Div -> if b = 0 then -1 else if sa = -0x80000000 && sb = -1 then sa else Int.div sa sb   (* truncated *)
    | Rem -> if b = 0 then a else if sa = -0x80000000 && sb = -1 then 0 else Int.rem sa sb
    | And -> a land b | Or -> a lor b | Xor -> a lxor b
    | Shl -> a lsl (b land 31) | Shr -> a lsr (b land 31) | Sar -> sa asr (b land 31)
    | Slt -> if sa < sb then 1 else 0 | Sltu -> if ult a b then 1 else 0)

let compare c a b =
  match c with
  | Eq -> a = b | Ne -> a <> b | Lt -> signed a < signed b | Ge -> signed a >= signed b | Ltu -> ult a b | Geu -> not (ult a b)

(* memory alone, and an unknown word an error *)
let plain ~sys = {
  fetch = (fun m pc -> load m W pc);
  load; store; sys;
  illegal = (fun m w -> error "illegal instruction %08x at 0x%x" w m.pc);
}

(*****************************************************************************)
(* Faster: the words already decoded *)
(*****************************************************************************)

(* The simple step decodes its word each time: decode makes a value (an
 * Alu, a Load...) that is used once and left to the collector, eight
 * million times a second. But decode is a function of the word alone,
 * so its answer can be kept by the word: no store in memory can make
 * it wrong, and nothing has to be forgotten when a program writes
 * over its code or another is loaded. A table of [kept] places, a
 * word's place by its bits folded; a place holds the last word that
 * fell there and its instruction. With [keep_decoded] false the step
 * is the simple one. (tests/TinyMachine_bench.sh, tiny-kernel's
 * paint.events: by js_of_ocaml under node, 6.8 million instructions a
 * second without it, 8.1 with it; natively 21.3 and 22.0, OCaml's own
 * allocation being a few instructions.) *)
let keep_decoded = ref true
let kept = 16384
let decoded : (int * instr option) array = Array.make kept (0, None)   (* 0 is no instruction *)

let decode_kept w =
  let k = (w lxor (w lsr 11) lxor (w lsr 22)) land (kept - 1) in
  let (w', i) = decoded.(k) in
  if w' = w then i else begin
    let i = decode w in
    decoded.(k) <- (w, i);
    i
  end

(*****************************************************************************)
(* The step *)
(*****************************************************************************)

(* old: a function inside step, let set d v = if d <> 0 then r.(d) <-
 * m32 v, which closes over r: js_of_ocaml makes that closure at every
 * step (OCaml's native compiler inlines it). *)
let set (r : int array) d v = if d <> 0 then r.(d) <- m32 v

(* one step: the word at pc fetched (from memory, or through the
 * machine's pages), decoded and run *)
let step env m =
  let pc = m.pc in
  let w = env.fetch m pc in
  match if !keep_decoded then decode_kept w else decode w with
  | None -> env.illegal m w
  | Some i ->
      let r = m.r in
      m.pc <- addr (pc + 4);
      (match i with
       | Alu (op, d, a, b) -> set r d (alu op r.(a) r.(b))
       | Alui (op, d, a, imm) -> set r d (alu op r.(a) (m32 imm))
       | Lui (d, imm) -> set r d (imm lsl 16)
       | Load (s, d, a, off) -> set r d (env.load m s (r.(a) + off))
       | Store (s, d, a, off) -> env.store m s (r.(a) + off) r.(d)
       | Branch (c, d, a, off) -> if compare c r.(d) r.(a) then m.pc <- addr (pc + 4 + (4 * off))
       | Jal (d, off) -> set r d (pc + 4); m.pc <- addr (pc + 4 + (4 * off))
       | Jalr (d, a, off) -> let t = word (r.(a) + off) in set r d (pc + 4); m.pc <- t
       | Sys n -> env.sys m n)

(* the machine at its start: the image at 0, sp at the top of memory *)
let boot image =
  let m = { r = Array.make 16 0; pc = 0; mem = Bytes.make !memsize '\000' } in
  Bytes.blit_string image 0 m.mem 0 (String.length image);
  m.r.(sp) <- !memsize;
  m

(*****************************************************************************)
(* An image *)
(*****************************************************************************)

(* the memory's first bytes, no header: the CPU starts at 0 (tiny-linker
 * made it) *)
let image name text = if String.length text > !memsize then error "%s: larger than the memory" name; text

(* the listing: address, word, instruction, as assembly again *)
let listing ~show ~origin image =
  List.init (String.length image / 4) (fun k ->
    let w = Int32.to_int (String.get_int32_le image (4 * k)) land 0xffffffff in
    Printf.sprintf "%x:\t%08x\t%s\n" (origin + (4 * k)) w
      (match decode w, show w with
       | Some i, _ -> print (origin + (4 * k)) i
       | None, Some s -> s
       | None, None -> Printf.sprintf ".word\t0x%x" w))
  |> String.concat ""

(*****************************************************************************)
(* A profile *)
(*****************************************************************************)

(* Each instruction run, counted by where it was: the program's or the
 * kernel's (a mode), the base of the user's window (which program),
 * its address. Every instruction, not a sample: the machine is slow
 * enough for that to cost little more than running it, and two runs
 * give the same profile. *)
type profile = (int, int ref) Hashtbl.t

let profile () : profile = Hashtbl.create 4096

(* an env that counts each instruction it fetches; [where m] is its mode
 * (1 the kernel's, 0 a program's) and the window's base *)
let profiled (env : env) (p : profile) (where : machine -> int * int) =
  { env with fetch = (fun m pc ->
      let mode, base = where m in
      let k = (((base lsl 1) lor mode) lsl 32) lor (pc land 0xffffffff) in
      (match Hashtbl.find_opt p k with Some n -> incr n | None -> Hashtbl.add p k (ref 1));
      env.fetch m pc) }

(* the profile as lines "k|u base pc count", the addresses in hexadecimal,
 * the most counted first *)
let profile_lines (p : profile) =
  let l = Hashtbl.fold (fun k n acc -> (k, !n) :: acc) p [] in
  let l = List.sort (fun (_, a) (_, b) -> b - a) l in
  String.concat "" (List.map (fun (k, n) ->
    Printf.sprintf "%c %x %x %d\n" (if (k lsr 32) land 1 = 1 then 'k' else 'u') (k lsr 33) (k land 0xffffffff) n) l)

