(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyLibStd's functions, each called and its result printed
 * (TinyLibStd_test.sh): a program OCaml runs on its own library, which
 * says what to expect (std.expected), and tiny-ml builds with
 * TinyLibStd.ml. No Hashtbl.fold: its order is the library's own. *)
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
