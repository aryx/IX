(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's tests/browser/Unit_glyph_unicode.ml (docs/plans/plan_browser.md) *)

(* See Unit_glyph_unicode.mli *)

let width (s : string) : int = let g = Glyph_unicode.glyph s in g.right - g.left
let strokes (s : string) : int = List.length (Glyph_unicode.glyph s).strokes
let ascii (c : char) = Hershey.glyph c

(* the highest and the lowest point of a glyph's ink (y goes down) *)
let extent (s : string) : int * int =
  let ys = List.concat_map (List.map snd) (Glyph_unicode.glyph s).strokes in
  (List.fold_left min max_int ys, List.fold_left max min_int ys)

let tests =
  Testo.categorize "Glyph unicode"
    [
      Testo.create "the worked example" (fun () ->
          Alcotest.(check bool) "ASCII is Hershey's own" true (Glyph_unicode.glyph "A" = ascii 'A');
          Alcotest.(check (pair int int)) "é: as wide as e, one stroke more" (width "e", strokes "e" + 1) (width "é", strokes "é");
          Alcotest.(check int) "…: three dots wide" (3 * width ".") (width "…");
          Alcotest.(check (pair int bool)) "—: one stroke, twice a -" (1, true) (strokes "—", width "—" = 2 * width "-");
          Alcotest.(check (pair bool bool)) "Δ is not known: the ?" (false, true) (Glyph_unicode.known "Δ", Glyph_unicode.glyph "Δ" = ascii '?');
          Alcotest.(check bool) "bytes that are no character: the ?" true (Glyph_unicode.glyph "\xff\xfe" = ascii '?'));
      Testo.create "a mark's place: over a small letter, over a capital, under, across" (fun () ->
          let top s = fst (extent s) and bottom s = snd (extent s) in
          Alcotest.(check (list int)) "é above e's x-height, É above the capital's top, both letters' bottoms kept" [ -10; -17; bottom "e"; bottom "E" ]
            [ top "é"; top "É"; bottom "é"; bottom "É" ];
          Alcotest.(check bool) "a tall small letter takes its mark as a capital does" true (top "ď" = top "É");
          Alcotest.(check (pair int int)) "ç goes under the baseline; its top is c's" (top "c", 13) (top "ç", bottom "ç");
          Alcotest.(check (pair int int)) "ø: o and a stroke across; its width o's" (strokes "o" + 1, width "o") (strokes "ø", width "ø");
          Alcotest.(check (pair int int)) "an i with a mark has no dot: í is a stem and the acute; ı the stem alone" (2, 1) (strokes "í", strokes "ı"));
      Testo.create "the tables, letter by letter" (fun () ->
          (* each is its letter's width, and has more ink than it *)
          let same_as (base : char) (letters : string list) =
            List.iter
              (fun l ->
                Alcotest.(check bool) (l ^ " is known") true (Glyph_unicode.known l);
                Alcotest.(check (pair int bool)) (Printf.sprintf "%s is a %c with a mark" l base) (width (String.make 1 base), true) (width l, strokes l > 0 && Glyph_unicode.glyph l <> ascii base))
              letters
          in
          same_as 'a' [ "à"; "á"; "â"; "ã"; "ä"; "å"; "ā"; "ă"; "ą" ];
          same_as 'A' [ "À"; "Á"; "Â"; "Ã"; "Ä"; "Å"; "Ā"; "Ą" ];
          same_as 'e' [ "è"; "é"; "ê"; "ë"; "ē"; "ė"; "ę"; "ě" ];
          same_as 'c' [ "ç"; "ć"; "č"; "ĉ" ];
          same_as 'n' [ "ñ"; "ń"; "ň" ];
          same_as 'o' [ "ò"; "ó"; "ô"; "õ"; "ö"; "ø"; "ō"; "ő" ];
          same_as 'u' [ "ù"; "ú"; "û"; "ü"; "ū"; "ů"; "ű"; "ų" ];
          same_as 's' [ "ś"; "š"; "ş" ];
          same_as 'z' [ "ź"; "ż"; "ž" ];
          same_as 'l' [ "ł"; "ĺ"; "ľ" ];
          same_as 'L' [ "Ł" ];
          same_as 'g' [ "ğ" ];
          same_as 'r' [ "ř" ];
          same_as 'y' [ "ý"; "ÿ" ];
          same_as 'Y' [ "Ý"; "Ÿ" ];
          same_as 'Z' [ "Ž"; "Ż" ];
          same_as 'S' [ "Š" ];
          same_as 'I' [ "İ"; "Í" ]);
      Testo.create "what is read as ASCII, what takes no room, what is put together" (fun () ->
          let is (c : char) (l : string) = Glyph_unicode.glyph l = ascii c in
          Alcotest.(check (list bool)) "the curly quotes, the dashes, a no-break space, the times sign"
            [ true; true; true; true; true; true; true; true ]
            [ is '\'' "‘"; is '\'' "’"; is '"' "“"; is '"' "”"; is '-' "–"; is '-' "−"; is ' ' "\xc2\xa0"; is 'x' "×" ];
          Alcotest.(check (list int)) "the soft hyphen and the zero-width space take no room" [ 0; 0 ] [ width "\xc2\xad"; width "\xe2\x80\x8b" ];
          Alcotest.(check (list bool)) "ligatures and signs put together: narrower than their letters side by side, and known"
            [ true; true; true; true; true ]
            [ width "æ" < width "a" + width "e"; width "œ" < width "o" + width "e"; width "ß" < 2 * width "s"; Glyph_unicode.known "€"; Glyph_unicode.known "→" ];
          Alcotest.(check bool) "¿ is ? upside down: as wide, its ink lower" true (width "¿" = width "?" && snd (extent "¿") > snd (extent "?")));
    ]
