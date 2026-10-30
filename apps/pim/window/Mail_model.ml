(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Mail_model.mli *)

type caps =
  < Cap.network ; Cap.open_in ; Cap.open_out ; Cap.readdir ; Cap.env ; Cap.exit >

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

(* what waits for the password *)
type action = Fetch | Open | Archive | Star of bool | Send | Snooze of Civil.date
type asking = Password | Search | Until | Due
type mode = Browsing | Reading | Composing | Asking of asking

type model = {
  account : string;
  server : Mail_sync.server;
  smtp : Mail_sync.server;
  mailbox : string; (* INBOX, All Mail, or the store's drafts *)
  (* the Screener (Screen): on or not, the Inbox's list shown, how many
   * wait in the Screener *)
  screening : bool;
  screen : Screen.place;
  waiting : int;
  (* Gmail's Unread: the Inbox's (the Imbox's) not read, a view of it;
   * how many *)
  unread : bool;
  unread_count : int;
  password : string option; (* kept while the window is open *)
  query : string; (* the search's words, "" for none *)
  conversations : Imap.summary list list;
  drafts : Mail_compose.draft list; (* the drafts mailbox's *)
  today : Civil.date; (* today= (the tests'), else the clock's *)
  selected : int;
  (* the conversation opened: its messages, oldest first, each its text
   * when the cache has it *)
  reading : (Imap.summary * string option) list;
  scroll : int; (* the first line of the conversation shown *)
  mode : mode;
  (* the message written: its fields, its text being edited, and the
   * mode its window goes back to *)
  draft : Mail_compose.draft;
  body : Text_edit.t;
  back_to : mode;
  field : string; (* what is typed after a question *)
  after : action option;
  (* what waits one frame, the status saying it first: the window draws
   * nothing while the server is asked *)
  soon : action option;
  status : string;
  held : string Set_.t; (* the keys down at the last frame *)
}

let store (caps : caps) : Items.t = Items.at (Items.place caps)

(* the drafts, a mailbox of the store's, not the server's *)
let drafts = "Drafts"

let contains (s : string) (word : string) : bool =
  let s = String.lowercase_ascii s and w = String.lowercase_ascii word in
  let n = String.length s and k = String.length w in
  let rec at i = i + k <= n && (String.sub s i k = w || at (i + 1)) in
  at 0

(* every word of the query in who sent one of its messages, or in its
 * subject *)
let matches (query : string) (c : Imap.summary list) : bool =
  List.for_all
    (fun w ->
      List.exists
        (fun (s : Imap.summary) ->
          contains (Conversations.who s.headers) w
          || contains (Conversations.header s.headers "subject") w)
        c)
    (List.filter (fun w -> w <> "") (String.split_on_char ' ' query))

(* the conversations again from the store, those back from a snooze on
 * top; the drafts *)
let load (caps : caps) (m : model) : model =
  let items = Items.all caps (store caps) in
  let l = Mail_item.listed items ~account:m.account ~mailbox:m.mailbox in
  let cs = List.filter (matches m.query) (Conversations.group l) in
  (* the Inbox's: the list asked of the Screener's, the screened out
   * in All Mail only *)
  let screening = Screen.since items <> None in
  let place = Screen.place items ~account:m.account in
  let waiting =
    if screening then
      List.length (List.filter (fun c -> place c = Screen.Screener) cs)
    else 0
  in
  let cs =
    if m.mailbox <> "INBOX" then cs
    else List.filter (fun c -> place c = m.screen) cs
  in
  let unread_count =
    if m.mailbox = "INBOX" && m.screen = Screen.Imbox then
      List.length (List.filter Conversations.unread cs)
    else m.unread_count
  in
  let cs =
    if m.mailbox = "INBOX" && m.unread then List.filter Conversations.unread cs
    else cs
  in
  let woke =
    List.filter_map
      (fun i -> if Item.field i "woke" <> "" then Some (Item.id i) else None)
      items
  in
  let back (c : Imap.summary list) =
    List.exists (fun s -> List.mem (Mail_item.id s) woke) c
  in
  let cs = List.filter back cs @ List.filter (fun c -> not (back c)) cs in
  let ds =
    List.map Mail_compose.of_item
      (List.filter (fun i -> Item.has_stamp i "draft") items)
  in
  let n = if m.mailbox = drafts then List.length ds else List.length cs in
  { m with conversations = cs; drafts = ds; screening; waiting; unread_count;
    selected = max 0 (min m.selected (n - 1)) }

let initial (caps : caps) (flags : Playground.flags) : model =
  let flag name =
    match List.assoc_opt name flags with Some v -> v | None -> ""
  in
  (* server=host:port, else Gmail's *)
  let server name (gmail : Mail_sync.server) : Mail_sync.server =
    let plain = List.mem_assoc "plain" flags in
    match String.rindex_opt (flag name) ':' with
    | Some i -> (
        let hp = flag name in
        match
          int_of_string_opt (String.sub hp (i + 1) (String.length hp - i - 1))
        with
        | Some port -> { Mail_sync.host = String.sub hp 0 i; port; plain }
        | None -> gmail)
    | None -> { gmail with plain }
  in
  (* the store's password file, if the author made one *)
  let password, status =
    match Mail_sync.saved_password caps with
    | Ok p -> (p, "")
    | Error e -> (None, e)
  in
  load caps
    {
      account = flag "user";
      server = server "server" Mail_sync.gmail;
      smtp = server "smtp" Mail_sync.gmail_smtp;
      mailbox = "INBOX";
      screening = false;
      screen = Screen.Imbox;
      waiting = 0;
      unread = false;
      unread_count = 0;
      password;
      query = "";
      conversations = [];
      drafts = [];
      today =
        (match Search.date (flag "today") with
        | Some d -> d
        | None -> When.today caps);
      selected = 0;
      reading = [];
      scroll = 0;
      mode = Browsing;
      draft = Mail_compose.blank ~id:"";
      body = Text_edit.of_string "";
      back_to = Browsing;
      field = "";
      after = None;
      soon = None;
      status;
      held = Set_.empty;
    }

type place = {
  name : string;
  mailbox : string;
  list : Screen.place; (* the Screener's, in the Inbox *)
  unread : bool; (* Unread, the Inbox's not read *)
}

let places (m : model) : place list =
  let p name mailbox list unread = { name; mailbox; list; unread } in
  (if not m.screening then [ p "Inbox" "INBOX" Screen.Imbox false ]
   else
     [ p "Imbox" "INBOX" Screen.Imbox false;
       p (Printf.sprintf "The Screener (%d)" m.waiting) "INBOX" Screen.Screener
         false;
       p "The Feed" "INBOX" Screen.Feed false;
       p "Paper Trail" "INBOX" Screen.Paper false ])
  @ [ p (Printf.sprintf "Unread (%d)" m.unread_count) "INBOX" Screen.Imbox true;
      p "Starred" Mail_sync.starred Screen.Imbox false;
      p "All Mail" Mail_sync.all_mail Screen.Imbox false;
      p "Drafts" drafts Screen.Imbox false ]

let shown (m : model) (p : place) : bool =
  p.mailbox = m.mailbox
  && (p.mailbox <> "INBOX" || (p.list = m.screen && p.unread = m.unread))

let refresh (caps : caps) (keys : string Set_.t) (m : model) : model =
  load caps { m with held = keys }
