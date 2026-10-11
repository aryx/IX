(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/crypto/Aes.ml (docs/plans/plan_browser.md) *)

(* See Aes.mli *)

(* multiplication by x (that is 2) in GF(2^8), modulo x^8+x^4+x^3+x+1 *)
let xtime (a : int) : int = ((a lsl 1) lxor (if a land 0x80 <> 0 then 0x1b else 0)) land 0xff

let rec gmul (a : int) (b : int) : int = if b = 0 then 0 else (if b land 1 <> 0 then a else 0) lxor gmul (xtime a) (b lsr 1)

let sbox : int array =
  (* the powers of 3 go through every non-zero element: its logarithms *)
  let exp = Array.make 256 0 and log = Array.make 256 0 in
  let x = ref 1 in
  for i = 0 to 254 do
    exp.(i) <- !x;
    log.(!x) <- i;
    x := gmul !x 3
  done;
  let inverse a = if a = 0 then 0 else exp.((255 - log.(a)) mod 255) in
  let rotl8 b n = ((b lsl n) lor (b lsr (8 - n))) land 0xff in
  Array.init 256 (fun a ->
      let b = inverse a in
      b lxor rotl8 b 1 lxor rotl8 b 2 lxor rotl8 b 3 lxor rotl8 b 4 lxor 0x63)

type key = { rounds : int; w : int array (* the expanded key, a byte each *) }

let expand (k : string) : key =
  let nk = String.length k / 4 in
  let rounds = nk + 6 in
  let words = 4 * (rounds + 1) in
  let w = Array.make (4 * words) 0 in
  String.iteri (fun i c -> w.(i) <- Char.code c) k;
  let rcon = ref 1 in
  for i = nk to words - 1 do
    let t = Array.init 4 (fun j -> w.((4 * (i - 1)) + j)) in
    let t =
      if i mod nk = 0 then begin
        (* RotWord, SubWord, and the round constant *)
        let t = [| sbox.(t.(1)) lxor !rcon; sbox.(t.(2)); sbox.(t.(3)); sbox.(t.(0)) |] in
        rcon := xtime !rcon;
        t
      end
      else if nk > 6 && i mod nk = 4 then Array.map (fun b -> sbox.(b)) t
      else t
    in
    for j = 0 to 3 do
      w.((4 * i) + j) <- w.((4 * (i - nk)) + j) lxor t.(j)
    done
  done;
  { rounds; w }

(* FIPS 197's four steps, as it names them. What the tests hold
 * [encrypt_block] against. *)
let encrypt_block_simple (k : key) (block : string) : string =
  let s = Array.init 16 (fun i -> Char.code block.[i]) in
  let add_round_key r = for i = 0 to 15 do s.(i) <- s.(i) lxor k.w.((16 * r) + i) done in
  (* the state column by column: byte i is row (i mod 4), column (i / 4) *)
  let sub_shift () =
    let t = Array.copy s in
    for c = 0 to 3 do
      for r = 0 to 3 do
        s.((4 * c) + r) <- sbox.(t.((4 * ((c + r) mod 4)) + r))
      done
    done
  in
  let mix () =
    for c = 0 to 3 do
      let a = Array.init 4 (fun r -> s.((4 * c) + r)) in
      for r = 0 to 3 do
        s.((4 * c) + r) <- xtime a.(r) lxor (xtime a.((r + 1) mod 4) lxor a.((r + 1) mod 4)) lxor a.((r + 2) mod 4) lxor a.((r + 3) mod 4)
      done
    done
  in
  add_round_key 0;
  for r = 1 to k.rounds - 1 do
    sub_shift ();
    mix ();
    add_round_key r
  done;
  sub_shift ();
  add_round_key k.rounds;
  String.init 16 (fun i -> Char.chr s.(i))

(*****************************************************************************)
(* opti: a round in one pass *)
(*****************************************************************************)

(* SubBytes, ShiftRows and MixColumns of a byte are three tables read:
 * the S-box's byte, its double and its triple (MixColumns multiplies by
 * 1, 2 and 3 only), and [from] says which byte ShiftRows brings to each
 * place. A round is then, for each of the sixteen bytes, four tables
 * read and xored with the round's key; two arrays, one the state and
 * one the next, change places. No closure, no array made in a round,
 * no division.
 * old: encrypt_block was encrypt_block_simple: an array copied and four
 * made a round, xtime called, indices by mod (a call, on arm): 186,000
 * instructions a block by mini-ml for arm, 12,000 of GCM's 22,000 a
 * byte *)
let sbox2 : int array = Array.map xtime sbox
let sbox3 : int array = Array.map (fun b -> xtime b lxor b) sbox
let from : int array = Array.init 16 (fun i -> (4 * (((i / 4) + (i mod 4)) mod 4)) + (i mod 4))

let encrypt_block (k : key) (block : string) : string =
  let w = k.w in
  let s = ref (Array.init 16 (fun i -> Char.code block.[i] lxor w.(i))) and t = ref (Array.make 16 0) in
  for r = 1 to k.rounds - 1 do
    let a = !s and b = !t and base = 16 * r in
    for c = 0 to 3 do
      let i = 4 * c in
      let a0 = a.(from.(i)) and a1 = a.(from.(i + 1)) and a2 = a.(from.(i + 2)) and a3 = a.(from.(i + 3)) in
      b.(i) <- sbox2.(a0) lxor sbox3.(a1) lxor sbox.(a2) lxor sbox.(a3) lxor w.(base + i);
      b.(i + 1) <- sbox.(a0) lxor sbox2.(a1) lxor sbox3.(a2) lxor sbox.(a3) lxor w.(base + i + 1);
      b.(i + 2) <- sbox.(a0) lxor sbox.(a1) lxor sbox2.(a2) lxor sbox3.(a3) lxor w.(base + i + 2);
      b.(i + 3) <- sbox3.(a0) lxor sbox.(a1) lxor sbox.(a2) lxor sbox2.(a3) lxor w.(base + i + 3)
    done;
    s := b;
    t := a
  done;
  (* the last round: no MixColumns *)
  let a = !s and base = 16 * k.rounds in
  String.init 16 (fun i -> Char.chr (sbox.(a.(from.(i))) lxor w.(base + i)))
