(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyBrowserAddress.mli *)
open TinyBrowserText

(*****************************************************************************)
(* Addresses *)
(*****************************************************************************)

(* an address and its #fragment, apart ("" when there is none) *)
let fragment url =
  match String.index_opt url '#' with
  | Some i ->
    String.sub url 0 i, String.sub url (i + 1) (String.length url - i - 1)
  | None -> url, ""

(* DuckDuckGo's page for text browsers: its results are plain HTML, no
 * script (as Lynx is given), each a link through a page that a <meta>
 * refresh sends on *)
let search_engine = "https://lite.duckduckgo.com/lite/?q="

(* the words of a search as a query: a space +, other than letters and
 * digits %XX *)
let query s =
  let hex = "0123456789ABCDEF" in
  let piece c =
    if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
       || (c >= '0' && c <= '9') || c = '-' || c = '.' || c = '_'
    then String.make 1 c
    else if c = ' ' then "+"
    else
      let n = Char.code c in
      "%" ^ String.make 1 hex.[n / 16] ^ String.make 1 hex.[n mod 16] in
  String.concat "" (List.init (String.length s) (fun i -> piece s.[i]))

(* What was typed, as a full address (the wire's other end's too:
 * TinyMachinePeer.www_address): a title is an English Wikipedia
 * article, a name with a dot is https://, ?words a search. *)
let absolute typed =
  let s = String.trim typed in
  if String.starts_with "http://" s || String.starts_with "https://" s then s
  else if String.length s > 1 && s.[0] = '?' then
    search_engine
    ^ query (String.trim (String.sub s 1 (String.length s - 1)))
  else begin
    let first =
      match String.index_opt s '/' with Some i -> String.sub s 0 i | None -> s in
    if String.contains first '.' && not (String.contains first ' ') then
      "https://" ^ s
    else
      "https://en.wikipedia.org/wiki/"
      ^ String.map (fun c -> if c = ' ' then '_' else c) s
  end

(* "https://host" of an address *)
let site url =
  match find url "://" 0 with
  | -1 -> ""
  | i ->
    (match String.index_from_opt url (i + 3) '/' with
     | Some j -> String.sub url 0 j
     | None -> url)

(* Where a link goes, from the page at [url] whose <base> is [base]
 * (Wikipedia's is //en.wikipedia.org/wiki/, and its links ./OCaml). *)
let resolve url base href =
  if href = "" then url
  else if String.starts_with "http://" href
          || String.starts_with "https://" href then href
  else if String.starts_with "//" href then "https:" ^ href
  else if href.[0] = '#' then fst (fragment url) ^ href
  else if href.[0] = '/' then site url ^ href
  else begin
    let dir =
      if base <> "" then
        (if String.starts_with "//" base then "https:" ^ base else base)
      else begin
        let u = fst (fragment url) in
        match String.rindex_opt u '/' with
        | Some i when i > String.length (site url) -> String.sub u 0 (i + 1)
        | _ -> site url ^ "/"
      end in
    dir ^ (if String.starts_with "./" href
           then String.sub href 2 (String.length href - 2) else href)
  end
