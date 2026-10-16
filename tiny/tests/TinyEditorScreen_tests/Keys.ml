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

(* the keys of a string, each followed by those the editor gives itself
 * (a macro's, M-x's), and what the last one asked *)
let keys e s =
  let last = ref Continue in
  let rec given () = match pending e with Some k -> last := key e k; given () | None -> () in
  String.iter (fun c -> last := key e (Char.code c); given ()) s;
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
  keys e "\024x\027z\000";
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

let () =
  let e = create 24 7 "mx" "one fish\ntwo fish\nred fish\nblue fish" in
  keys e "\027x";
  show "Escape x: M-x asks for a command" e;
  keys e "end-of-b\t";
  show "end-of-b, then Tab: the name completed" e;
  keys e "\n";
  show "Enter: end-of-buffer done" e;
  keys e "\027xgoto-line\n3\n";
  show "M-x goto-line, 3" e;
  keys e "\027xkill-l\n";
  show "M-x kill-l, one command it starts: kill-line" e;
  keys e "\027<\027xreplace-string\nfish\ncat\n";
  show "M-x replace-string fish with cat, from the start" e;
  keys e "\027xnothing\n";
  show "a name that is no command" e;
  keys e "\027xyank\007";
  show "C-g: never mind" e

let () =
  let e = create 24 7 "macro" "a\nb\nc\nd" in
  keys e "\024(";
  show "C-x (: a macro, Def on the line below the text" e;
  keys e "\001- \014\024)";
  show "C-a, a dash and a space, a line down, C-x ): defined" e;
  keys e "\024e\024e";
  show "C-x e twice" e;
  keys e "\024(\005!\016\024e";
  show "a second macro, ended by C-x e: done once at once" e;
  keys e "\024)";
  show "C-x ) when none is being defined" e;
  keys e "\024(\024\019\024)\024e";
  show "a macro that saves: C-x e asks to save" e

(* the text's lines shown, each with its faces below (k a keyword, c a
 * comment, s a string or a character) *)
let show_faces what e =
  print_string ("== " ^ what); print_newline ();
  let v = view e in
  List.iteri (fun i f -> print_string ("|" ^ List.nth v i ^ "|"); print_newline (); print_string ("|" ^ f ^ "|"); print_newline ()) (faces e)

let () =
  let ml = "let x = 'a' (* a (* nested *)\n  comment *) in\nif s = \"say \\\"hi\\\"\" then 'b'\nlet f x' = x' :: []" in
  let e = create 32 7 "a.ml" ml in
  show_faces "OCaml: a comment over two lines, nested; strings, characters, x'" e;
  let e = create 32 7 "a.c" "#include <u.h>\nint f(char *s) /* a\n comment */ {\n\treturn s[0] == '\\n'; // end\n}" in
  show_faces "C: #include, a comment over two lines, a tab, // to the end" e;
  let e = create 32 7 "notes" "let x = 1" in
  print_string ("a file of no language: " ^ string_of_int (List.length (faces e)) ^ " lines of faces"); print_newline ()

let () =
  let text = String.concat "\n" (List.init 9 (fun i -> if i = 2 then "(* open" else if i = 6 then "closed *) let" else "let " ^ string_of_int i)) in
  let e = create 24 5 "b.ml" text in
  keys e "\022\022";
  show_faces "two screens down: the comment opened above the first line shown" e
