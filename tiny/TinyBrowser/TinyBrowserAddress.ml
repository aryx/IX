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

(* What was typed, as a full address, by the rules of the wire's other
 * end (TinyMachinePeer.www_address), which this side needs to know too to
 * find where a relative link goes: a title is an English Wikipedia
 * article, a name with a dot is https://. *)
let absolute typed =
  let s = String.trim typed in
  if String.starts_with "http://" s || String.starts_with "https://" s then s
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
