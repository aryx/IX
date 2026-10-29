(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Mail_window.mli *)

open Playground

type caps =
  < Cap.network ; Cap.open_in ; Cap.open_out ; Cap.readdir ; Cap.env ; Cap.exit >

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

(* what waits for the password *)
type action = Fetch | Open | Archive
type asking = Password | Search
type mode = Browsing | Reading | Asking of asking

type model = {
  account : string;
  server : Mail_sync.server;
  mailbox : string;
  password : string option; (* kept while the window is open *)
  query : string; (* the search's words, "" for none *)
  conversations : Imap.summary list list;
  selected : int;
  (* the conversation opened: its messages, oldest first, each its text
   * when the cache has it *)
  reading : (Imap.summary * string option) list;
  scroll : int; (* the first line of the conversation shown *)
  mode : mode;
  field : string; (* what is typed after a question *)
  after : action option;
  status : string;
  held : string Set_.t; (* the keys down at the last frame *)
}

let store (caps : caps) : Items.t = Items.at (Items.place caps)

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

(* the conversations again from the store *)
let load (caps : caps) (m : model) : model =
  let l =
    Mail_item.listed
      (Items.all caps (store caps))
      ~account:m.account ~mailbox:m.mailbox
  in
  let cs = List.filter (matches m.query) (Conversations.group l) in
  let n = List.length cs in
  { m with conversations = cs; selected = max 0 (min m.selected (n - 1)) }

let initial (caps : caps) (flags : Playground.flags) : model =
  let flag name =
    match List.assoc_opt name flags with Some v -> v | None -> ""
  in
  let server =
    match String.rindex_opt (flag "server") ':' with
    | Some i -> (
        let hp = flag "server" in
        match
          int_of_string_opt (String.sub hp (i + 1) (String.length hp - i - 1))
        with
        | Some port ->
            {
              Mail_sync.host = String.sub hp 0 i;
              port;
              plain = List.mem_assoc "plain" flags;
            }
        | None -> Mail_sync.gmail)
    | None -> { Mail_sync.gmail with plain = List.mem_assoc "plain" flags }
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
      server;
      mailbox = "INBOX";
      password;
      query = "";
      conversations = [];
      selected = 0;
      reading = [];
      scroll = 0;
      mode = Browsing;
      field = "";
      after = None;
      status;
      held = Set_.empty;
    }

(*****************************************************************************)
(* What the keys and the menus do *)
(*****************************************************************************)

let current (m : model) : Imap.summary list =
  match List.nth_opt m.conversations m.selected with Some c -> c | None -> []

(* [f] in a session, its error the status *)
let online (caps : caps) (m : model) (password : string)
    (f : Imap.t -> ('a, string) result) : ('a, string) result =
  Mail_sync.session caps m.server ~user:m.account ~password ~mailbox:m.mailbox f

(* the conversation opened: its texts from the server (and so the
 * cache) when the password is known, from the cache else *)
let open_ (caps : caps) (m : model) : model =
  let messages = List.rev (current m) in
  let cached (s : Imap.summary) = Items.cached caps (store caps) s.msgid in
  let texts =
    match m.password with
    | None -> Ok (List.map (fun s -> (s, cached s)) messages)
    | Some p ->
        online caps m p (fun t ->
            Ok
              (List.map
                 (fun (s : Imap.summary) ->
                   match
                     Mail_sync.message caps (store caps) t ~account:m.account
                       ~mailbox:m.mailbox s.uid
                   with
                   | Ok text -> (s, Some text)
                   | Error _ -> (s, cached s))
                 messages))
  in
  match texts with
  | Error e -> { m with status = e }
  | Ok reading ->
      let missing = List.exists (fun (_, t) -> t = None) reading in
      let m = load caps m in
      {
        m with
        reading;
        scroll = 0;
        mode = Reading;
        status = (if missing then "g: get the mail to read it all" else "");
      }

let run (caps : caps) (m : model) (action : action) : model =
  match m.password with
  | None -> { m with mode = Asking Password; field = ""; after = Some action }
  | Some p -> (
      match action with
      | Open -> open_ caps m
      | Fetch -> (
          match
            online caps m p (fun t ->
                Mail_sync.list caps (store caps) t ~account:m.account
                  ~mailbox:m.mailbox ~query:None 50)
          with
          | Error e -> { m with status = e; password = None }
          | Ok l ->
              let m = load caps m in
              {
                m with
                status = Printf.sprintf "%d messages fetched" (List.length l);
              })
      | Archive -> (
          let uids = List.map (fun (s : Imap.summary) -> s.uid) (current m) in
          match
            online caps m p (fun t ->
                Mail_sync.archive caps (store caps) t ~account:m.account
                  ~mailbox:m.mailbox uids)
          with
          | Error e -> { m with status = e }
          | Ok () ->
              let m = load caps { m with mode = Browsing } in
              { m with status = "archived" }))

(* the next or the previous conversation; opened, when one is *)
let next (caps : caps) (m : model) (d : int) : model =
  let n = List.length m.conversations in
  let m = { m with selected = max 0 (min (n - 1) (m.selected + d)) } in
  if m.mode = Reading then open_ caps m else m

(* what is printable of what was typed *)
let printable (typed : string) : string =
  String.concat "" (List.filter (fun c -> c >= " ") (Text.chars typed))

let without_last (s : string) : string =
  match List.rev (Text.chars s) with
  | [] -> ""
  | _ :: rest -> String.concat "" (List.rev rest)

(* what a person can ask, by a key or by a menu *)
type command =
  | Get
  | Search_
  | Exit
  | Open_
  | Back
  | Archive_
  | Next
  | Previous
  | Inbox
  | All_mail

(* the menu bar: each menu its title, then its items, each with its
 * command and its key, said in the item (a menu is where the keys are
 * learnt) *)
let menus : (string * (string * command) list) list =
  [ ( "Mail",
      [ ("Get Mail  (g)", Get); ("Search...  (/)", Search_); ("Exit", Exit) ] );
    ( "Conversation",
      [ ("Open  (o)", Open_); ("Back to List  (u)", Back);
        ("Archive  (e)", Archive_); ("Next  (j)", Next);
        ("Previous  (k)", Previous) ] );
    ("Go", [ ("Inbox  (Tab)", Inbox); ("All Mail  (Tab)", All_mail) ]) ]

let menu_bar = 30.

(* the menu [i]'s title, at the window's top left *)
let menu_box (computer : computer) (i : int) : Widget.box =
  let w = computer.screen.width and h = computer.screen.height in
  (* (as wide as the longest item, "Back to List  (u)") *)
  { Widget.x = (-.w /. 2.) +. 89. +. (float_of_int i *. 174.);
    y = (h /. 2.) -. (menu_bar /. 2.); w = 170.; h = menu_bar -. 4. }

(* the menus asked for this frame (every frame: immediate mode), and the
 * command of the item chosen, if one was *)
let chosen (computer : computer) : command option =
  List.fold_left
    (fun found (i, (title, items)) ->
      let labels = title :: List.map fst items in
      let k = Gui.menu_in computer (menu_box computer i) labels 0 in
      (* (0: the title, nothing chosen) *)
      if found <> None || k = 0 then found
      else Option.map snd (List.nth_opt items (k - 1)))
    None
    (List.mapi (fun i menu -> (i, menu)) menus)

let switch (caps : caps) (m : model) (mailbox : string) : model =
  let m =
    load caps { m with mailbox; selected = 0; mode = Browsing; status = "" }
  in
  (* (fetched when the password is known: what the store has of the
   * other mailbox may be old, or nothing) *)
  if m.password <> None then run caps m Fetch else m

let command (caps : caps) (m : model) (c : command) : model =
  match c with
  | Get -> run caps m Fetch
  | Search_ -> { m with mode = Asking Search; field = m.query }
  | Exit -> CapStdlib.exit caps 0
  | Open_ ->
      if current m = [] then m
      else if m.password = None then open_ caps m
      else run caps m Open
  | Back -> { m with mode = Browsing }
  | Archive_ -> if current m = [] then m else run caps m Archive
  | Next -> next caps m 1
  | Previous -> next caps m (-1)
  | Inbox -> switch caps m "INBOX"
  | All_mail -> switch caps m "[Gmail]/All Mail"

let update (caps : caps) (computer : computer) (m : model) : model =
  let keys = computer.keyboard.keys in
  let pressed name = Set_.mem name keys && not (Set_.mem name m.held) in
  let menu = chosen computer in
  let m =
    match m.mode with
    | Asking a ->
        if pressed "Escape" then
          { m with mode = Browsing; field = ""; after = None }
        else if pressed "Enter" then
          match a with
          | Password -> (
              let m =
                { m with password = Some m.field; field = ""; mode = Browsing }
              in
              match m.after with
              | Some action -> run caps { m with after = None } action
              | None -> m)
          | Search ->
              load caps
                { m with query = m.field; field = ""; mode = Browsing;
                  selected = 0 }
        else if pressed "Backspace" then { m with field = without_last m.field }
        else { m with field = m.field ^ printable computer.keyboard.typed }
    | (Browsing | Reading) when Gui.modal () -> m
    | Browsing | Reading -> (
        let reading = m.mode = Reading in
        let key =
          if pressed "j" || ((not reading) && pressed "ArrowDown") then Some Next
          else if pressed "k" || ((not reading) && pressed "ArrowUp") then
            Some Previous
          else if pressed "o" || pressed "Enter" then Some Open_
          else if pressed "u" || pressed "Escape" then Some Back
          else if pressed "e" then Some Archive_
          else if pressed "g" then Some Get
          else if pressed "/" then Some Search_
          else if pressed "Tab" then
            Some (if m.mailbox = "INBOX" then All_mail else Inbox)
          else None
        in
        match (menu, key) with
        | Some c, _ | None, Some c -> command caps m c
        | None, None ->
            if reading && (pressed "ArrowDown" || pressed "space") then
              { m with scroll = (m.scroll + if pressed "space" then 10 else 1) }
            else if reading && pressed "ArrowUp" then
              { m with scroll = max 0 (m.scroll - 1) }
            else m)
  in
  { m with held = keys }

(*****************************************************************************)
(* The picture *)
(*****************************************************************************)

let size = 16.
let row = 28.
let side = 170.
let bar = 40.
let ink = rgb 32 33 36
let grey = rgb 95 99 104
let blue = rgb 26 115 232

(* a letter's width, Hershey's at [size] *)
let advance (c : string) : float =
  let g = Glyph_unicode.glyph c in
  float_of_int (g.right - g.left) *. size /. Hershey.units_per_em

let width (s : string) : float =
  List.fold_left (fun w c -> w +. advance c) 0. (Text.chars s)

(* [s]'s letters from [x] on the [baseline], those past [room] left out *)
let text (color : color) ~(bold : bool) ~(room : float) (x : float)
    (baseline : float) (s : string) : shape =
  let rec place (x0 : float) acc l =
    match l with
    | [] -> List.rev acc
    | c :: rest ->
        let w = advance c in
        if x0 +. w > x +. room then List.rev acc
        else place (x0 +. w) ((x0, c) :: acc) rest
  in
  letters color
    { size; bold; italic = false; baseline; at = place x [] (Text.chars s) }

(* a text's lines cut at [room], at the spaces *)
let wrap (room : float) (s : string) : string list =
  List.concat_map
    (fun line ->
      let words = String.split_on_char ' ' line in
      let rec go cur acc ws =
        match ws with
        | [] -> List.rev (cur :: acc)
        | w :: rest ->
            let next = if cur = "" then w else cur ^ " " ^ w in
            if cur <> "" && width next > room then go w (cur :: acc) rest
            else go next acc rest
      in
      go "" [] words)
    (String.split_on_char '\n' s)

let mailbox_name (m : model) : string =
  if m.mailbox = "INBOX" then "Inbox"
  else if m.mailbox = "[Gmail]/All Mail" then "All Mail"
  else m.mailbox

let view (computer : computer) (m : model) : shape list =
  let w = computer.screen.width and h = computer.screen.height in
  (* (the menu bar above the rest) *)
  let left = -.w /. 2. and top = (h /. 2.) -. menu_bar in
  let x0 = left +. side +. 16. in
  let room = w -. side -. 32. in
  let top_bar =
    let title =
      match m.mode with
      | Asking Password ->
          "password: " ^ String.make (List.length (Text.chars m.field)) '*'
      | Asking Search -> "search: " ^ m.field ^ "_"
      | Browsing | Reading -> mailbox_name m ^ " \xe2\x80\x94 " ^ m.account
    in
    let right =
      if m.status <> "" then m.status
      else Printf.sprintf "%d conversations" (List.length m.conversations)
    in
    [
      rectangle (rgb 241 243 244) w bar |> move 0. (top -. (bar /. 2.));
      text ink ~bold:true ~room:(w /. 2.) (left +. 16.) (top -. 26.) title;
      text grey ~bold:false ~room:(w /. 2.)
        (-.left -. 16. -. width right)
        (top -. 26.) right;
    ]
  in
  let sidebar =
    List.concat
      (List.mapi
         (fun i (name, box) ->
           let y = top -. bar -. 12. -. (float_of_int i *. row) in
           (if box = m.mailbox then
              [
                rectangle (rgb 211 227 253) side row
                |> move (left +. (side /. 2.)) (y -. (row /. 2.));
              ]
            else [])
           @ [
               text ink ~bold:(box = m.mailbox) ~room:(side -. 24.)
                 (left +. 16.) (y -. 19.) name;
             ])
         [ ("Inbox", "INBOX"); ("All Mail", "[Gmail]/All Mail") ])
    @
    if m.query <> "" then
      [
        text blue ~bold:false ~room:(side -. 24.) (left +. 16.)
          (top -. bar -. 12. -. (3. *. row) -. 19.)
          ("/" ^ m.query);
      ]
    else []
  in
  let main =
    match m.mode with
    | Reading ->
        let subject =
          match m.reading with
          | (s, _) :: _ -> Conversations.header s.headers "subject"
          | [] -> ""
        in
        let lines =
          List.concat_map
            (fun ((s : Imap.summary), t) ->
              let head =
                Conversations.who s.headers
                ^ "   "
                ^ Conversations.day s.headers
              in
              let body =
                match t with
                | Some t -> wrap room (String.trim (Mime.text (Mail.parse t)))
                | None -> [ "(not fetched: g gets the mail)" ]
              in
              ((true, head) :: List.map (fun l -> (false, l)) body)
              @ [ (false, "") ])
            m.reading
        in
        let fits = int_of_float ((h -. bar -. 60.) /. 22.) in
        let shown =
          List.filteri (fun i _ -> i >= m.scroll && i < m.scroll + fits) lines
        in
        text ink ~bold:true ~room x0 (top -. bar -. 32.) subject
        :: List.mapi
             (fun i (bold, l) ->
               text
                 (if bold then ink else grey)
                 ~bold ~room x0
                 (top -. bar -. 62. -. (float_of_int i *. 22.))
                 l)
             shown
    | Browsing | Asking _ ->
        if m.conversations = [] then
          [
            text grey ~bold:false ~room x0
              (top -. bar -. 31.)
              "No mail here: g gets it.";
          ]
        else
          let fits = int_of_float ((h -. bar -. 12.) /. row) in
          let first = max 0 (m.selected - fits + 1) in
          List.concat
            (List.mapi
               (fun i (c : Imap.summary list) ->
                 if i < first || i >= first + fits then []
                 else
                   let s = List.hd c in
                   let y =
                     top -. bar -. 12. -. (float_of_int (i - first) *. row)
                   in
                   let bold = Conversations.unread c in
                   let many =
                     if List.length c > 1 then
                       Printf.sprintf " (%d)" (List.length c)
                     else ""
                   in
                   let day = Conversations.day s.headers in
                   (if i = m.selected then
                      [
                        rectangle (rgb 232 240 254) (room +. 16.) row
                        |> move
                             (x0 -. 8. +. ((room +. 16.) /. 2.))
                             (y -. (row /. 2.));
                      ]
                    else [])
                   @ [
                       text ink ~bold ~room:190. x0 (y -. 19.)
                         (Conversations.who s.headers ^ many);
                       text ink ~bold ~room:(room -. 310.) (x0 +. 200.)
                         (y -. 19.)
                         (Conversations.header s.headers "subject");
                       text grey ~bold
                         ~room:(width day +. 4.)
                         (x0 +. room -. width day)
                         (y -. 19.) day;
                     ])
               m.conversations)
  in
  (rectangle white w h :: top_bar)
  @ sidebar @ main
  @ [ rectangle (Gui.theme ()).face w menu_bar |> move 0. (top +. (menu_bar /. 2.)) ]
  (* (the menus last: an open one over the list) *)
  @ Gui.draw ()
