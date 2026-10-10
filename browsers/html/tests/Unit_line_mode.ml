(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's tests/html/Unit_line_mode.ml, its first version (docs/plans/plan_browser.md) *)

(* See Unit_line_mode.mli *)

let lines ?(width = 80) (html : string) : string list = (Line_mode.render width (Html_tree.of_string html)).lines

let check ?width (what : string) (html : string) (expected : string list) : unit =
  Alcotest.(check (list string)) what expected (lines ?width html)

let tests =
  Testo.categorize "Line_mode"
    [
      Testo.create "the worked example" (fun () ->
          let html =
            "<h1>Menu</h1>\n<p>Soup of the day. See the <a href=\"recipes.html\">recipes</a>\nor go back <a href=\"/\">home</a>."
          in
          let page = Line_mode.render 80 (Html_tree.of_string html) in
          Alcotest.(check (list string))
            "the lines"
            [ String.make 38 ' ' ^ "Menu"; ""; "Soup of the day. See the recipes[1] or go back home[2]." ]
            page.lines;
          Alcotest.(check (list string)) "the links" [ "recipes.html"; "/" ] page.links);
      Testo.create "greedy lines" (fun () ->
          check ~width:20 "Linebreak.mli's words" "<p>aaa bb cc ddddd ee ff gggg" [ "aaa bb cc ddddd ee"; "ff gggg" ];
          check ~width:5 "a long word on its own" "<p>a abcdefgh b" [ "a"; "abcdefgh"; "b" ];
          check "spaces and newlines are one space" "<p>a  \n\t b" [ "a b" ]);
      Testo.create "lists" (fun () ->
          check "bullets, numbers" "<ul><li>one<li>two</ul><ol><li>a<li>b</ol>"
            [ "  * one"; "  * two"; ""; "  1. a"; "  2. b" ];
          check ~width:12 "the next lines under the text" "<ul><li>aaa bbb ccc</ul>" [ "  * aaa bbb"; "    ccc" ];
          check "dl and blockquote" "<dl><dt>Term<dd>Definition</dl><blockquote>q</blockquote>"
            [ "Term"; "    Definition"; ""; "    q" ]);
      Testo.create "pre: its lines as they are" (fun () ->
          check "spaces kept" "<p>x<pre>\n  a  b\n c\n</pre>" [ "x"; ""; "  a  b"; " c" ]);
      Testo.create "images and rules" (fun () ->
          check "alt, else [IMAGE]" "<p><img alt=Logo> <img src=a.gif>" [ "Logo [IMAGE]" ];
          check ~width:10 "a rule" "<p>a<hr>b" [ "a"; ""; "----------"; "b" ]);
      Testo.create "not shown: the head, scripts, styles" (fun () ->
          check "only the body's text" "<title>T</title><style>p{}</style><script>x()</script><p>y" [ "y" ]);
    ]
