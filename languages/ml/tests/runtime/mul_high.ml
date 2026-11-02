(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Wide.mul_high (Ir's MulHigh: arm's MULLU, arm64's UMULH in ssa's
 * code, the runtime's ml_mul_high in simple's): the bits of a product
 * above an int's. What it prints is the same where an int has 31 bits
 * and 63: the identities of numbers made from Sys.int_size, then
 * pseudo-random pairs (in a variable, in a loop: the instruction, not a
 * constant folded) against the product's halves by ints' arithmetic *)

external mul_high : int -> int -> int = "ml_mul_high"

let n = Sys.int_size

(* the reference: a and b in halves of h bits, no product overflowing *)
let reference a b =
  let h = n / 2 in
  let m = (1 lsl h) - 1 in
  let a0 = a land m and a1 = a lsr h and b0 = b land m and b1 = b lsr h in
  let mid = (a1 * b0) + ((a0 * b0) lsr h) in
  let mid2 = (a0 * b1) + (mid land m) in
  ((a1 * b1) + (mid lsr h) + (mid2 lsr h)) lsr (n - (2 * h))

let check name got want = Printf.printf "%s: %b\n" name (got = want)

let () =
  check "0 0" (mul_high 0 0) 0;
  check "max_int 0" (mul_high max_int 0) 0;
  check "max_int 1" (mul_high max_int 1) 0;
  check "max_int 2" (mul_high max_int 2) 0;
  check "max_int 3" (mul_high max_int 3) 1;
  check "max_int max_int" (mul_high max_int max_int) ((1 lsl (n - 2)) - 1);
  check "2^(n-2) a" (mul_high (1 lsl (n - 2)) 0x1234567) (0x1234567 lsr 2);
  check "2^(n/2+1) 2^(n/2)" (mul_high (1 lsl ((n / 2) + 1)) (1 lsl (n / 2))) 1;
  check "2^(n-2) 2^(n-2)" (mul_high (1 lsl (n - 2)) (1 lsl (n - 2))) (1 lsl (n - 4));
  (* limbs of 28 bits, Bignum's on arm: a product's high part *)
  let l = (1 lsl 28) - 1 in
  check "limbs" ((mul_high l l lsl (n - 28)) lor ((l * l) lsr 28)) ((1 lsl 28) - 2);
  let x = ref 12345 and bad = ref 0 in
  for _i = 1 to 20000 do
    x := (!x * 1103515245 + 12345) land max_int;
    let a = !x lsr (!x land 15) in
    x := (!x * 1103515245 + 12345) land max_int;
    let b = !x lsr (!x land 7) in
    if mul_high a b <> reference a b then incr bad
  done;
  Printf.printf "random pairs, wrong: %d\n" !bad
