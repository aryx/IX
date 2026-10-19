(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Places.mli *)

type place = { url : string; title : string }
type t = { history : place list; bookmarks : place list }

let empty : t = { history = []; bookmarks = [] }

let visited (t : t) (p : place) : t =
  { t with history = List.filteri (fun i _ -> i < 1000) (p :: List.filter (fun (q : place) -> q.url <> p.url) t.history) }

let bookmarked (t : t) (p : place) : t =
  if List.exists (fun (q : place) -> q.url = p.url) t.bookmarks then t else { t with bookmarks = t.bookmarks @ [ p ] }

(* a title on one line, a tab and a newline being the file's *)
let flat (s : string) : string = String.map (fun c -> if c = '\t' || c = '\n' || c = '\r' then ' ' else c) s

let history_to_string (t : t) : string = String.concat "" (List.map (fun p -> Printf.sprintf "%s\t%s\n" p.url (flat p.title)) t.history)

let history_of_string (s : string) : place list =
  List.filter_map
    (fun line -> match String.index_opt line '\t' with Some i -> Some { url = String.sub line 0 i; title = String.sub line (i + 1) (String.length line - i - 1) } | None -> if line = "" then None else Some { url = line; title = "" })
    (String.split_on_char '\n' s)

let escape (s : string) : string =
  let b = Buffer.create (String.length s) in
  String.iter (fun c -> Buffer.add_string b (match c with '<' -> "&lt;" | '>' -> "&gt;" | '&' -> "&amp;" | '"' -> "&quot;" | c -> String.make 1 c)) s;
  Buffer.contents b

let link (p : place) : string = Printf.sprintf "<A HREF=\"%s\">%s</A>" (escape p.url) (escape (if p.title = "" then p.url else p.title))

(* Netscape's file, as Firefox and Chrome still write it *)
let bookmarks_to_html (t : t) : string =
  "<!DOCTYPE NETSCAPE-Bookmark-file-1>\n<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">\n<TITLE>Bookmarks</TITLE>\n<H1>Bookmarks</H1>\n<DL><p>\n"
  ^ String.concat "" (List.map (fun p -> "    <DT>" ^ link p ^ "\n") t.bookmarks)
  ^ "</DL><p>\n"

(* each <A HREF="...">title</A>, in a file of any browser's *)
let bookmarks_of_html (s : string) : place list =
  List.filter_map
    (fun a -> Option.map (fun url -> { url; title = String.trim (Dom.text_content a) }) (Dom.attribute "href" a))
    (Dom.find_all "a" (Html_tree.of_string s))

let history_page (t : t) : string =
  "<!doctype html><title>History</title><h1>History</h1><ol>\n" ^ String.concat "" (List.map (fun p -> "<li>" ^ link p ^ "\n") t.history) ^ "</ol>"

let contains (s : string) (part : string) : bool =
  let s = String.lowercase_ascii s and part = String.lowercase_ascii part in
  let n = String.length part in
  let rec at i = i + n <= String.length s && (String.sub s i n = part || at (i + 1)) in
  at 0

let matches (t : t) (typed : string) : place list =
  if String.trim typed = "" then []
  else
    let all = List.filter (fun p -> contains p.url typed || contains p.title typed) (t.bookmarks @ t.history) in
    let once = List.fold_left (fun seen (p : place) -> if List.exists (fun (q : place) -> q.url = p.url) seen then seen else seen @ [ p ]) [] all in
    List.filteri (fun i _ -> i < 6) once

let destination (typed : string) : string =
  let s = String.trim typed in
  let words = String.contains s ' ' || not (String.contains s '.' || String.contains s ':' || String.contains s '/' || s = "localhost") in
  if words then "https://lite.duckduckgo.com/lite/?" ^ Urlencoded.encode [ ("q", s) ] else s
