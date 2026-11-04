(* e92ae1ec, its fix: Int32's words; and what must stay quiet: a constant
 * in a function only called when ints are wide (Poly1305's mac_limbs),
 * 0x3fffffff (max_int on the Pi 1), a shift of 16 bits by 8, a char's
 * code by 16, a value of no known width by 30 *)
let ( |: ) = Int32.logor

let rol (x : int32) (n : int) : int32 =
  Int32.shift_left x n |: Int32.shift_right_logical x (32 - n)

let start () = [| 0x67452301l; 0xefcdab89l; 0x98badcfel |]

let limbs (n : int) : int = (n land 0xffffffff) lsr 32

let simple (n : int) : int = n land 0x3fffffff

let mac (n : int) : int = if Sys.int_size >= 63 then limbs n else simple n

let half (s : string) : int =
  ((Char.code s.[0] lsl 8) lor Char.code s.[1]) lsl 8 lor (Char.code s.[2] lsl 16)

let bit (x : int) : int = x lsl 30

let () =
  print_int (Int32.to_int (rol (start ()).(1) 5));
  print_int (mac 7 + half "abc" + bit 1)
