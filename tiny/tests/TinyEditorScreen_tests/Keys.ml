(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyEditorScreen's test (TinyEditorScreen_test.sh): keys typed at the editor, with
 * no screen and no file, and after each scene its screen printed, a
 * line each between bars, then the cursor's place. A screen of 24
 * columns and 7 lines, 5 of them the text's. The same file is built by
 * OCaml and by tiny-ml for tiny-cpu: the same lines. A control key is
 * its byte in a string: C-a is \001, C-x \024, Escape \027; the arrows
 * are \128 to \131. *)
open TinyEditorScreen

let show what e =
  print_string ("== " ^ what); print_newline ();
  List.iter (fun l -> print_string ("|" ^ l ^ "|"); print_newline ()) (view e);
  let x, y = cursor e in
  print_string ("cursor " ^ string_of_int x ^ " " ^ string_of_int y); print_newline ()

(* the keys of a string, and what the last one asked *)
let keys e s =
  let last = ref Continue in
  String.iter (fun c -> last := key e (Char.code c)) s;
  match !last with Continue -> () | Save -> print_string "asks: save"; print_newline () | Quit -> print_string "asks: quit"; print_newline ()

let () =
  let e = create 24 7 "notes" "" in
  show "an empty text" e;
  keys e "hello world\nsecond line\nthird";
  show "three lines typed" e;
  keys e "\001\016\016\006\006\006\006\006";
  show "C-a, two lines up, five characters forward" e;
  keys e "\011";
  show "C-k: the rest of the line" e;
  keys e "\011\011";
  show "C-k twice more: the newline, the next line" e;
  keys e "\014\025";
  show "a line down, C-y: the three kills, one text" e;
  keys e "\127\127\127\004";
  show "three Backspace, one C-d" e;
  keys e "\027<\005 \128\128\129\131\130\130";
  show "Escape <, C-e, a space, the arrows" e;
  keys e "\024\017";
  show "C-x C-q, not saved: refused" e;
  keys e "\024\019";
  saved e;
  show "C-x C-s, and the program says it wrote" e;
  keys e "\024\017"

let () =
  let text = String.concat "\n" (List.init 12 (fun i -> "line " ^ string_of_int (i + 1) ^ (if i mod 4 = 3 then " needle" else ""))) in
  let e = create 24 7 "twelve" text in
  show "a text of twelve lines" e;
  keys e "\022";
  show "C-v: a screen down" e;
  keys e "\027>";
  show "Escape >: the end" e;
  keys e "\027v\012";
  show "Escape v: a screen up; C-l: the cursor's line in the middle" e;
  keys e "\027<\019nee";
  show "from the start, C-s nee" e;
  keys e "\019";
  show "C-s again: the next one" e;
  keys e "\019\019";
  show "twice more: the last one, then none" e;
  keys e "\127";
  show "Backspace: a character less to look for" e;
  keys e "\n!";
  show "Enter ends the search; a ! typed" e;
  keys e "\019zz\007";
  show "C-s zz, none; C-g" e;
  keys e "\024x\027x\000";
  show "what is not a command" e

let () =
  let e = create 24 7 "wide" "\tif(x)\n\t\treturn a\tb;\nabcdefghijklmnopqrstuvwxyz0123456789" in
  show "tabs, and a line wider than the screen" e;
  keys e "\006\014";
  show "after the first tab, a line down: the same character's column" e;
  keys e "\014\005";
  show "the wide line's end: the screen follows the cursor" e;
  keys e "\016\016\001";
  show "back up: the screen as it was" e
