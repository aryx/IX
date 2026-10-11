(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's tests/layout/Unit_grid_layout.ml, as its add433e first had it (docs/plans/plan_browser.md) *)

(* See Unit_grid_layout.mli *)

let near = Alcotest.float 0.05
let sizes = Alcotest.(list near)

(* a rem is 16 *)
let ctx : Css_values.context = { em = 16.; rem = 16.; viewport_width = 1400.; viewport_height = 800. }
let tracks (css : string) : Css_grid.track array = Array.of_list (Css_grid.tracks ctx (Css_syntax.components_of css))
let nothing n = Array.make n { Grid_layout.least = 0.; most = 0. }
let content least most : Grid_layout.content = { least; most }

(* row, column, rows, columns *)
let cell (c : Grid_layout.cell) = (c.row, c.column, c.rows, c.columns)
let cells = Alcotest.(list (pair (pair int int) (pair int int)))
let as_pairs l = List.map (fun c -> let r, k, rs, ks = cell c in ((r, k), (rs, ks))) l

let wikipedia = [ [ "siteNotice"; "siteNotice" ]; [ "columnStart"; "pageContent" ]; [ "footer"; "footer" ] ]

let tests =
  Testo.categorize "Grid_layout"
    [
      Testo.create "Css_grid: the tracks read" (fun () ->
          let px n : Css_grid.breadth = Length { px = n; pct = 0. } in
          Alcotest.(check bool) "12.25rem minmax(0, 1fr)" true
            (tracks "12.25rem minmax(0, 1fr)" = [| { min = px 196.; max = px 196. }; { min = px 0.; max = Fr 1. } |]);
          Alcotest.(check bool) "1fr is auto at the least" true (tracks "1fr" = [| { min = Auto; max = Fr 1. } |]);
          Alcotest.(check bool) "min-content auto max-content" true
            (tracks "min-content auto max-content" = [| { min = Min_content; max = Min_content }; Css_grid.auto; { min = Max_content; max = Max_content } |]);
          Alcotest.(check int) "repeat(3, 1fr 20px): six" 6 (Array.length (tracks "repeat(3, 1fr 20px)"));
          Alcotest.(check bool) "a percentage" true (tracks "30%" = [| { min = Length { px = 0.; pct = 30. }; max = Length { px = 0.; pct = 30. } } |]);
          Alcotest.(check int) "a line's name is no track" 2 (Array.length (tracks "[start] 1fr [middle] 1fr [end]"));
          Alcotest.(check int) "none" 0 (Array.length (tracks "none")));
      Testo.create "Css_grid: the areas and grid-area read" (fun () ->
          Alcotest.(check (list (list string))) "a row a string" wikipedia
            (Css_grid.areas (Css_syntax.components_of "'siteNotice  siteNotice' 'columnStart pageContent' 'footer footer'"));
          let placed css = Css_grid.placement (Css_syntax.components_of css) in
          Alcotest.(check bool) "a name" true (placed "pageContent" = Area "pageContent");
          Alcotest.(check bool) "row / column" true (placed "2 / 1" = Cell { row = 2; column = 1 });
          Alcotest.(check bool) "auto" true (placed "auto" = Auto_placed));
      Testo.create "the worked example: an area's rectangle" (fun () ->
          let placed, rows, columns = Grid_layout.place ~rows:3 ~columns:2 ~areas:wikipedia [ Area "siteNotice"; Area "columnStart"; Area "pageContent"; Area "footer" ] in
          Alcotest.(check (pair int int)) "3 rows, 2 columns" (3, 2) (rows, columns);
          Alcotest.check cells "the notice across, the two columns, the footer across"
            [ ((0, 0), (1, 2)); ((1, 0), (1, 1)); ((1, 1), (1, 1)); ((2, 0), (1, 2)) ]
            (as_pairs placed));
      Testo.create "the next free cell, row by row; a row added; a name unknown" (fun () ->
          let placed, rows, columns = Grid_layout.place ~rows:0 ~columns:3 ~areas:[] [ Auto_placed; Cell { row = 1; column = 2 }; Auto_placed; Auto_placed; Area "nowhere" ] in
          Alcotest.(check (pair int int)) "2 rows of 3" (2, 3) (rows, columns);
          Alcotest.check cells "the cell said is skipped by the others"
            [ ((0, 0), (1, 1)); ((0, 1), (1, 1)); ((0, 2), (1, 1)); ((1, 0), (1, 1)); ((1, 1), (1, 1)) ]
            (as_pairs placed);
          let _, rows, columns = Grid_layout.place ~rows:0 ~columns:0 ~areas:[] [ Auto_placed; Auto_placed ] in
          Alcotest.(check (pair int int)) "no column said: one, a row an item" (2, 1) (rows, columns));
      Testo.create "the worked example: Wikipedia's columns" (fun () ->
          let page = tracks "12.25rem minmax(0, 1fr)" in
          Alcotest.check sizes "196, and the fr the rest" [ 196.; 1180. ]
            (Array.to_list (Grid_layout.sizes ~room:(Some 1400.) ~base:1400. ~gap:24. ~stretch:true page (nothing 2)));
          let body = tracks "minmax(0, 59.25rem) min-content" in
          Alcotest.check sizes "the article grows to its most, the empty column is nothing" [ 948.; 0. ]
            (Array.to_list (Grid_layout.sizes ~room:(Some 1180.) ~base:1180. ~gap:0. ~stretch:true body (nothing 2)));
          Alcotest.check sizes "in a narrow window, what there is" [ 500.; 0. ]
            (Array.to_list (Grid_layout.sizes ~room:(Some 500.) ~base:500. ~gap:0. ~stretch:true body (nothing 2))));
      Testo.create "fr tracks share the room; one keeps its content's width" (fun () ->
          let t = tracks "1fr 2fr" in
          Alcotest.check sizes "a third, two thirds" [ 100.; 200. ] (Array.to_list (Grid_layout.sizes ~room:(Some 300.) ~base:300. ~gap:0. ~stretch:true t (nothing 2)));
          Alcotest.check sizes "the first cannot be less than its longest word: the other has the rest" [ 180.; 120. ]
            (Array.to_list (Grid_layout.sizes ~room:(Some 300.) ~base:300. ~gap:0. ~stretch:true t [| content 180. 400.; content 0. 0. |])));
      Testo.create "auto tracks: their contents', then stretched (not when packed)" (fun () ->
          let t = tracks "auto auto" and cs = [| content 20. 50.; content 20. 100. |] in
          let sized room stretch = Array.to_list (Grid_layout.sizes ~room:(Some room) ~base:room ~gap:0. ~stretch t cs) in
          Alcotest.check sizes "room to spare, stretched" [ 125.; 175. ] (sized 300. true);
          Alcotest.check sizes "packed: their widest" [ 50.; 100. ] (sized 300. false);
          Alcotest.check sizes "too little room: grown equally from their narrowest" [ 50.; 50. ] (sized 100. true);
          Alcotest.check sizes "no room: their narrowest" [ 20.; 20. ] (sized 0. true));
      Testo.create "the rows: their contents' heights, with no room said" (fun () ->
          let t = tracks "min-content 1fr min-content" and cs = [| content 30. 30.; content 400. 400.; content 50. 50. |] in
          Alcotest.check sizes "each its items'" [ 30.; 400.; 50. ] (Array.to_list (Grid_layout.sizes ~room:None ~base:0. ~gap:0. ~stretch:true t cs));
          Alcotest.check sizes "in a height of 600, the fr has the rest" [ 30.; 520.; 50. ]
            (Array.to_list (Grid_layout.sizes ~room:(Some 600.) ~base:0. ~gap:0. ~stretch:true t cs)));
      Testo.create "an item spanning: what the others lack goes to the last" (fun () ->
          let t = tracks "auto auto" in
          let cs = Grid_layout.contents ~base:0. ~gap:10. t [ (0, 1, content 30. 30.); (0, 2, content 100. 100.) ] in
          Alcotest.check sizes "30, and 100 - 30 - 10" [ 30.; 60. ] (Array.to_list (Array.map (fun (c : Grid_layout.content) -> c.least) cs));
          let cs = Grid_layout.contents ~base:0. ~gap:0. (tracks "auto 1fr") [ (0, 2, content 100. 100.) ] in
          Alcotest.check sizes "not across an fr" [ 0.; 0. ] (Array.to_list (Array.map (fun (c : Grid_layout.content) -> c.least) cs)));
      Testo.create "the worked example: packed at the centre (example.com's place-content)" (fun () ->
          let starts align = Array.to_list (Grid_layout.starts ~align ~room:100. ~gap:4. [| 12.; 12. |]) in
          Alcotest.check sizes "the start" [ 0.; 16. ] (starts Start);
          Alcotest.check sizes "the centre: 72 left, half before" [ 36.; 52. ] (starts Center);
          Alcotest.check sizes "the end" [ 72.; 88. ] (starts End);
          Alcotest.check sizes "space-between" [ 0.; 88. ] (starts Space_between));
    ]
