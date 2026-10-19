(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's tests/layout/Unit_hit.ml, its first version (docs/plans/plan_browser.md) *)

(* See Unit_hit.mli *)

(* the tests' font: a character as wide as its look's size *)
let metrics (l : Looks.t) (s : string) : float = l.size *. float_of_int (String.length s)

(* the page laid out by the box model in a window [width] wide, the
 * root's font 10 (a line 12 high), as the lines and fragments Hit
 * reads *)
let page ?(width = 200.) (html : string) : Html_layout.box =
  let root = Html_tree.of_string html in
  let media : Cascade.media = { width; height = 600. } in
  let sheet : Cascade.sheet = { origin = Author; rules = Css_syntax.parse_stylesheet "html { font-size: 10px }" } in
  Box_layout.as_html_layout (Box_layout.layout metrics Html_layout.no_picture ~viewport:(width, 600.) (Computed.styles media [ sheet ] root) root)

let tests =
  Testo.categorize "Hit"
    [
      Testo.create "the worked example" (fun () ->
          (* the line 11.2..23.2 (the p's margin, 1.12 em, and the
           * body's collapsed into one): "the" 8..38, "recipes" 48..118 *)
          let p = page "<p>the <a href=recipes.html>recipes</a>" in
          Alcotest.(check (option string)) "on recipes" (Some "recipes.html") (Hit.link_at p ~x:60. ~y:15.);
          Alcotest.(check (option string)) "on the" None (Hit.link_at p ~x:20. ~y:15.);
          Alcotest.(check (option string)) "right of the line" None (Hit.link_at p ~x:150. ~y:15.);
          Alcotest.(check (option string)) "below it" None (Hit.link_at p ~x:60. ~y:30.));
      Testo.create "spaces: inside a link, not between two" (fun () ->
          (* "a" 8..18, "b" 28..38 (one link); "c" 48..58 (another) *)
          let p = page "<p><a href=u>a b</a> <a href=v>c</a>" in
          Alcotest.(check (option string)) "between a and b" (Some "u") (Hit.link_at p ~x:23. ~y:15.);
          Alcotest.(check (option string)) "between b and c" None (Hit.link_at p ~x:43. ~y:15.);
          Alcotest.(check (option string)) "on c" (Some "v") (Hit.link_at p ~x:50. ~y:15.));
      Testo.create "anchors: a name, an id, a block's id" (fun () ->
          let p = page "<p>a<p>b <a name=x>here</a><h2 id=y>t</h2><a name=top></a><p>c" in
          (* p1 11.2..23.2 (its margin and the body's collapsed); p2
           * 34.4..46.4; h2 (15, margin 0.83 em) 57.65..75.65; the empty
           * anchor at the next block's top, where its margin ends: 86.9 *)
          Alcotest.(check (option (float 1e-6))) "a name: its line's top" (Some 34.4) (Hit.anchor p "x");
          Alcotest.(check (option (float 1e-6))) "a block's id: the block's top" (Some 57.65) (Hit.anchor p "y");
          Alcotest.(check (option (float 1e-6))) "an anchor alone" (Some 86.9) (Hit.anchor p "top");
          Alcotest.(check (option (float 1e-6))) "none" None (Hit.anchor p "z"));
      Testo.create "the fragment under a point: a control" (fun () ->
          (* "Name:" 8..58, the field 68..136 *)
          let p = page ~width:400. "<form>Name: <input name=n size=10></form>" in
          let at x = Option.map (fun (f : Html_layout.fragment) -> (f.text, f.control <> None)) (Hit.fragment_at p ~x ~y:15.) in
          Alcotest.(check (option (pair string bool))) "on Name:" (Some ("Name:", false)) (at 20.);
          Alcotest.(check (option (pair string bool))) "on the field" (Some ("", true)) (at 100.);
          Alcotest.(check (option (pair string bool))) "in the space" None (at 63.));
      Testo.create "the element under a point: a word's, else its block" (fun () ->
          let p = page "<p>ab <span id=s>cd</span></p>" in
          let name x y = match Hit.element_at p ~x ~y with Some e -> e.name | None -> "none" in
          (* the line from 11.2, its baseline 20.2: "cd" at 38..58 *)
          Alcotest.(check string) "on cd: the span" "span" (name 45. 15.);
          Alcotest.(check string) "on ab: the p" "p" (name 15. 15.);
          Alcotest.(check string) "beside the words: the p still" "p" (name 150. 15.);
          Alcotest.(check string) "below the page: nothing" "none" (name 100. 400.));
      Testo.create "an anchor keeps the space around it" (fun () ->
          let p = page "a <a name=x></a>b" in
          Alcotest.(check (list (pair string (float 1e-6))))
            "a, then b a space later"
            [ ("a", 8.); ("b", 28.) ]
            (List.map (fun (f : Html_layout.fragment) -> (f.text, f.x)) (Html_layout.fragments p)));
    ]
