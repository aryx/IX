(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The state of Latex, the reader of simple LaTeX (Latex.mli): what is
 * being read, what is being made, what was defined. Its parts each
 * take it: Latex_input reads the text, Latex_output writes the
 * document, Noweb, Latex_math and Latex_table read a chunk, a formula
 * and a table, Latex the commands. *)

(* What is being read: a file, a macro's text put in its place, an
 * argument read apart ([stop]: the reading ends with it). *)
type frame = { s : string; mutable i : int; stop : bool; file : string; mutable line : int; counts : bool }

type macro = { args : int; default : string option; body : string }

(* what a group gives back at its end *)
type look = { style : Doc.style; caps : bool; center : bool }

(* what is being made: the blocks, the last first, and the paragraph
 * being filled, its last piece first, with its footnotes and the
 * anchors met in it (a \label: put before it) *)
type out = { mutable blocks : Doc.block list; mutable line : Doc.inline list; mutable feet : Doc.block list; mutable marks : Doc.block list }

type env = {
  name : string;
  (* where its blocks go at its end, when it gathers them *)
  outer : out option;
  saved : look;
  (* a list: an item was begun, its tag, how many there were *)
  mutable started : bool;
  mutable tag : Doc.inline list;
  mutable count : int;
  mutable caption : Doc.inline list option;
  (* a defined one: the text of its end, to be read before it ends *)
  mutable after : string option;
}

(* What the first reading learns for the second: a reference is before
 * what it names, a table of contents before the chapters. *)
type known = {
  labels : (string, string) Hashtbl.t;
  (* a heading's level, its number, its title as written *)
  mutable toc : (int * string * string) list;
  (* a chunk's name: the chunks that define it, and those that use it *)
  defs : (string, int list) Hashtbl.t;
  uses : (string, int list) Hashtbl.t;
  (* the keys cited, the last first *)
  mutable cites : string list;
  bibitems : (string, string) Hashtbl.t;
}

type t = {
  (* the reading itself (Latex's): a text is read apart by it *)
  mutable run : t -> unit;
  paper : bool;
  load : string -> string option;
  known : known;
  (* the second reading: what is said is said, the tables are read *)
  final : bool;
  mutable input : frame list;
  mutable out : out;
  mutable look : look;
  mutable groups : look list;
  mutable envs : env list;
  macros : (string, macro) Hashtbl.t;
  flags : (string, bool) Hashtbl.t;
  environments : (string, macro * string) Hashtbl.t;
  (* the environments whose text is as it is written *)
  verbatims : (string, bool) Hashtbl.t;
  (* \begin{document} was read: text is the document's *)
  mutable body : bool;
  mutable said : (int * string) list;
  unknown : (string, bool) Hashtbl.t;
  (* a report: it has chapters *)
  report : bool;
  mutable appendix : bool;
  mutable chapter : int;
  mutable section : int;
  mutable subsection : int;
  mutable subsubsection : int;
  mutable figure : int;
  mutable table : int;
  mutable notes : int;
  mutable chunk : int;
  (* the entries of the table of contents so far: an anchor's name *)
  mutable entries : int;
  (* what a \label here names *)
  mutable here : string;
  mutable title : string;
  mutable author : string;
  mutable date : string;
  (* a table's cell being read: how many columns it goes across *)
  mutable span : int;
  mutable cell_align : Doc.align option;
}
