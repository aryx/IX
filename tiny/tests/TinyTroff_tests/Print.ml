(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyTroff's test (TinyTroff_test.sh): a page of the four kinds and a
 * Markdown file, each printed as text, 40 columns, as HTML and as PDF. The
 * same file is built by OCaml and by tiny-ml for tiny-cpu: the same
 * lines. *)
open TinyTroff

let page = String.concat "\n" [
  "\\box[10 40 300 100]{";
  "# A **report**";
  "";
  "Some *slanted*, ***both***, \\u{under} and plain words, more than a line holds, <and> & \"quoted\".";
  "}";
  "";
  "\\box[10 150 170 86 budget]{";
  "| a    | b      |";
  "|------|--------|";
  "| Rent | 500    |";
  "| Food | 300    |";
  "|      | =b1+b2 |";
  "| Odd  | =1/0   |";
  "}";
  "";
  "\\box[200 150 200 90]{";
  "```drawing";
  "box 8 8 64 24 cpu";
  "arrow 72 20 136 56";
  "box 104 56 64 24 mem";
  "text 8 64 a note";
  "```";
  "}";
  "";
  "\\box[10 250 200 120]{";
  "```chart";
  "bars budget b1:b3 a1:a3";
  "```";
  "}";
  "";
  "\\box[220 250 120 60]{";
  "```chart";
  "bars nosuch b1:b2";
  "```";
  "}";
  "";
  "\\box[320 40 60 40]{";
  "```paint";
  "..kk";
  ".rrrr";
  "";
  "bbg";
  "```";
  "}";
  "" ]

let () =
  print_string "== the page as text\n";
  print_string (to_text 40 page);
  print_string "== the page as HTML\n";
  print_string (to_html "report <1>" page);
  print_string "== the page as PDF\n";
  print_string (to_pdf page);
  print_string "== a Markdown file as text\n";
  print_string (to_text 40 "# Notes\n\nA *Markdown* file, with no box.\n")
