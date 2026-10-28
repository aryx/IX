(* Toplevel constants folded (Fold): each one, computed at compile time,
 * against the same arithmetic at run time on values the compiler does
 * not know (a ref's), so that the target's wrapping (31 bits on arm,
 * 63 on arm64) is checked; ifs on constants, && and ||, comparisons of
 * chars and constructors *)

type color = Red | Green | Blue

let r = ref 0
let n x = r := x; !r

let wide = 1 lsl 40 <> 0
let top = 1 lsl 30
let sum = top + top
let neg = - top - top - 1
let ones = -1 lsr 1
let shifted = -16 asr 2
let quot = -7 / 2
let rem = -7 mod 2
let masked = if wide then 0xffff land 0x1234 else 0
let mixed = (lnot 5) lxor (3 lor 8) * 7 - succ (pred 2)
let chars = 'a' < 'b' && not ('z' = 'y')
let colors = Red < Blue || Green = Red
let same = Blue = Blue && Red <> Green
let skipped = if false then 1 / 0 else 3

let check name folded runtime = Printf.printf "%s %b\n" name (folded = runtime)

let () =
  check "wide" wide (n 1 lsl 40 <> 0);
  check "top" top (n 1 lsl 30);
  check "sum" sum (n top + n top);
  check "neg" neg (- (n top) - n top - 1);
  check "ones" ones (n (-1) lsr 1);
  check "shifted" shifted (n (-16) asr 2);
  check "quot" quot (n (-7) / 2);
  check "rem" rem (n (-7) mod 2);
  check "masked" masked (if wide then n 0xffff land 0x1234 else 0);
  check "mixed" mixed ((lnot (n 5)) lxor (n 3 lor 8) * 7 - succ (pred (n 2)));
  Printf.printf "%b %b %b %d\n" chars colors same skipped;
  Printf.printf "%d %d %d\n" quot rem shifted
