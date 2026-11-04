(* e92ae1ec^, lib_crypto/Sha1.ml: its words in ints masked by 0xffffffff,
 * -1 where an int has 31 bits (arm, the Pi 1): every hash was wrong
 * there. And cc6eb618's kernel/step4: a gigabyte, 0x40000000, as a bound,
 * min_int on the Pi 1; a word read from four bytes, the last shifted
 * past bit 30 *)
let mask = 0xffffffff
let rol x n = ((x lsl n) lor (x lsr (32 - n))) land mask

let start () = [| 0x67452301; 0xefcdab89; 0x98badcfe; 0x10325476; 0xc3d2e1f0 |]

let in_ram (pa : int) : bool = pa < 0x40000000

let word (s : string) : int =
  Char.code s.[0] lor (Char.code s.[1] lsl 8) lor (Char.code s.[2] lsl 16)
  lor (Char.code s.[3] lsl 24)

let flag = 0xf lsl 28

let () =
  let h = start () in
  print_int (rol h.(1) 5 + word "abcd" + flag);
  print_string (if in_ram 4096 then "y" else "n")
