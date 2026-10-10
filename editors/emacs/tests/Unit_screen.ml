(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Characters on a screen of cells (Utf8.width, Curses.put: a wide
 * character's two cells, a combining one's none), and the windows'
 * tree. *)

let t name f = Testo.create name (fun () -> f (); Testo.Promise.return ())
let str = Alcotest.(check string)

(* a row's cells, their glyphs between bars *)
let cells (screen : Curses.t) (n : int) : string =
  String.concat "|" (List.init n (fun (c : int) -> (Curses.cell screen 0 c).glyph))

(* a tree as text, a frame its buffer's name *)
let rec said (w : Efuns.window) : string =
  match w with
  | WFrame f -> f.frm_buffer.buf_name
  | HComb (a, b) -> "H(" ^ said a ^ "," ^ said b ^ ")"
  | VComb (a, b) -> "V(" ^ said a ^ "," ^ said b ^ ")"

let frame (name : string) : Efuns.frame = Frame.create (Obj.magic 0) (Ebuffer.make name None (Text.create ""))

let tests = [
  t "utf8: a character's width" (fun () ->
    List.iter (fun (what, c, w) -> Alcotest.(check int) what w (Utf8.width c))
      [ "a", 0x61, 1; "e acute", 0xE9, 1; "a combining acute", 0x301, 0; "alpha", 0x3B1, 1; "a Cyrillic letter", 0x436, 1;
        "a Chinese character", 0x4E2D, 2; "hiragana", 0x3042, 2; "a Korean syllable", 0xD55C, 2; "a full-width A", 0xFF21, 2;
        "an emoji", 0x1F600, 2; "a variation selector", 0xFE0F, 0; "a zero-width joiner", 0x200D, 0;
        "a box's line", 0x2500, 1; "an arrow", 0x2192, 1 ]);
  t "curses: a wide character has two cells, a combining one none" (fun () ->
    let put (s : string) : Curses.t = Curses.put ~attrs:Vt.plain 0 0 s (Curses.create ~rows:1 ~cols:6) in
    str "ascii" "a|b| | | | " (cells (put "ab") 6);
    str "wide: the second cell has no glyph" "a|\xe4\xb8\xad||b| | " (cells (put "a\xe4\xb8\xadb") 6);
    str "combining: in the cell before" "e\xcc\x81|b| | | | " (cells (put "e\xcc\x81b") 6);
    str "combining first: a cell of its own" "\xcc\x81|b| | | | " (cells (put "\xcc\x81b") 6);
    str "an emoji and its variation selector" "\xe2\x9d\xa4\xef\xb8\x8f|b| | | | " (cells (put "\xe2\x9d\xa4\xef\xb8\x8fb") 6);
    str "wide at the edge: not put" "a|b|c|d|e| " (cells (put "abcde\xe4\xb8\xad") 6);
    Alcotest.(check (list string)) "as text" [ "a\xe4\xb8\xadb" ] (Curses.text (put "a\xe4\xb8\xadb"));
    (* what is sent to a terminal that showed ab: from the second column, the wide character and b *)
    str "refresh" "\x1b[1;2H\xe4\xb8\xadb" (Curses.refresh ~before:(put "ab") (put "a\xe4\xb8\xadb")));
  t "top window: a host that paints when the model is another paints after a key, not after time" (fun () ->
    let top = Top_window.create (Obj.magic 0) 6 40 (Ebuffer.make "b" None (Text.create "one")) in
    let p = Top_window.program top in
    Keymap.add_global_key "C-f" (fun (f : Efuns.frame) -> Frame.goto f (Frame.point f + 1));
    let after_key = p.update (Tui.Key "\x06") p.init in
    Alcotest.(check bool) "a key: another model" true (after_key != p.init);
    Alcotest.(check (option (pair int int))) "and its screen is the new one: the cursor moved" (Some (0, 1)) (Curses.cursor_at (p.view after_key));
    Alcotest.(check bool) "a new size: another model" true (p.update (Tui.Resize (8, 50)) after_key != after_key);
    Alcotest.(check bool) "time: the same model" true (p.update (Tui.Tick 0.05) after_key == after_key));
  t "window: a frame's leaf replaced, taken out" (fun () ->
    let a = frame "a" and b = frame "b" and c = frame "c" in
    let w = Efuns.HComb (WFrame a, VComb (WFrame b, WFrame c)) in
    str "the tree" "H(a,V(b,c))" (said w);
    Alcotest.(check (list string)) "frames" [ "a"; "b"; "c" ] (List.map (fun (f : Efuns.frame) -> f.frm_buffer.buf_name) (Window.frames w));
    str "replace b" "H(a,V(V(b,a),c))" (said (Window.replace w b (VComb (WFrame b, WFrame a))));
    str "remove b: c has the place of both" "H(a,c)" (match Window.remove w b with Some w -> said w | None -> "none");
    str "remove a" "V(b,c)" (match Window.remove w a with Some w -> said w | None -> "none");
    str "remove the only one" "none" (match Window.remove (WFrame a) a with Some w -> said w | None -> "none");
    (match Window.remove (WFrame a) b with _ -> Alcotest.fail "no exception" | exception Not_found -> ());
    Window.place w 0 0 61 10;
    Alcotest.(check (list (list int))) "places: a half each, a column for the bar" [ [ 0; 0; 30; 10 ]; [ 31; 0; 30; 5 ]; [ 31; 5; 30; 5 ] ]
      (List.map (fun (f : Efuns.frame) -> [ f.frm_xpos; f.frm_ypos; f.frm_width; f.frm_height ]) [ a; b; c ]));
]
