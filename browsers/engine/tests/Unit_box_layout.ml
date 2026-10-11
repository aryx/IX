(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's tests/layout/Unit_box_layout.ml, its first version (docs/plans/plan_browser.md) *)

(* See Unit_box_layout.mli *)

(* the tests' font: a character as wide as its look's size *)
let metrics (l : Looks.t) (s : string) : float = l.size *. float_of_int (String.length s)

(* the page laid out in a window [width] wide, the root's font 10 (a
 * line 12 high), [css] the page's sheet *)
let page ?(width = 200.) ?(css = "") (html : string) : Box_layout.box =
  let root = Html_tree.of_string html in
  let media : Cascade.media = { width; height = 600. } in
  let sheet : Cascade.sheet = { origin = Author; rules = Css_syntax.parse_stylesheet ("html { font-size: 10px } " ^ css) } in
  Box_layout.layout metrics Html_layout.no_picture ~viewport:(width, 600.) (Computed.styles media [ sheet ] root) root

(* the box of the element of id [id] *)
let rec find (id : string) (b : Box_layout.box) : Box_layout.box option =
  match b.element with
  | Some e when Dom.attribute "id" e = Some id -> Some b
  | _ -> List.find_map (find id) b.children

let box id p = match find id p with Some b -> b | None -> Alcotest.fail ("no box " ^ id)
let near = Alcotest.float 1e-6

(* x, y, width, height *)
let geometry (b : Box_layout.box) = [ b.x; b.y; b.width; b.height ]

(* the words, left to right *)
let words (b : Box_layout.box) : (string * float) list =
  List.filter_map (fun (f : Html_layout.fragment) -> if f.text = "" then None else Some (f.text, f.x)) (Box_layout.fragments b)
  |> List.stable_sort (fun (_, a) (_, b) -> compare a b)

let word = Alcotest.(pair string near)

let tests =
  Testo.categorize "Box_layout"
    [
      Testo.create "the worked example: auto margins centre" (fun () ->
          let p = page {|<body style="margin: 8px"><div id=d style="width: 100px; margin: 0 auto; padding: 5px; border: 2px solid">ab</div>|} in
          Alcotest.(check (list near)) "the div: x, y, width, height" [ 43.; 8.; 114.; 26. ] (geometry (box "d" p));
          Alcotest.(check (list word)) "its word, inside padding and border" [ ("ab", 50.) ] (words p));
      Testo.create "notes_css_engine.md's centring" (fun () ->
          let p = page ~width:976. {|<body style="margin: 0"><div id=d style="width: 400px; padding: 10px; border: 1px solid; margin: 0 auto">x</div>|} in
          let d = box "d" p in
          Alcotest.(check (list near)) "277 each side: x, width" [ 277.; 422. ] [ d.x; d.width ]);
      Testo.create "box-sizing: border-box" (fun () ->
          let p = page {|<div id=d style="box-sizing: border-box; width: 100px; padding: 10px">x</div>|} in
          Alcotest.check near "the border box is the width" 100. (box "d" p).width);
      Testo.create "margins collapse: through the body, between siblings" (fun () ->
          let p = page {|<body style="margin: 8px"><p id=a style="margin: 20px 0">a</p><p id=b style="margin: 10px 0">b</p>|} in
          Alcotest.check near "the body's 8 and the p's 20: 20" 20. (box "a" p).y;
          Alcotest.check near "the body starts there too" 20. (Option.get (find "a" p)).y;
          Alcotest.check near "20 between the two, not 30" (20. +. 12. +. 20.) (box "b" p).y);
      Testo.create "an empty block's margins are one" (fun () ->
          let p = page {|<body style="margin: 0"><p id=a style="margin: 0">a</p><div style="margin: 15px 0"></div><p id=b style="margin: 5px 0">b</p>|} in
          Alcotest.check near "15, once" (12. +. 15.) (box "b" p).y);
      Testo.create "a float: the lines beside it shortened" (fun () ->
          let p =
            page {|<body style="margin: 8px"><div id=f style="float: left; width: 40px; height: 30px"></div>aa bb cc|}
          in
          Alcotest.(check (list near)) "the float: x, y, width" [ 8.; 8.; 40. ] (let f = box "f" p in [ f.x; f.y; f.width ]);
          Alcotest.(check (list word)) "the words from its right" [ ("aa", 48.); ("bb", 78.); ("cc", 108.) ] (words p));
      Testo.create "clear: below the float" (fun () ->
          let p = page {|<body style="margin: 0"><div style="float: left; width: 40px; height: 30px"></div><div id=c style="clear: left">x</div>|} in
          Alcotest.check near "at the float's bottom" 30. (box "c" p).y);
      Testo.create "an inline-block: shrink-to-fit, in the line" (fun () ->
          let p = page {|<body style="margin: 0">a <span id=s style="display: inline-block; padding: 2px">bcd</span> e|} in
          let s = box "s" p in
          Alcotest.(check (list near)) "its width: its word and padding; x after 'a '" [ 34.; 20. ] [ s.width; s.x ];
          Alcotest.(check (list word)) "e after it" [ ("a", 0.); ("bcd", 22.); ("e", 64.) ] (words p));
      Testo.create "position: relative and absolute" (fun () ->
          let p =
            page
              {|<body style="margin: 0"><div id=r style="position: relative; top: 5px; margin-left: 10px"><div id=a style="position: absolute; left: 3px; top: 7px; width: 20px">x</div>y</div>|}
          in
          Alcotest.check near "relative: moved down 5" 5. (box "r" p).y;
          let a = box "a" p in
          Alcotest.(check (list near)) "absolute: in its positioned parent" [ 13.; 7.; 20. ] [ a.x; a.y; a.width ]);
      Testo.create "a list's markers" (fun () ->
          let p = page "<ol><li id=a>x<li id=b>y</ol><ul><li id=c>z</ul>" in
          Alcotest.(check (list bool))
            "2, then a bullet" [ true; true ]
            [ (box "b" p).marker = Some (Number 2); (box "c" p).marker = Some Bullet ]);
      Testo.create "a table: Table_layout's columns" (fun () ->
          let p = page {|<body style="margin: 8px"><table id=t><tr><td id=a>a<td id=b>bb</table>|} in
          let t = box "t" p in
          (* each cell its word and its 1 of padding each side: 12 and
           * 22; 2 of spacing around them *)
          Alcotest.(check (list near)) "the table: x, width" [ 8.; 2. +. 12. +. 2. +. 22. +. 2. ] [ t.x; t.width ];
          Alcotest.(check (list near)) "the cells' x" [ 10.; 24. ] [ (box "a" p).x; (box "b" p).x ];
          Alcotest.(check (list word)) "the words" [ ("a", 11.); ("bb", 25.) ] (words p));
      Testo.create "presentational hints: Hacker News' table" (fun () ->
          let p = page {|<body style="margin: 0"><table id=t width="50%" cellpadding=0 cellspacing=0><tr><td id=a bgcolor=ff6600>a</table>|} in
          let a = box "a" p in
          Alcotest.check near "width=50%" 100. (box "t" p).width;
          Alcotest.(check (list int)) "bgcolor=" [ 255; 102; 0 ] [ a.style.background.r; a.style.background.g; a.style.background.b ];
          Alcotest.(check (list word)) "no padding" [ ("a", 0.) ] (words p));
      Testo.create "an inline element's padding and background" (fun () ->
          let p = page {|<body style="margin: 0">a <span id=s style="padding: 0 5px; background: yellow">b</span> c|} in
          Alcotest.(check (list word)) "room made for its padding" [ ("a", 0.); ("b", 25.); ("c", 50.) ] (words p);
          let rec backdrops (b : Box_layout.box) = b.backdrops @ List.concat_map backdrops b.children in
          match backdrops p with
          | [ d ] -> Alcotest.(check (list near)) "its box: x, width, height" [ 20.; 20.; 10. ] [ d.x; d.width; d.height ]
          | _ -> Alcotest.fail "one box");
      Testo.create "srcset: its first address" (fun () ->
          Alcotest.(check (option string)) "no src" (Some "a.png")
            (Box_layout.picture_src (Dom.element_with [ ("srcset", "a.png 1x, b.png 2x") ] "img" [])));
      Testo.create "flex: a row, an auto margin" (fun () ->
          let p = page {|<body style="margin: 0"><div style="display: flex; width: 200px"><div id=a style="width: 50px">a</div><div id=b style="margin-left: auto">bb</div></div>|} in
          Alcotest.(check (list near)) "a: x, width" [ 0.; 50. ] (let a = box "a" p in [ a.x; a.width ]);
          Alcotest.(check (list near)) "b pushed right, shrunk to its word" [ 180.; 20. ] (let b = box "b" p in [ b.x; b.width ]));
      Testo.create "flex: grow" (fun () ->
          let p = page {|<body style="margin: 0"><div style="display: flex"><div id=a style="flex: 1">a</div><div id=b style="flex: 2">b</div></div>|} in
          Alcotest.(check (list near)) "a third, two thirds" [ 200. /. 3.; 400. /. 3. ] [ (box "a" p).width; (box "b" p).width ];
          Alcotest.check near "b after a" (200. /. 3.) (box "b" p).x);
      Testo.create "flex: align-items center, the row stretched" (fun () ->
          let p =
            page {|<body style="margin: 0"><div style="display: flex; height: 100px; align-items: center"><div id=a>a</div></div><div style="display: flex; height: 50px"><div id=s>s</div></div>|}
          in
          Alcotest.check near "centred: (100 - 12) / 2" 44. (box "a" p).y;
          Alcotest.check near "stretched to the row" 50. (box "s" p).height);
      Testo.create "flex: wrap, and a column with a gap" (fun () ->
          let p =
            page
              {|<body style="margin: 0"><div style="display: flex; flex-wrap: wrap; width: 100px"><div style="width: 40px">a</div><div style="width: 40px">b</div><div id=c style="width: 40px">c</div></div><div style="display: flex; flex-direction: column; row-gap: 5px"><div id=d>d</div><div id=e>e</div></div>|}
          in
          Alcotest.(check (list near)) "c on a second line" [ 0.; 12. ] (let c = box "c" p in [ c.x; c.y ]);
          Alcotest.check near "e below d and the gap" (24. +. 12. +. 5.) (box "e" p).y);
      Testo.create "grid: named areas, a column said and an fr, a row stretched (Wikipedia's shape)" (fun () ->
          let css =
            {|body { margin: 0 }
              #g { display: grid; column-gap: 10px; grid-template: min-content 1fr min-content / 50px minmax(0, 1fr);
                   grid-template-areas: 'top top' 'side main' 'foot foot' }
              #top { grid-area: top } #side { grid-area: side } #main { grid-area: main; height: 30px } #foot { grid-area: foot }|}
          in
          (* said in another order than they are placed *)
          let p = page ~css {|<div id=g><div id=main>m</div><div id=foot>f</div><div id=side>s</div><div id=top>t</div></div>|} in
          Alcotest.(check (list near)) "the top, across" [ 0.; 0.; 200.; 12. ] (geometry (box "top" p));
          Alcotest.(check (list near)) "the side column: 50 wide, as high as its row" [ 0.; 12.; 50.; 30. ] (geometry (box "side" p));
          Alcotest.(check (list near)) "the main one: the rest, past the gap" [ 60.; 12.; 140.; 30. ] (geometry (box "main" p));
          Alcotest.(check (list near)) "the foot, across, under them" [ 0.; 42.; 200.; 12. ] (geometry (box "foot" p));
          Alcotest.(check (list near)) "the grid: its rows' heights" [ 0.; 0.; 200.; 54. ] (geometry (box "g" p)));
      Testo.create "grid: the next free cell, three columns, gaps; a cell said" (fun () ->
          let css = {|body { margin: 0 } #g { display: grid; grid-template-columns: repeat(3, 1fr); gap: 4px 10px } #e { grid-area: 3 / 2 }|} in
          let p = page ~css {|<div id=g><div id=a>a</div><div id=b>b</div><div id=c>c</div><div id=d>d</div><div id=e>e</div></div>|} in
          Alcotest.(check (list near)) "a" [ 0.; 0.; 60.; 12. ] (geometry (box "a" p));
          Alcotest.(check (list near)) "b" [ 70.; 0.; 60.; 12. ] (geometry (box "b" p));
          Alcotest.(check (list near)) "c" [ 140.; 0.; 60.; 12. ] (geometry (box "c" p));
          Alcotest.(check (list near)) "d: the next row, past the row gap" [ 0.; 16.; 60.; 12. ] (geometry (box "d" p));
          Alcotest.(check (list near)) "e: the third row, the second column" [ 70.; 32.; 60.; 12. ] (geometry (box "e" p)));
      Testo.create "grid: place-content: center in a min-height (example.com's shape)" (fun () ->
          let css = {|body { margin: 0; min-height: 100px; display: grid; place-content: center; text-align: center }|} in
          let p = page ~css {|<body id=b><p id=p style="margin: 0">a line</p><a id=a href=/x>more</a>|} in
          Alcotest.(check (list near)) "the body: its min-height" [ 0.; 0.; 200.; 100. ] (geometry (box "b" p));
          Alcotest.(check (list near)) "the paragraph: 24 of content in 100, 38 above; the widest content, centred" [ 70.; 38.; 60.; 12. ] (geometry (box "p" p));
          Alcotest.(check (list near)) "the link, a block under it, as wide as the column" [ 70.; 50.; 60.; 12. ] (geometry (box "a" p)));
      Testo.create "grid: an item at its own width, centred down its row; text between items" (fun () ->
          let css = {|body { margin: 0 } #g { display: grid; grid-template-columns: 100px 100px; align-items: center } #a { width: 40px } #b { height: 40px }|} in
          let p = page ~css {|<div id=g><div id=a>a</div><div id=b>b</div>loose</div>|} in
          Alcotest.(check (list near)) "a: 40 wide, in the middle of the row's 40" [ 0.; 14.; 40.; 12. ] (geometry (box "a" p));
          Alcotest.(check (list near)) "b" [ 100.; 0.; 100.; 40. ] (geometry (box "b" p));
          Alcotest.(check (list (pair string near))) "the loose text: an item of its own, in the next row" [ ("a", 0.); ("b", 100.); ("loose", 0.) ]
            (List.sort compare (words (box "g" p))));
      Testo.create "a picture: its size, max-width" (fun () ->
          let p = page {|<body style="margin: 0"><img src=a.png width=400 height=100 style="max-width: 100%">|} in
          match List.filter_map (fun (f : Html_layout.fragment) -> Option.map (fun (pic : Html_layout.picture) -> (f.width, pic.height)) f.picture) (Box_layout.fragments p) with
          | [ (w, h) ] -> Alcotest.(check (list near)) "scaled to the page" [ 200.; 50. ] [ w; h ]
          | _ -> Alcotest.fail "one picture");
    ]
