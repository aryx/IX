(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Tab.mli *)

(* a page left: its address, where it was scrolled to, and the page
 * itself if it was whole -- laid out, its scripts' engine, its bytes,
 * the width it was laid out at -- for Back and Forward to show it
 * again at once (browsers' back-forward cache, Opera's in 2003) *)
type kept = { shown : Browser_page.t; engine : Browser_script.t option; size : int; laid_at : float; seen : string list }
type entry = { at : string; scrolled_to : float; kept : kept option }

(* what is left to do, a piece a call of [step], in order: the page at
 * an address (with what a form posts, and where to scroll it), with
 * its sheets; a script's file; the page's scripts run, their files all
 * had; a picture; the page laid out with the pictures that came; a
 * request a script made (XMLHttpRequest, fetch), answered *)
type work =
  | Page of string * (string * string) option * float
  | Script_file of string
  | Run
  | Picture of string
  | Pictures_in
  | Request of Script_types.request

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
  (* the pictures had, by address *)
  pictures : (string * Browser_picture.t) list;
  (* the programs that show what the browser does not (those on the
   * PATH: Netscape's), and the one to run now: its rule, the address,
   * the document's bytes if they are what it is given *)
  helpers : Browser_helpers.rule list;
  job : (Browser_helpers.rule * string * string option) option;
  (* how much of the page the window shows, as scrolled was last told *)
  visible : float;
  todo : work list;
  (* do pages run their scripts? The page's, if it has them; their
   * files' texts, by address *)
  scripts : bool;
  script : Browser_script.t option;
  sources : (string * string) list;
  (* the page's bytes, for what is said when it is whole; or what is
   * said instead: that it did not come, what its alert() said *)
  bytes : int;
  note : string option;
  (* the cookies: what each request says back and each answer sets,
   * and what a page's script reads as document.cookie *)
  jar : Cookie_jar.t;
  (* the time, in ms since 1970, as [at] was last told: a page's Date
   * starts there *)
  epoch : float;
  (* a layout owed: the scripts changed the tree, and the page shown is
   * the one before; for how many frames (0: none owed) *)
  owed : int;
  (* the pieces done since the page was asked for: the status bar's
   * progress, with what is left *)
  taken : int;
}

let empty (width : float) (about : string -> string option) : t =
  { width; about; page = None; url = ""; said = ""; scroll = 0.; history = Browser_history.empty; visited = []; sheets = []; focus = None; pictures = []; helpers = []; job = None; visible = 700.; todo = []; scripts = true; script = None; sources = []; bytes = 0; note = None; jar = Cookie_jar.create []; epoch = 0.; owed = 0; taken = 0 }

let page (t : t) = t.page
let url (t : t) = match t.todo with Page (address, _, _) :: _ -> address | _ -> t.url
let busy (t : t) : bool = t.todo <> []
let pieces (t : t) : int * int = (t.taken, t.taken + List.length t.todo)
let with_scripts (scripts : bool) (t : t) : t = { t with scripts }
let with_jar (jar : Cookie_jar.t) (t : t) : t = { t with jar }
let with_helpers (helpers : Browser_helpers.rule list) (t : t) : t = { t with helpers }
let take_job (t : t) = (t.job, { t with job = None })
let at (epoch : float) (t : t) : t = if epoch = t.epoch then t else { t with epoch }
let console (t : t) : string list = match t.script with Some s -> Browser_script.console s | None -> []
let width (t : t) : float = t.width
let said (t : t) = t.said
let scroll (t : t) = t.scroll
let focus (t : t) = t.focus

let settings (t : t) : Browser_page.settings =
  {
    css = true; width = t.width;
    visited = (fun u -> List.exists (String.equal u) t.visited);
    picture = (fun u -> List.assoc_opt u t.pictures);
    sheet = (fun u -> List.assoc_opt u t.sheets);
  }

let height (t : t) : float = match t.page with Some p -> p.layout.height | None -> 0.

let scrolled (by : float) ~(visible : float) (t : t) : t =
  { t with visible; scroll = Float.max 0. (Float.min (height t -. visible) (t.scroll +. by)) }

(* another width: the page laid out again, kept within its new height *)
let resized (width : float) (t : t) : t =
  if width = t.width then t
  else
    let t = { t with width } in
    match t.page with
    | Some p -> scrolled 0. ~visible:t.visible { t with page = Some (Browser_page.laid_out (settings t) p) }
    | None -> t

(*****************************************************************************)
(* Fetching *)
(*****************************************************************************)

(* an address's bytes: where the redirections led, the status, the
 * content type, the bytes *)
(* opti: a page's files on the connection the last one used
 * (Keep_alive.mli, with the numbers); keep=off, a connection each *)
let keeps : bool ref = ref true

let fetch_any (caps : < Cap.network; Cap.open_in; .. >) (t : t) ~(post : (string * string) option) (address : string) :
    (string * int * string option * string, string) result =
  let starts p = Browser_url.starts_with p address in
  if starts "about:" then
    match t.about (String.sub address 6 (String.length address - 6)) with
    | Some html -> Ok (address, 200, Some "text/html", html)
    | None -> Error "no such page of the browser's own"
  else if starts "data:" then
    (* its type, the words before its "," or its first ";" (none: HTML, as before) *)
    let kind = String.sub address 5 (String.length address - 5) in
    let kind = List.hd (String.split_on_char ';' (List.hd (String.split_on_char ',' kind))) in
    match Browser_url.data_url address with
    | Some bytes -> Ok (address, 200, (if kind = "" then None else Some kind), bytes)
    | None -> Error "a data: address that cannot be read"
  else if starts "http://" || starts "https://" then
    (* old: Http_client.fetch caps ~post address *)
    match Http_client.fetch_with { said = []; keep = !keeps; jar = Some t.jar } caps ~post address with
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

(* and said, with -v: the address asked, what came *)
let fetch (caps : < Cap.network; Cap.open_in; .. >) (t : t) ~(post : (string * string) option) (address : string) :
    (string * int * string option * string, string) result =
  Logs.info (fun m -> m "%s %s" (if post = None then "GET" else "POST") address);
  let r = fetch_any caps t ~post address in
  (match r with
   | Ok (url, status, kind, body) -> Logs.info (fun m -> m "%d %s, %s, %d bytes" status url (match kind with Some k -> k | None -> "no type") (String.length body))
   | Error why -> Logs.info (fun m -> m "%s: %s" address why));
  r

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

(* the page's pictures not had yet, nor asked for -- its <img>s and
 * its boxes' background-images -- to fetch *)
let pictures_wanted (t : t) (p : Browser_page.t) : string list =
  let srcs = List.filter_map (fun (e : Dom.element) -> Option.map (Browser_url.resolve p.url) (Box_layout.picture_src e)) (Dom.find_all "img" p.tree) in
  let asked = List.filter_map (fun w -> match w with Picture u -> Some u | _ -> None) t.todo in
  List.sort_uniq compare
    (List.filter (fun u -> (not (List.mem_assoc u t.pictures)) && not (List.mem u asked)) (srcs @ p.backgrounds))

(* what the status bar says of what is left *)
let progress (t : t) : t =
  let count f = List.length (List.filter f t.todo) in
  let said =
    match t.todo with
    | [] -> ( match t.note with Some note -> note | None -> Printf.sprintf "Document: Done (%d bytes)" t.bytes)
    | Page (address, _, _) :: _ -> "Loading " ^ fst (Browser_url.split_fragment address) ^ " ..."
    | Script_file _ :: _ -> Printf.sprintf "Loading scripts: %d left" (count (fun w -> match w with Script_file _ -> true | _ -> false))
    | Run :: _ -> "Running the page's scripts"
    | (Picture _ | Pictures_in) :: _ -> Printf.sprintf "Loading pictures: %d left" (count (fun w -> match w with Picture _ -> true | _ -> false))
    | Request r :: _ -> "Loading " ^ r.url ^ " ..."
  in
  { t with said }

(* the pictures the page now asks for, at the end of what is left, and
 * the layout after them *)
let with_pictures (t : t) : t =
  match t.page with
  | None -> t
  | Some p -> (
      match pictures_wanted t p with
      | [] -> t
      | wanted -> { t with todo = List.filter (fun w -> w <> Pictures_in) t.todo @ List.map (fun u -> Picture u) wanted @ [ Pictures_in ] })

(* where an element is in its tree: the indexes of the elements down to
 * it -- how the field in focus is found again in a tree a script froze
 * anew (mini-chrome's Browser_tab's) *)
let rec path_to (root : Dom.element) (e : Dom.element) : int list option =
  if root == e then Some []
  else
    let children = List.filter_map (fun (n : Dom.node) -> match n with Dom.Element c -> Some c | Dom.Text _ -> None) root.children in
    List.find_map (fun (i, c) -> Option.map (fun p -> i :: p) (path_to c e)) (List.mapi (fun i c -> (i, c)) children)

let rec at_path (root : Dom.element) (path : int list) : Dom.element option =
  match path with
  | [] -> Some root
  | i :: rest -> (
      let children = List.filter_map (fun (n : Dom.node) -> match n with Dom.Element c -> Some c | Dom.Text _ -> None) root.children in
      match List.nth_opt children i with Some c -> at_path c rest | None -> None)

(* the page at [address] asked for: [step] fetches it; what was left of
 * the page before is dropped *)
let ask (t : t) ~(post : (string * string) option) ~(scroll : float) (address : string) : t = progress { t with todo = [ Page (address, post, scroll) ]; taken = 0 }

(* opti: a layout the scripts' change of the tree asks for is owed, and
 * made once ([settle]) when the page's work is done, or after half a
 * second of frames, and before a click is looked at -- not at each
 * task (mini-chrome's Browser_tab.settle). The Wikipedia article:
 * its scripts run in 1.2 s, and the page was styled and laid out 15
 * times for them, 0.6 s each; settle=off is that way again *)
let settles : bool ref = ref true

(* the page laid out again from the scripts' tree, and the pictures it
 * now asks for; the field in focus found again in that tree *)
let relaid (t : t) : t =
  match (t.page, t.script) with
  | Some p, Some s ->
      let tree = Browser_script.tree s in
      let focus = match t.focus with Some e -> Option.bind (path_to p.tree e) (at_path tree) | None -> None in
      with_pictures { t with page = Some (Browser_page.with_tree (settings t) p tree); focus; owed = 0 }
  | _ -> { t with owed = 0 }

let settle (t : t) : t = if t.owed > 0 then relaid t else t

(* after a task of the page's scripts (those of its load, an event's
 * handlers, a timer's function, a request's answer): what alert said;
 * the requests they made, to answer; if the tree changed, the page
 * laid out again from it, once, and the pictures it now asks for; a
 * page they went to (location = ...), or a form they sent, asked for
 * (mini-chrome's Browser_tab.after_task) *)
let after_task (t : t) : t =
  match (t.page, t.script) with
  | Some _, Some s -> (
      let t = match List.rev (Browser_script.take_alerts s) with message :: _ -> { t with note = Some ("Alert: " ^ message) } | [] -> t in
      ignore (Browser_script.take_address s);
      let t = { t with todo = t.todo @ List.map (fun r -> Request r) (Browser_script.take_requests s) } in
      let t =
        if not (Browser_script.changed s) then t
        else if !settles then { t with owed = max 1 t.owed }
        else relaid t
      in
      let here = fst (Browser_url.split_fragment t.url) in
      match (Browser_script.take_submission s, Browser_script.take_navigation s) with
      | Some (url, post), _ -> ask t ~post ~scroll:0. (Browser_url.resolve here url)
      | None, Some (url, _) when fst (Browser_url.split_fragment (Browser_url.resolve here url)) <> here -> ask t ~post:None ~scroll:0. (Browser_url.resolve here url)
      | _ -> t)
  | _ -> t

(* the page's scripts run, their files all had (one that did not come
 * is said in the console) *)
let run_scripts (t : t) : t =
  match (t.script, t.page) with
  | Some s, Some _ ->
      Browser_script.run_scripts_with (fun u -> match List.assoc_opt u t.sources with Some "" | None -> None | Some text -> Some text) s;
      (* (laid out from the scripts' tree even if they left it as it
       * was: a click is told to them by an element of that tree)
       * old: with_tree here, then again in after_task if they changed it *)
      let t = after_task t in
      if !settles then { t with owed = max 1 t.owed } else with_pictures (relaid t)
  | _ -> with_pictures t

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
  (* a PDF file, whatever its type is said to be (a file's has none) *)
  let content_type = if String.starts_with ~prefix:"%PDF-" bytes then Some "application/pdf" else content_type in
  (* what is not shown here, given to its program if there is one: the
   * page says so (Browser_helpers) *)
  let kind = Browser_page.media_type content_type in
  let shown = kind = "" || kind = "text/html" || String.starts_with ~prefix:"text/" kind in
  let job = if shown || status = 0 then None else Option.map (fun r -> (r, url, Some bytes)) (Browser_helpers.for_type t.helpers kind) in
  let html =
    match job with
    | Some (r, _, _) ->
        let name = Filename.basename (fst (Browser_url.split_fragment url)) in
        Printf.sprintf "<title>%s</title><h1>%s</h1><p>A document of type <code>%s</code>, %d bytes, given to <b>%s</b>." name name kind (String.length bytes) (Browser_helpers.name r)
    | None -> bytes
  in
  let content_type = if job <> None then Some "text/html" else content_type in
  let t = { t with job; focus = None; pictures = []; script = None; note = None; visited = (if List.mem url t.visited then t.visited else url :: t.visited) } in
  let p = Browser_page.read (settings t) url status content_type html in
  let t, p = with_sheets caps t p 8 in
  let t = (to_fragment { t with page = Some p; url = (match fragment with Some f -> url ^ "#" ^ f | None -> url); scroll; bytes = String.length bytes } fragment) in
  if status = 0 then { t with todo = []; note = Some "Could not load the page" }
  else if not t.scripts then with_pictures t
  else
    (* its scripts of their own file fetched first, then all run in
     * order; the page shown meanwhile, as it came *)
    (* document.cookie: the jar's for the page's address, but the HttpOnly ones *)
    let cookies =
      match Url.parse p.url with
      | Ok (u : Url.t) when u.authority <> None -> ((fun () -> Cookie_jar.script_cookies t.jar u), fun (value : string) -> Cookie_jar.set_from_script t.jar u value)
      | _ -> Browser_script.defaults.cookies
    in
    let s = Browser_script.create_with { Browser_script.defaults with base = p.url; viewport = (t.width, t.visible); epoch = t.epoch; cookies } p.tree in
    let t = { t with script = Some s } in
    let missing = List.filter (fun u -> not (List.mem_assoc u t.sources)) (Browser_script.script_sources s) in
    { t with todo = List.map (fun u -> Script_file u) missing @ [ Run ] }

(* a piece of what is left done *)
let step (caps : < Cap.network; Cap.open_in; .. >) (t : t) : t =
  let had u = match fetch caps t ~post:None u with Ok (_, status, _, bytes) when status < 400 -> Some bytes | _ -> None in
  match t.todo with
  | [] -> t
  | work :: rest ->
      let t = { t with todo = rest; taken = t.taken + 1 } in
      (* (the page's work done: the layout owed, if one is) *)
      (fun (t : t) -> if t.todo = [] && t.owed > 0 then progress (settle t) else t)
      @@ progress
        (match work with
        | Page (address, post, scroll) -> load caps { t with todo = [] } ~post ~scroll address
        | Script_file u -> { t with sources = (u, match had u with Some text -> text | None -> "") :: t.sources }
        | Run -> run_scripts t
        | Picture u -> { t with pictures = (u, match had u with Some bytes -> Browser_picture.decode bytes | None -> Browser_picture.Broken) :: t.pictures }
        (* a picture has its size only when it has come: the page laid
         * out again with them all, once (in mini-chrome they come four
         * at a time and the page is laid out at each) *)
        | Pictures_in -> ( match t.page with Some _ when t.owed > 0 -> relaid t | Some p -> { t with page = Some (Browser_page.laid_out (settings t) p) } | None -> t)
        | Request r -> (
            match t.script with
            | None -> t
            | Some s ->
                let answer : (Script_types.answer, string) result =
                  match fetch caps t ~post:r.post r.url with
                  | Ok (final, status, content_type, body) ->
                      Ok { status; headers = (match content_type with Some c -> [ ("Content-Type", c) ] | None -> []); body; final }
                  | Error why -> Error why
                in
                Browser_script.answer s r.rid answer;
                after_task t))

(* [r], a piece done on a copy of the tab (Netscape's worker), with
 * what the window did to its own copy meanwhile: its width and its
 * clock, and where it is scrolled if the page is the same *)
let merged ~(window : t) (r : t) : t =
  let r = resized window.width { r with epoch = window.epoch; visible = window.visible } in
  if r.url = window.url then scrolled 0. ~visible:window.visible { r with scroll = window.scroll } else r

let here (t : t) : entry =
  let kept = match t.page with Some p when t.todo = [] -> Some { shown = p; engine = t.script; size = t.bytes; laid_at = t.width; seen = t.visited } | _ -> None in
  { at = t.url; scrolled_to = t.scroll; kept }

(* the pages kept: the three nearest each way (one of Wikipedia's,
 * with its scripts, is tens of megabytes), and of them only while
 * their bytes together, behind then ahead, the nearest first, are no
 * more than [kept_bytes]. A page alive is some 40 times its HTML:
 * Hacker News's comments, 1.3 MB, are 57.6 MB under mini-ml, most of
 * mini-9pi's heap; Back to one asks for it again.
 * old: the three nearest each way, whatever their size *)
let kept_bytes = 1_000_000

let trimmed (h : entry Browser_history.t) : entry Browser_history.t =
  let used = ref 0 in
  let near =
    List.mapi (fun i (e : entry) ->
        match e.kept with
        | Some k when i < 3 && !used + k.size <= kept_bytes -> used := !used + k.size; e
        | _ -> { e with kept = None })
  in
  let behind = near h.behind in
  { behind; ahead = near h.ahead }

(* the page of an entry shown again: as it was left if it was kept,
 * else asked for *)
let returned (t : t) (e : entry) (history : entry Browser_history.t) : t =
  let history = trimmed history in
  match e.kept with
  | Some k ->
      (* laid out again at another width, or if a link of it was
       * followed since (:visited, its color) *)
      let since = List.filter (fun u -> not (List.mem u k.seen)) t.visited in
      let followed = List.exists (fun (a : Dom.element) -> match Dom.attribute "href" a with Some h -> List.mem (Browser_url.resolve k.shown.url h) since | None -> false) (Dom.find_all "a" k.shown.tree) in
      let p = if k.laid_at = t.width && not followed then k.shown else Browser_page.laid_out (settings t) k.shown in
      progress { t with history; page = Some p; script = k.engine; url = e.at; scroll = e.scrolled_to; bytes = k.size; todo = []; focus = None; note = None; owed = 0 }
  | None -> ask { t with history } ~post:None ~scroll:e.scrolled_to e.at

(* [address] is whole *)
let go_post (t : t) ~(post : (string * string) option) (address : string) : t =
  let same_page = t.page <> None && post = None && fst (Browser_url.split_fragment address) = fst (Browser_url.split_fragment t.url) in
  let history = if t.page = None then t.history else trimmed (Browser_history.visit (here t) t.history) in
  if same_page && snd (Browser_url.split_fragment address) <> None then
    to_fragment { t with history; url = address } (snd (Browser_url.split_fragment address))
  else ask { t with history } ~post ~scroll:0. address

let go (t : t) (address : string) : t =
  go_post t ~post:None (if t.url = "" then address else Browser_url.resolve t.url address)

let visit (t : t) (typed : string) : t =
  let a = String.trim typed in
  let whole = List.exists (fun p -> Browser_url.starts_with p a) [ "http://"; "https://"; "file://"; "about:"; "data:" ] || Sys.file_exists a in
  go_post t ~post:None (if whole then a else "http://" ^ a)

let back (t : t) : t =
  match Browser_history.back (here t) t.history with
  | Some (e, history) -> returned t e history
  | None -> { t with said = "No page before this one" }

let forward (t : t) : t =
  match Browser_history.forward (here t) t.history with
  | Some (e, history) -> returned t e history
  | None -> { t with said = "No page after this one" }

let reload (t : t) : t =
  if t.url = "" then t else ask { t with sheets = []; sources = [] } ~post:None ~scroll:t.scroll t.url

(* (what Netscape said then) *)
let stop (t : t) : t = if t.todo = [] then t else progress (settle { t with todo = []; note = Some "Transfer interrupted!" })

(*****************************************************************************)
(* The mouse and the keys *)
(*****************************************************************************)

let link_at (t : t) ~(x : float) ~(y : float) : string option =
  match t.page with
  | Some p -> Option.map (Browser_url.resolve p.url) (Hit.link_at p.layout ~x ~y)
  | None -> None

type under = Nothing | Link of string | Field | Button

let under (t : t) ~(x : float) ~(y : float) : under =
  match t.page with
  | None -> Nothing
  | Some p -> (
      match Hit.fragment_at p.layout ~x ~y with
      | Some { control = Some c; _ } -> (
          let kind = List.find_map (fun (f : Forms.form) -> List.find_map (fun (k : Forms.control) -> if k.element == c.element then Some k.kind else None) f.controls) p.forms in
          match kind with Some (Forms.Text | Forms.Password | Forms.Textarea) -> Field | Some _ -> Button | None -> Nothing)
      | _ -> ( match link_at t ~x ~y with Some address -> Link address | None -> Nothing))

(* what a form's control answered, done *)
let form (t : t) (outcome : Browser_forms.outcome) : t =
  match outcome with
  | Browser_forms.Nothing -> t
  | Browser_forms.Focus e -> { t with focus = Some e }
  | Browser_forms.Unfocus -> { t with focus = None }
  | Browser_forms.Changed p -> (
      let t = { t with page = Some p } in
      (* the script told: the field's text in its value=, its input event *)
      match (t.script, t.focus) with
      | Some s, Some e ->
          Browser_script.input s e (Browser_page.value_of p e).text;
          progress (settle (after_task t))
      | _ -> t)
  | Browser_forms.Submit { url; post; page } -> go_post { t with page = Some page } ~post (Browser_url.resolve t.url url)

(* the page's scripts first (the element under the pointer, its click
 * bubbling); then, unless one prevented it, the browser's own: a
 * control, a link *)
let click (t : t) ~(x : float) ~(y : float) : t =
  (* (what is clicked is looked for in the page as its scripts left it) *)
  let t = settle t in
  match t.page with
  | None -> t
  | Some p -> (
      let control = match Hit.fragment_at p.layout ~x ~y with Some { control = Some c; _ } -> Some c.element | _ -> None in
      let link = link_at t ~x ~y in
      (* (between two words of a link the click is the link's, as it is
       * for the browser, Hit.link_at: the word before is looked for) *)
      let under =
        match link with
        | Some _ -> (
            match List.find_map (fun back -> Hit.fragment_at p.layout ~x:(x -. back) ~y) [ 0.; 3.; 6.; 9.; 12.; 15. ] with
            | Some f -> Some f.element
            | None -> Hit.element_at p.layout ~x ~y)
        | None -> Hit.element_at p.layout ~x ~y
      in
      let prevented = match (t.script, under) with Some s, Some e -> Browser_script.click s e | _ -> false in
      let t = progress (settle (after_task t)) in
      if prevented then t
      else
        match (control, link, t.page) with
        | Some e, _, Some p -> form t (Browser_forms.click p e)
        | None, Some address, _ -> (
            (* a link to what a program shows (a film of YouTube's to
             * mpv): run beside, the page staying (Browser_helpers) *)
            let whole = Browser_url.resolve t.url address in
            match Browser_helpers.for_url t.helpers whole with
            | Some r -> { t with focus = None; job = Some (r, whole, None); said = Browser_helpers.name r ^ ": " ^ whole }
            | None -> go { t with focus = None } address)
        | _ -> { t with focus = None })

(* the page's clock moved on by [ms]: its timers due run; not while
 * the page or its scripts are still on their way *)
let advance (ms : float) (t : t) : t =
  let loading = List.exists (fun w -> match w with Page _ | Script_file _ | Run -> true | _ -> false) t.todo in
  match t.script with
  | Some s when not loading ->
      Browser_script.advance s ms;
      let was = t.todo in
      let t = after_task t in
      (* the layout owed: now if nothing else is on its way, or it has
       * been half a second (a page that never rests) *)
      let t = if t.owed = 0 then t else if t.todo = [] || t.owed > 30 then settle t else { t with owed = t.owed + 1 } in
      if t.todo == was && t.note = None then t else progress t
  | _ -> t

let typed (t : t) (text : string) : t =
  match (t.page, t.focus) with Some p, Some e -> { t with page = Some (Browser_forms.typed p e text) } | _ -> t

let key (t : t) (name : string) : t =
  match (t.page, t.focus) with Some p, Some e -> form t (Browser_forms.key p e name) | _ -> t
