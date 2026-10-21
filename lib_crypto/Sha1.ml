(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Sha1.mli *)

type t = string

(* 32-bit arithmetic in OCaml's 63-bit ints, masked *)
let mask = 0xffffffff
let rol x n = ((x lsl n) lor (x lsr (32 - n))) land mask

let blocks (h : int array) (b : Bytes.t) =
  let w = Array.make 80 0 in
  for blk = 0 to Bytes.length b / 64 - 1 do
    for i = 0 to 15 do w.(i) <- Int32.to_int (Bytes.get_int32_be b (blk * 64 + i * 4)) land mask done;
    for i = 16 to 79 do w.(i) <- rol (w.(i - 3) lxor w.(i - 8) lxor w.(i - 14) lxor w.(i - 16)) 1 done;
    let a = ref h.(0) and b' = ref h.(1) and c = ref h.(2) and d = ref h.(3) and e = ref h.(4) in
    for i = 0 to 79 do
      let f, k =
        if i < 20 then (!b' land !c) lor (lnot !b' land mask land !d), 0x5a827999
        else if i < 40 then !b' lxor !c lxor !d, 0x6ed9eba1
        else if i < 60 then (!b' land !c) lor (!b' land !d) lor (!c land !d), 0x8f1bbcdc
        else !b' lxor !c lxor !d, 0xca62c1d6 in
      let t = (rol !a 5 + f + !e + k + w.(i)) land mask in
      e := !d; d := !c; c := rol !b' 30; b' := !a; a := t
    done;
    h.(0) <- (h.(0) + !a) land mask; h.(1) <- (h.(1) + !b') land mask; h.(2) <- (h.(2) + !c) land mask;
    h.(3) <- (h.(3) + !d) land mask; h.(4) <- (h.(4) + !e) land mask
  done

let start () = [| 0x67452301; 0xefcdab89; 0x98badcfe; 0x10325476; 0xc3d2e1f0 |]

(* the last [rest] bytes of [len], padded, then the five words *)
let finish (h : int array) (ss : string list) (rest : int) (len : int) : t =
  let padded = (rest + 9 + 63) / 64 * 64 in
  let b = Bytes.make padded '\000' in
  ignore (List.fold_left (fun off s -> Bytes.blit_string s 0 b off (String.length s); off + String.length s) 0 ss);
  Bytes.set b rest '\x80';
  Bytes.set_int64_be b (padded - 8) (Int64.of_int (len * 8));
  blocks h b;
  let out = Bytes.create 20 in
  Array.iteri (fun i x -> Bytes.set_int32_be out (i * 4) (Int32.of_int x)) h;
  Bytes.to_string out

let strings (ss : string list) : t =
  let len = List.fold_left (fun n s -> n + String.length s) 0 ss in
  finish (start ()) ss len len

(* the whole blocks digested as they come, the rest kept for the next *)
let reads (next : unit -> string) : t =
  let h = start () and len = ref 0 in
  let rec go rest =
    match next () with
    | "" -> finish h [ rest ] (String.length rest) !len
    | s ->
        len := !len + String.length s;
        let s = rest ^ s in
        let whole = String.length s / 64 * 64 in
        blocks h (Bytes.unsafe_of_string (String.sub s 0 whole));
        go (String.sub s whole (String.length s - whole))
  in
  go ""

let string s = strings [ s ]

let to_hex (t : t) = String.concat "" (List.init 20 (fun i -> Printf.sprintf "%02x" (Char.code t.[i])))

let of_hex s =
  if String.length s <> 40 then invalid_arg "Sha1.of_hex";
  String.init 20 (fun i -> Char.chr (int_of_string ("0x" ^ String.sub s (i * 2) 2)))

let of_raw s = if String.length s <> 20 then invalid_arg "Sha1.of_raw" else s
let raw t = t
