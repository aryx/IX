(* the stdlib's later functions (lib_core's), OCaml's output by mini-ml *)

let show l = String.concat " " (List.map string_of_int l)

(* not %Lx, %ld: mini-ml's formats don't have them yet *)
let x32 n = Int32.format "%x" n
let x64 n = Int64.format "%x" n
let d64 = Int64.to_string

let () =
  (* Bytes: the binary fields, and a string not changed by its bytes *)
  let s = "abc" in
  let b = Bytes.of_string s in
  Bytes.set b 0 'X';
  Printf.printf "%s %s %s\n" s (Bytes.to_string b) (Bytes.to_string (Bytes.copy b));
  let b = Bytes.make 16 '\000' in
  Bytes.set_int32_le b 0 0x8765_4321l;
  Bytes.set_int32_be b 4 0x8765_4321l;
  Bytes.set_uint16_le b 8 0xbeef;
  Bytes.set_uint16_be b 10 0xbeef;
  Bytes.set_uint8 b 12 0xfe;
  Bytes.iteri (fun i c -> if i < 13 then Printf.printf "%02x" (Char.code c)) b;
  print_newline ();
  Printf.printf "%s %s %x %x %d %d %d\n" (x32 (Bytes.get_int32_le b 0)) (x32 (Bytes.get_int32_be b 4))
    (Bytes.get_uint16_le b 8) (Bytes.get_uint16_be b 10) (Bytes.get_uint8 b 12) (Bytes.get_int8 b 12)
    (Bytes.get_int16_be b 10);
  Bytes.set_int64_le b 0 0x0123_4567_89ab_cdefL;
  Bytes.set_int64_be b 8 0x0123_4567_89ab_cdefL;
  Printf.printf "%s %s %s\n" (x64 (Bytes.get_int64_le b 0)) (x64 (Bytes.get_int64_be b 8)) (x32 (Bytes.get_int32_le b 8));
  Printf.printf "%s\n" (match Bytes.index_from_opt (Bytes.of_string "a.b.c") 2 '.' with Some i -> string_of_int i | None -> "none");

  (* Buffer *)
  let buf = Buffer.create 4 in
  Buffer.add_bytes buf (Bytes.of_string "hello, world");
  Buffer.truncate buf 5;
  Buffer.add_uint16_le buf 0x4241;
  Buffer.add_int32_le buf 0x46454443l;
  Buffer.add_int64_le buf 0x4e4d4c4b4a494847L;
  print_endline (Buffer.contents buf);

  (* Queue *)
  let q = Queue.create () in
  Printf.printf "%b" (Queue.is_empty q);
  Queue.push 1 q; Queue.add 2 q;
  Printf.printf " %b %d" (Queue.is_empty q) (Queue.pop q);
  let a = Queue.take_opt q in
  let b = Queue.take_opt q in
  Printf.printf " %d %b\n" (match a with Some n -> n | None -> -1) (b = None);

  (* List *)
  print_endline (show (List.filteri (fun i x -> i mod 2 = 0 && x > 1) [ 1; 2; 3; 4; 5; 6; 7 ]));
  print_endline (show (List.sort_uniq compare [ 3; 1; 3; 2; 1; 1; 9 ]));
  print_endline (String.concat " " (List.map snd (List.stable_sort (fun (a, _) (b, _) -> compare a b)
    [ (2, "c"); (1, "a"); (2, "d"); (1, "b") ])));
  let k = "k" in
  Printf.printf "%b %b\n" (List.assq_opt k [ ("j", 1); (k, 2) ] = Some 2) (List.assq_opt 3 [ (1, 1) ] = None);
  print_endline (show (List.map fst (List.remove_assoc 2 [ (1, 'a'); (2, 'b'); (3, 'c'); (2, 'd') ])));

  (* Array *)
  let a = [| 5; 3; 8; 1 |] in
  Printf.printf "%b %b %b %b %b" (Array.exists (fun x -> x > 7) a) (Array.exists (fun x -> x > 8) a)
    (Array.for_all (fun x -> x > 0) a) (Array.for_all (fun x -> x > 1) a) (Array.mem 8 a);
  Printf.printf " %d %b\n" (match Array.find_opt (fun x -> x < 5) a with Some x -> x | None -> 0)
    (Array.find_opt (fun x -> x > 9) a = None);
  Array.sort compare a;
  print_endline (show (Array.to_list a));
  let p = [| (2, "c"); (1, "a"); (2, "d"); (1, "b") |] in
  Array.stable_sort (fun (a, _) (b, _) -> compare a b) p;
  print_endline (String.concat " " (List.map snd (Array.to_list p)));

  (* Int64, Int32, Int *)
  Printf.printf "%d %d %d %d\n" (Int64.compare 1L 2L) (Int64.compare (-1L) 1L) (Int64.unsigned_compare (-1L) 1L)
    (Int32.compare 7l 7l);
  Printf.printf "%s %s %s %s\n" (d64 (Int64.unsigned_div (-1L) 10L)) (d64 (Int64.unsigned_rem (-1L) 10L))
    (d64 (Int64.unsigned_div 100L (-1L))) (d64 (Int64.unsigned_div (-1L) (-2L)));
  Printf.printf "%s %s %s %s\n" (d64 Int64.min_int) (d64 Int64.max_int) (Int32.to_string Int32.min_int)
    (Int32.to_string Int32.max_int);
  Printf.printf "%b %b\n" (Int64.of_string_opt "0x10" = Some 16L) (Int64.of_string_opt "x" = None);
  Printf.printf "%d %d\n" (Int.max 3 (-4)) (Int.min 3 (-4));
  Printf.printf "%b %b %b\n" (int_of_string_opt "42" = Some 42) (int_of_string_opt "4x" = None)
    (Sys.int_size = Sys.word_size - 1);

  (* Hashtbl, Filename, Digest, Seq, Fun *)
  let h = Hashtbl.create 8 in
  Hashtbl.add h 1 "a";
  Hashtbl.reset h;
  Printf.printf "%d\n" (Hashtbl.length h);
  Printf.printf "%s %s %s\n" (Filename.remove_extension "a/b.tar.gz") (Filename.remove_extension "noext")
    (Filename.quote "it's a file");
  (* not Digest.string: MD5 is not in mini-ml's runtime yet *)
  print_endline (Digest.to_hex (String.init 16 (fun i -> Char.chr (i * 17))));
  print_endline (show (List.of_seq (Seq.append (Seq.return 1) (Seq.return 2))));
  (try Fun.protect ~finally:(fun () -> print_string "finally ") (fun () -> failwith "work")
   with Failure s -> print_endline s);

  (* Out_channel; not In_channel: mini-ml's runtime opens a file only
   * to write it, and has no Sys.remove yet *)
  let n = Out_channel.with_open_bin "/dev/null" (fun oc -> Out_channel.output_string oc "one\ntwo\n"; 2) in
  Out_channel.with_open_gen [ Open_wronly; Open_append ] 0o644 "/dev/null" (fun oc -> output_string oc "three");
  Printf.printf "%d\n" n
