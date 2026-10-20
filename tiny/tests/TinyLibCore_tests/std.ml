(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyLibCore/'s functions, each called and its result printed
 * (TinyLibCore_test.sh): a program OCaml runs on its own library, which
 * says what to expect (std.expected), and tiny-ml builds on
 * TinyLibCore/. No Hashtbl.fold's order: it is the library's own. *)
let str s = print_string ("[" ^ s ^ "]")
let strs l = List.iter str l; print_newline ()
let int n = print_int n; print_char ' '
let ints l = List.iter int l; print_newline ()
let bool b = print_string (if b then "true " else "false ")
let opt = function Some n -> int n | None -> print_string "none "

let () =
  ints (List.concat_map (fun x -> [ x; x * 10 ]) [ 1; 2; 3 ]);
  ints (List.filteri (fun i _ -> i mod 2 = 0) [ 10; 11; 12; 13; 14 ]);
  ints (List.init 4 (fun i -> i * i));
  ints (List.init 0 (fun i -> i));
  ints (List.mapi (fun i x -> (10 * i) + x) [ 7; 8; 9 ]);
  ints (List.mapi (fun i x -> i + x) []);
  opt (List.assoc_opt "b" [ "a", 1; "b", 2 ]); opt (List.assoc_opt "c" [ "a", 1 ]);
  opt (List.nth_opt [ 5; 6 ] 1); opt (List.nth_opt [ 5; 6 ] 2); print_newline ();
  strs (List.map2 ( ^ ) [ "a"; "b" ] [ "x"; "y" ]);
  (try strs (List.map2 ( ^ ) [ "a" ] []) with Invalid_argument _ -> print_endline "map2: lengths");
  int (Option.get (Some 3)); print_newline ();
  ints (List.sort compare [ 3; 1; 2; 1 ]); strs (List.sort compare [ "b"; "a"; "ab" ]);
  strs (List.map snd (List.sort (fun (a, _) (b, _) -> compare a b) [ 2, "x"; 1, "y"; 2, "z"; 1, "w" ]));
  opt (int_of_string_opt "42"); opt (int_of_string_opt "-7"); opt (int_of_string_opt ""); opt (int_of_string_opt "4x");
  opt (int_of_string_opt "-"); opt (int_of_string_opt "007"); print_newline ();
  strs [ Filename.concat "/" "ls"; Filename.concat "/bin" "ls"; Filename.concat "" "ls"; Filename.concat "a/" "b" ]

let () =
  opt (String.index_opt "hello" 'l'); opt (String.index_opt "hello" 'z');
  opt (String.index_from_opt "hello" 3 'l'); opt (String.index_from_opt "hello" 4 'l');
  opt (String.index_from_opt "hello" 5 'l'); int (String.index_from "a=b" 0 '=');
  (try int (String.index_from "ab" 0 '=') with Not_found -> print_string "not found "); print_newline ();
  bool (String.contains "a/b" '/'); bool (String.contains "" '/');
  bool (String.exists (fun c -> c = '*') "a*"); bool (String.exists (fun c -> c = '*') "");
  bool (String.for_all (fun c -> c >= '0' && c <= '9') "123"); bool (String.for_all (fun c -> c = 'a') "ab");
  bool (String.for_all (fun c -> c = 'a') ""); print_newline ();
  String.iter (fun c -> int (Char.code c)) "abc"; print_newline ();
  str (String.concat ", " [ "a"; "b"; "c" ]); str (String.concat "," []); str (String.concat "," [ "a" ]); print_newline ();
  strs (String.split_on_char ' ' "a b  c"); strs (String.split_on_char ':' ""); strs (String.split_on_char ':' ":a:");
  strs (String.split_on_char ':' "abc"); print_newline ();
  str (String.concat "" [ "a"; "b"; "c"; "d"; "e" ]); str (String.concat "-" [ "a"; "b"; "c"; "d"; "e" ]); print_newline ();
  opt (String.rindex_opt "a/b/c" '/'); opt (String.rindex_opt "abc" '/'); opt (String.rindex_opt "" '/'); print_newline ();
  str (String.map (fun c -> if c = ' ' then '_' else c) "Plan 9 os"); str (String.map (fun c -> c) ""); print_newline ();
  str (String.lowercase_ascii "OCaml 4.14!"); str (String.lowercase_ascii "small"); str (String.lowercase_ascii ""); print_newline ();
  str (String.trim "  a b \t\n"); str (String.trim "   "); str (String.trim ""); str (String.trim "x"); print_newline ();
  (* (their labels left out, as the tiny programs call them) *)
  bool (String.starts_with "ht" "http"); bool (String.starts_with "http" "ht"); bool (String.starts_with "" "");
  int (String.get_uint16_le "\001\002" 0); int (String.get_uint16_le "x\255\255" 1); print_newline ();
  bool (Filename.check_suffix "a.ml" ".ml"); bool (Filename.check_suffix "ml" ".ml"); bool (Filename.check_suffix "a.ml" ""); print_newline ()

let () =
  let b = Buffer.create 16 in
  Buffer.add_string b "one"; Buffer.add_char b ' '; Buffer.add_string b "two";
  str (Buffer.contents b); int (Buffer.length b);
  Buffer.clear b; int (Buffer.length b); Buffer.add_char b 'x'; str (Buffer.contents b); print_newline ()

let () =
  let h = Hashtbl.create 16 in
  Hashtbl.replace h "x" [ "a"; "b" ]; Hashtbl.replace h "y" []; Hashtbl.replace h "x" [ "c" ];
  strs (Hashtbl.find h "x"); bool (Hashtbl.mem h "y"); bool (Hashtbl.mem h "z");
  (match Hashtbl.find_opt h "z" with None -> print_string "none " | Some _ -> print_string "some ");
  Hashtbl.remove h "x"; bool (Hashtbl.mem h "x");
  (try strs (Hashtbl.find h "x") with Not_found -> print_endline "not found");
  int (Hashtbl.fold (fun _ _ n -> n + 1) h 0); print_newline ()

(* Buffer past its first bytes, Hashtbl past its buckets: they double;
 * add hides a key's binding, remove shows it again, as OCaml's *)
let () =
  let b = Buffer.create 1 in
  for i = 0 to 999 do Buffer.add_char b (Char.chr (97 + (i mod 26))) done;
  Buffer.add_string b (String.make 300 '.');
  int (Buffer.length b); str (String.sub (Buffer.contents b) 990 15); print_newline ();
  let h = Hashtbl.create 1 in
  for i = 0 to 999 do Hashtbl.replace h (string_of_int i) i done;
  for i = 0 to 499 do Hashtbl.remove h (string_of_int (2 * i)) done;
  int (Hashtbl.length h); int (Hashtbl.fold (fun _ v n -> n + v) h 0); int (Hashtbl.find h "999");
  let t = Hashtbl.create 8 in
  Hashtbl.add t (1, "a") "first"; Hashtbl.add t (1, "a") "second"; str (Hashtbl.find t (1, "a"));
  Hashtbl.remove t (1, "a"); str (Hashtbl.find t (1, "a")); int (Hashtbl.length t); print_newline ()

(* int_of_string (decimal, -, 0x), filter_map, of_list and to_list,
 * Option.iter *)
let () =
  int (int_of_string "42"); int (int_of_string "-7"); int (int_of_string "0x1f"); int (int_of_string "0xFF");
  (try int (int_of_string "4x") with Failure m -> str m);
  opt (int_of_string_opt "x"); print_newline ();
  List.iter int (List.filter_map (fun x -> if x mod 2 = 0 then Some (x * 10) else None) [ 1; 2; 3; 4 ]);
  int (Array.length (Array.of_list [])); List.iter int (Array.to_list (Array.of_list [ 5; 6; 7 ]));
  Option.iter int (Some 8); Option.iter int None; print_newline ()

(* Seq: each element made when pulled (pulled counts them: a take
 * stops the pulling), List's and Array's to_seq and of_seq *)
let () =
  let pulled = ref 0 in
  let nat = Seq.init 1000 (fun i -> incr pulled; i) in
  List.iter int (List.of_seq (Seq.take 3 (Seq.filter (fun x -> x mod 2 = 1) nat))); int !pulled;
  List.iter int (List.of_seq (Seq.take_while (fun x -> x < 4) (Seq.drop_while (fun x -> x < 2) (List.to_seq [ 0; 1; 2; 3; 4; 1 ]))));
  List.iter int (List.of_seq (Seq.concat_map (fun x -> List.to_seq [ x; x * 10 ]) (Array.to_seq (Array.of_list [ 1; 2 ]))));
  List.iter int (List.of_seq (Seq.filter_map (fun x -> if x > 1 then Some (x + 100) else None) (Seq.map (fun x -> x * 2) (List.to_seq [ 0; 1; 2 ]))));
  int (Seq.fold_left ( + ) 0 (Seq.init 10 (fun i -> i))); Seq.iter int (Seq.take 2 nat);
  (match Seq.empty () with Seq.Nil -> str "empty" | Seq.Cons _ -> str "not"); print_newline ()

(* for tiny-db: List's find_opt, mem_assoc, iter2, rev_map, stable_sort
 * (its ties kept in order); Array's init, sub, copy (another array),
 * map, append, concat; Hashtbl.find_all, the latest first *)
let () =
  opt (List.find_opt (fun x -> x > 2) [ 1; 3; 5 ]); opt (List.find_opt (fun x -> x > 9) [ 1 ]);
  bool (List.mem_assoc 2 [ 1, "a"; 2, "b" ]); bool (List.mem_assoc 3 [ 1, "a" ]);
  List.iter2 (fun a b -> int (a * b)) [ 1; 2 ] [ 3; 4 ]; List.iter int (List.rev_map (fun x -> x + 1) [ 1; 2; 3 ]);
  List.iter (fun (k, v) -> int k; str v) (List.stable_sort (fun (a, _) (b, _) -> compare a b) [ 2, "x"; 1, "y"; 2, "z"; 1, "w" ]);
  print_newline ();
  let a = Array.init 5 (fun i -> i * i) in
  let c = Array.copy a in c.(0) <- 99;
  List.iter int (Array.to_list (Array.sub a 1 3)); int a.(0); int c.(0); int (Array.length (Array.init 0 (fun i -> i)));
  List.iter int (Array.to_list (Array.map (fun x -> x + 1) (Array.append (Array.sub a 0 2) (Array.sub a 3 2))));
  List.iter int (Array.to_list (Array.concat [ Array.sub a 0 1; Array.of_list []; Array.sub a 4 1 ]));
  (try ignore (Array.sub a 3 3) with Invalid_argument m -> str m);
  let h = Hashtbl.create 4 in
  Hashtbl.add h "k" 1; Hashtbl.add h "j" 0; Hashtbl.add h "k" 2; List.iter int (Hashtbl.find_all h "k"); int (List.length (Hashtbl.find_all h "z"));
  print_newline ()

(* for tiny-vcs: Filename.dirname (OCaml's, its slashes), Option.map
 * and to_list, Array.iter, List.remove_assoc (the first only) and
 * sort_uniq *)
let () =
  List.iter (fun s -> str (Filename.dirname s)) [ "a/b"; "a"; ""; "/"; "/a"; "a/b/"; "a//b"; "//"; "/a/b//c//" ];
  print_newline ();
  opt (Option.map (fun x -> x + 1) (Some 1)); opt (Option.map (fun x -> x + 1) None);
  List.iter int (Option.to_list (Some 3)); int (List.length (Option.to_list None));
  Array.iter int (Array.of_list [ 4; 5 ]);
  List.iter (fun (k, v) -> int k; str v) (List.remove_assoc 1 [ 2, "a"; 1, "b"; 1, "c" ]);
  List.iter int (List.sort_uniq compare [ 3; 1; 3; 2; 1 ]); print_newline ()

(* for tiny-build: List.memq (the same block, not an equal one),
 * partition, String.iteri, Hashtbl.copy (the two apart after it) *)
let () =
  let a = [ 1 ] and b = [ 1 ] in
  bool (List.memq a [ b; a ]); bool (List.memq a [ b ]); bool (List.mem a [ b ]);
  let even, odd = List.partition (fun x -> x mod 2 = 0) [ 1; 2; 3; 4; 5 ] in
  List.iter int even; List.iter int odd;
  String.iteri (fun i c -> int i; str (String.make 1 c)) "ab";
  let h = Hashtbl.create 4 in
  Hashtbl.replace h "k" 1;
  let h2 = Hashtbl.copy h in
  Hashtbl.replace h2 "k" 2; Hashtbl.replace h2 "j" 3;
  int (Hashtbl.find h "k"); int (Hashtbl.length h); int (Hashtbl.find h2 "k"); int (Hashtbl.length h2); print_newline ()

(* for tiny-c and the toolchain: Int64 (tiny-ml's of four pieces), its
 * edges, and what tiny-c folds; List's find, find_map, rev_append,
 * combine, for_all2; String.index; Filename's basename, is_relative,
 * chop_suffix, remove_extension; Bytes.of_string a copy *)
let () =
  let i64 x = str (Int64.to_string x) in
  let vs = List.map Int64.of_string [ "0"; "1"; "-1"; "7"; "-7"; "0x7fffffff"; "0xffffffff"; "-2147483648"; "12345678901"; "-987654321987";
                                      "9223372036854775807"; "-9223372036854775808"; "0x8000000000000000"; "0o17"; "0b101"; "1_000" ] in
  List.iter i64 vs; print_newline ();
  List.iter (fun a -> List.iter (fun b ->
    i64 (Int64.add a b); i64 (Int64.sub a b); i64 (Int64.mul a b);
    (if b <> Int64.zero then (i64 (Int64.div a b); i64 (Int64.rem a b)));
    i64 (Int64.logand a b); i64 (Int64.logor a b); i64 (Int64.logxor a b); int (Int64.compare a b); bool (Int64.equal a b)) vs;
    List.iter (fun n -> i64 (Int64.shift_left a n); i64 (Int64.shift_right a n); i64 (Int64.shift_right_logical a n)) [ 0; 1; 15; 16; 17; 31; 32; 48; 63 ];
    i64 (Int64.neg a); i64 (Int64.lognot a); i64 (Int64.succ a); i64 (Int64.pred a); i64 (Int64.abs a); int (Int64.to_int a land 0xffff);
    print_newline ()) vs;
  List.iter (fun n -> i64 (Int64.of_int n)) [ 0; 5; -5; 0x3fffffff; - 0x40000000 ];
  i64 Int64.max_int; i64 Int64.min_int; i64 Int64.minus_one; i64 Int64.one; i64 Int64.zero;
  (try i64 (Int64.div Int64.one Int64.zero) with Division_by_zero -> print_string "division by zero ");
  (try i64 (Int64.of_string "12a") with Failure _ -> print_string "not a number ");
  print_newline ();
  int (List.find (fun x -> x > 1) [ 1; 2; 3 ]); (try int (List.find (fun x -> x > 5) [ 1 ]) with Not_found -> print_string "not found ");
  opt (List.find_map (fun x -> if x > 1 then Some (10 * x) else None) [ 1; 2; 3 ]); opt (List.find_map (fun _ -> None) [ 1 ]);
  ints (List.rev_append [ 1; 2 ] [ 3; 4 ]);
  List.iter (fun (a, b) -> int a; str b) (List.combine [ 1; 2 ] [ "a"; "b" ]); print_newline ();
  bool (List.for_all2 (fun a b -> a < b) [ 1; 2 ] [ 2; 3 ]); bool (List.for_all2 (fun a b -> a < b) [ 1; 4 ] [ 2; 3 ]);
  int (String.index "a=b" '='); (try int (String.index "ab" '=') with Not_found -> print_string "not found "); print_newline ();
  strs (List.map Filename.basename [ ""; "/"; "a"; "a/b"; "/a/b/"; "a//"; "//" ]);
  List.iter (fun f -> bool (Filename.is_relative f)) [ ""; "a"; "/a"; "./a" ]; print_newline ();
  strs [ Filename.chop_suffix "a.c" ".c"; Filename.chop_suffix "x/b.tm" ".tm" ];
  strs (List.map Filename.remove_extension [ "a.c"; "a/b.c"; ".profile"; "a.b/c"; "x..y"; "a.tar.gz"; "/a/.b.c"; "noext"; "" ]);
  let s = "abc" in let b = Bytes.of_string s in Bytes.set b 0 'x'; strs [ s; Bytes.to_string b ];
  (* Printf, which tiny-ml reads as concatenations *)
  strs [ Printf.sprintf "r%d, r%d" 3 (-12); Printf.sprintf "%s=%c%%" "x" 'y'; Printf.sprintf "%x %x %02x" 0 255 7 ];
  strs [ Printf.sprintf "%5d|%-5d|%05d|%3s|%-3s|" 42 42 (-42) "a" "b"; Printf.sprintf "%S" "a\"b\n\001"; Printf.sprintf "no hole" ];
  let f = Printf.sprintf "%s-%d" in strs [ f "a" 1; Printf.sprintf "%s/%s" "x" "y" ^ "!" ];
  (try Printf.ksprintf failwith "bad %d" 7 with Failure m -> str m);
  let b = Buffer.create 8 in Printf.bprintf b "%d+%d" 1 2; Printf.bprintf b "=%s" "3"; str (Buffer.contents b); print_newline ();
  (* Marshal: OCaml's bytes, and the values back; what is shared, shared *)
  let hex s = String.concat "" (List.init (String.length s) (fun i -> Printf.sprintf "%02x" (Char.code s.[i]))) in
  let shared = "ab" in
  let v = ([ 1; -1; 63; 64; -129; 40000; -40000; 1000000; 1000000000 ], (shared, shared), Some (ref [ None; Some 'z' ]), String.make 40 'x', String.make 300 'y', Array.of_list [ 1; 2 ]) in
  let m = Marshal.to_string v [] in
  str (hex m); int (String.length m); print_newline ();
  str (hex (Marshal.to_string (shared, shared, [ 1; 2 ]) [ Marshal.No_sharing ])); print_newline ();
  let (l, (s1, s2), r, x, y, a) = (Marshal.from_string m 0 : int list * (string * string) * char option list ref option * string * string * int array) in
  ints l; bool (s1 == s2); str s1; (match r with Some r -> int (List.length !r) | None -> ()); int (String.length x); int (String.length y); int (Array.length a); print_newline ()
