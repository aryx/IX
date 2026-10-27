(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* A string's little-endian integers in place (Lower's BytesGet and
 * BytesSet, Emit's loads and stores): Bytes' and String's 16 and 32
 * bits read and written at each offset (arm's a byte at a time, so the
 * unaligned too), the sign and the 16 bits' full range, the bounds at
 * both ends (-1, the last index that fits, the one after; a string too
 * short); at -O0 the runtime's (caml_bytes_get16...) *)

let check name f = match f () with () -> () | exception Invalid_argument m -> Printf.printf "%s: Invalid_argument %s\n" name m

let () =
  let b = Bytes.init 12 (fun i -> Char.chr ((i * 37 + 200) land 0xff)) in
  for i = 0 to 8 do
    Printf.printf "%d: %d %ld\n" i (Bytes.get_uint16_le b i) (Bytes.get_int32_le b i)
  done;
  let s = Bytes.to_string b in
  Printf.printf "string: %d %ld %d %ld\n" (String.get_uint16_le s 3) (String.get_int32_le s 5) (String.get_uint16_le s 10)
    (String.get_int32_le s 8);
  let w = Bytes.make 10 '\000' in
  List.iteri (fun k v -> Bytes.set_int32_le w (k mod 7) v; Printf.printf "set32 %d %ld: %ld %S\n" (k mod 7) v (Bytes.get_int32_le w (k mod 7)) (Bytes.to_string w))
    [ 0l; 1l; -1l; 0x7fffffffl; 0x80000000l; 0x12345678l; -0x2152411l ];
  List.iteri (fun k v -> Bytes.set_uint16_le w (k mod 9) v; Printf.printf "set16 %d %d: %d\n" (k mod 9) v (Bytes.get_uint16_le w (k mod 9)))
    [ 0; 1; 0xff; 0x100; 0xffff; 0x1234; 0x10005 ];
  check "get32 -1" (fun () -> ignore (Bytes.get_int32_le b (-1)));
  check "get32 8" (fun () -> ignore (Bytes.get_int32_le b 8));
  check "get32 9" (fun () -> ignore (Bytes.get_int32_le b 9));
  check "get16 10" (fun () -> ignore (Bytes.get_uint16_le b 10));
  check "get16 11" (fun () -> ignore (Bytes.get_uint16_le b 11));
  check "get16 -1" (fun () -> ignore (Bytes.get_uint16_le b (-1)));
  check "set32 7" (fun () -> Bytes.set_int32_le w 7 5l);
  check "set16 9" (fun () -> Bytes.set_uint16_le w 9 5);
  check "short" (fun () -> ignore (String.get_int32_le "ab" 0));
  check "empty" (fun () -> ignore (String.get_uint16_le "" 0));
  (* a reader's loop: the sum of a buffer's words, blocks made meanwhile *)
  let big = Bytes.init 4096 (fun i -> Char.chr (i land 0xff)) in
  let sum = ref 0l and n = ref 0 in
  for i = 0 to 1023 do
    sum := Int32.add !sum (Bytes.get_int32_le big (4 * i));
    n := !n + Bytes.get_uint16_le big (4 * i + 1)
  done;
  Printf.printf "sum %ld %d\n" !sum !n
