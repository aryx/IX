(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Tab.mli *)

(* a page left: its address, and where it was scrolled to *)
type entry = { at : string; scrolled_to : float }

type t = {
  width : float;
  about : string -> string option;
  page : Browser_page.t option;
  url : string;
  said : string;
  scroll : float;
  history : entry Browser_history.t;
  visited : string list;
  (* the style sheets had, by address ("": one that did not come) *)
  sheets : (string * string) list;
  focus : Dom.element option;
}

let empty (width : float) (about : string -> string option) : t =
  { width; about; page = None; url = ""; said = ""; scroll = 0.; history = Browser_history.empty; visited = []; sheets = []; focus = None }

let page (t : t) = t.page
let url (t : t) = t.url
let said (t : t) = t.said
let scroll (t : t) = t.scroll
let focus (t : t) = t.focus

let settings (t : t) : Browser_page.settings =
  {
    extensions = true; css = true; boxes = true; width = t.width; breaker = Html_layout.greedy;
    visited = (fun u -> List.mem u t.visited);
    picture = (fun _ -> None);
    sheet = (fun u -> List.assoc_opt u t.sheets);
  }

let height (t : t) : float = match t.page with Some p -> p.layout.height | None -> 0.

let scrolled (by : float) ~(visible : float) (t : t) : t =
  { t with scroll = Float.max 0. (Float.min (height t -. visible) (t.scroll +. by)) }

(*****************************************************************************)
(* Fetching *)
(*****************************************************************************)

(* an address's bytes: where the redirections led, the status, the
 * content type, the bytes *)
let fetch (caps : < Cap.network; Cap.open_in; .. >) (t : t) ~(post : (string * string) option) (address : string) :
    (string * int * string option * string, string) result =
  let starts p = Browser_url.starts_with p address in
  if starts "about:" then
    match t.about (String.sub address 6 (String.length address - 6)) with
    | Some html -> Ok (address, 200, Some "text/html", html)
    | None -> Error "no such page of the browser's own"
  else if starts "data:" then
    match Browser_url.data_url address with Some bytes -> Ok (address, 200, None, bytes) | None -> Error "a data: address that cannot be read"
  else if starts "http://" || starts "https://" then
    match Http_client.fetch caps ~post address with
    | Ok (url, (r : Http.response)) -> Ok (url, r.status, Http.header "Content-Type" r.headers, r.body)
    | Error why -> Error why
  else
    let file = if starts "file://" then String.sub address 7 (String.length address - 7) else address in
    let file = fst (Browser_url.split_query (fst (Browser_url.split_fragment file))) in
    if Sys.file_exists file && not (Sys.is_directory file) then
      let content_type = if String.ends_with ~suffix:".css" file then Some "text/css" else if String.ends_with ~suffix:".txt" file then Some "text/plain" else None in
      match FS.read caps (Fpath.v file) with
      (* (the address as it was asked, its query kept: a form's fields) *)
      | bytes -> Ok ((if starts "file://" then address else "file://" ^ address), 200, content_type, bytes)
      | exception Sys_error why -> Error why
    else Error (file ^ ": no such file")

(* the page's sheets not had yet fetched, and theirs, the page laid out
 * again with them: eight rounds at most (an @import four deep, and a
 * margin) *)
let rec with_sheets (caps : < Cap.network; Cap.open_in; .. >) (t : t) (p : Browser_page.t) (rounds : int) : t * Browser_page.t =
  let wanted = List.sort_uniq compare (List.filter (fun u -> not (List.mem_assoc u t.sheets)) (Browser_page.sheets_wanted (settings t) p)) in
  if wanted = [] || rounds = 0 then (t, p)
  else
    let had = List.map (fun u -> (u, match fetch caps t ~post:None u with Ok (_, status, _, bytes) when status < 400 -> bytes | _ -> "")) wanted in
    let t = { t with sheets = had @ t.sheets } in
    with_sheets caps t (Browser_page.laid_out (settings t) p) (rounds - 1)

let to_fragment (t : t) (fragment : string option) : t =
  match (t.page, fragment) with
  | Some p, Some name -> ( match Hit.anchor p.layout name with Some y -> { t with scroll = y } | None -> t)
  | _ -> t

(* the page at [address] shown, scrolled to [scroll] or to its
 * #fragment; the history is the caller's *)
let load (caps : < Cap.network; Cap.open_in; .. >) (t : t) ~(post : (string * string) option) ~(scroll : float) (address : string) : t =
  let plain, fragment = Browser_url.split_fragment address in
  let url, status, content_type, bytes =
    match fetch caps t ~post plain with
    | Ok r -> r
    | Error why -> (plain, 0, Some "text/html", Browser_page.error_html plain why)
  in
  let t = { t with focus = None; visited = (if List.mem url t.visited then t.visited else url :: t.visited) } in
  let p = Browser_page.read (settings t) url status content_type bytes in
  let t, p = with_sheets caps t p 8 in
  let said = if status = 0 then "Could not load the page" else Printf.sprintf "Document: Done (%d bytes)" (String.length bytes) in
  to_fragment { t with page = Some p; url = (match fragment with Some f -> url ^ "#" ^ f | None -> url); said; scroll } fragment

let here (t : t) : entry = { at = t.url; scrolled_to = t.scroll }

(* [address] is whole *)
let go_post (caps : < Cap.network; Cap.open_in; .. >) (t : t) ~(post : (string * string) option) (address : string) : t =
  let same_page = t.page <> None && post = None && fst (Browser_url.split_fragment address) = fst (Browser_url.split_fragment t.url) in
  let history = if t.page = None then t.history else Browser_history.visit (here t) t.history in
  if same_page && snd (Browser_url.split_fragment address) <> None then
    to_fragment { t with history; url = address } (snd (Browser_url.split_fragment address))
  else load caps { t with history } ~post ~scroll:0. address

let go (caps : < Cap.network; Cap.open_in; .. >) (t : t) (address : string) : t =
  go_post caps t ~post:None (if t.url = "" then address else Browser_url.resolve t.url address)

let visit (caps : < Cap.network; Cap.open_in; .. >) (t : t) (typed : string) : t =
  let a = String.trim typed in
  let whole = List.exists (fun p -> Browser_url.starts_with p a) [ "http://"; "https://"; "file://"; "about:"; "data:" ] || Sys.file_exists a in
  go_post caps t ~post:None (if whole then a else "http://" ^ a)

let back (caps : < Cap.network; Cap.open_in; .. >) (t : t) : t =
  match Browser_history.back (here t) t.history with
  | Some (e, history) -> load caps { t with history } ~post:None ~scroll:e.scrolled_to e.at
  | None -> { t with said = "No page before this one" }

let forward (caps : < Cap.network; Cap.open_in; .. >) (t : t) : t =
  match Browser_history.forward (here t) t.history with
  | Some (e, history) -> load caps { t with history } ~post:None ~scroll:e.scrolled_to e.at
  | None -> { t with said = "No page after this one" }

let reload (caps : < Cap.network; Cap.open_in; .. >) (t : t) : t =
  if t.url = "" then t else load caps { t with sheets = [] } ~post:None ~scroll:t.scroll t.url

(*****************************************************************************)
(* The mouse and the keys *)
(*****************************************************************************)

let link_at (t : t) ~(x : float) ~(y : float) : string option =
  match t.page with
  | Some p -> Option.map (Browser_url.resolve p.url) (Hit.link_at p.layout ~x ~y)
  | None -> None

(* what a form's control answered, done *)
let form (caps : < Cap.network; Cap.open_in; .. >) (t : t) (outcome : Browser_forms.outcome) : t =
  match outcome with
  | Browser_forms.Nothing -> t
  | Browser_forms.Focus e -> { t with focus = Some e }
  | Browser_forms.Unfocus -> { t with focus = None }
  | Browser_forms.Changed p -> { t with page = Some p }
  | Browser_forms.Submit { url; post; page } -> go_post caps { t with page = Some page } ~post (Browser_url.resolve t.url url)

let click (caps : < Cap.network; Cap.open_in; .. >) (t : t) ~(x : float) ~(y : float) : t =
  match t.page with
  | None -> t
  | Some p -> (
      match Hit.fragment_at p.layout ~x ~y with
      | Some { control = Some c; _ } -> form caps t (Browser_forms.click p c.element)
      | _ -> (
          let t = { t with focus = None } in
          match link_at t ~x ~y with Some address -> go caps t address | None -> t))

let typed (t : t) (text : string) : t =
  match (t.page, t.focus) with Some p, Some e -> { t with page = Some (Browser_forms.typed p e text) } | _ -> t

let key (caps : < Cap.network; Cap.open_in; .. >) (t : t) (name : string) : t =
  match (t.page, t.focus) with Some p, Some e -> form caps t (Browser_forms.key p e name) | _ -> t
