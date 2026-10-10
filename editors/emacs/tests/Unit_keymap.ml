(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Keymap.mli's examples, checked, and Frame's columns. *)

let t name f = Testo.create name (fun () -> f (); Testo.Promise.return ())
let str = Alcotest.(check string)
let int = Alcotest.(check int)

(* what a binding is, said: the command's mark left in [ran] *)
let ran = ref ""
let command (mark : string) : Efuns.action = fun (_ : Efuns.frame) -> ran := mark
let said (b : Efuns.binding option) : string =
  match b with
  | None -> "none"
  | Some (Efuns.Prefix _) -> "prefix"
  | Some (Efuns.Function f) -> f (Obj.magic 0); !ran

let tests = [
  t "keymap: a key's name from a terminal's bytes" (fun () ->
    List.iter (fun (bytes, name) -> str (String.escaped bytes) name (Keymap.of_bytes bytes))
      [ "a", "a"; " ", " "; "\xc3\xa9", "\xc3\xa9"; "\x18", "C-x"; "\x01", "C-a"; "\x00", "C-@"; "\x1f", "C-_";
        "\r", "RET"; "\t", "TAB"; "\x7f", "DEL"; "\x1b", "ESC"; "\x1bf", "M-f"; "\x1b<", "M-<"; "\x1b\x18", "M-C-x";
        "\x1b\x7f", "M-DEL"; "\x1b[A", "<up>"; "\x1b[6~", "<next>"; "\x1b[20~", "\x1b[20~" ]);
  t "keymap: a character, or not" (fun () ->
    List.iter (fun (key, is) -> Alcotest.(check bool) (String.escaped key) is (Keymap.is_char key))
      [ "a", true; " ", true; "<", true; "\xc3\xa9", true; "C-x", false; "RET", false; "DEL", false; "<up>", false;
        "M-f", false; "\x1b[20~", false; "", false ]);
  t "keymap: mli's example" (fun () ->
    let map = Keymap.create () in
    Keymap.add_binding map "C-x C-s" (command "save");
    Keymap.add_binding map "C-x 4 f" (command "other");
    Keymap.add_binding map "C-f" (command "forward");
    str "C-x" "prefix" (said (Keymap.get_binding map [ "C-x" ]));
    str "C-x C-s" "save" (said (Keymap.get_binding map [ "C-x"; "C-s" ]));
    str "C-x a" "none" (said (Keymap.get_binding map [ "C-x"; "a" ]));
    str "C-x 4" "prefix" (said (Keymap.get_binding map [ "C-x"; "4" ]));
    str "C-x 4 f" "other" (said (Keymap.get_binding map [ "C-x"; "4"; "f" ]));
    str "C-f" "forward" (said (Keymap.get_binding map [ "C-f" ]));
    str "C-f a: a command has no key after it" "none" (said (Keymap.get_binding map [ "C-f"; "a" ]));
    Keymap.add_binding map "C-f" (command "again");
    str "bound again" "again" (said (Keymap.get_binding map [ "C-f" ])));
  t "frame: columns, and characters" (fun () ->
    (*                     01 2   3 45 6 7  8 *)
    let tx = Text.create "a\tb\xc3\xa9\001c\nd" in
    Alcotest.(check (list int)) "column (4 is in the \xc3\xa9: as after it)" [ 0; 1; 8; 9; 10; 10; 12; 13; 0; 1 ] (List.init 10 (Frame.column tx));
    Alcotest.(check (list int)) "position_of_column: in a tab or a ^A, after it" [ 0; 1; 2; 2; 2; 3; 5; 6; 6; 7; 7 ]
      (List.map (Frame.position_of_column tx 0) [ 0; 1; 2; 5; 8; 9; 10; 11; 12; 13; 99 ]);
    Alcotest.(check (list int)) "next" [ 1; 2; 3; 5; 5; 6; 7; 8; 9; 9 ] (List.init 10 (Frame.next tx));
    Alcotest.(check (list int)) "prev" [ 0; 0; 1; 2; 3; 3; 5; 6; 7; 8 ] (List.init 10 (Frame.prev tx));
    int "no text" 0 (Frame.column (Text.create "") 0));
]
