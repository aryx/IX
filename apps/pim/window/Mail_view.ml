(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Mail_view.mli *)

open Playground
open Pim_look
open Mail_model

(* where the message's fields, its text and its buttons are: under the
 * title bar, right of the sidebar *)
let field_box (computer : computer) (i : int) : Widget.box =
  let w = computer.screen.width and h = computer.screen.height in
  let x0 = (-.w /. 2.) +. side +. 16. and room = w -. side -. 32. in
  { Widget.x = x0 +. 80. +. ((room -. 80.) /. 2.);
    y = (h /. 2.) -. menu_bar -. bar -. 26. -. (float_of_int i *. 34.);
    w = room -. 80.; h = 26. }

let area_box (computer : computer) : Widget.box =
  let w = computer.screen.width and h = computer.screen.height in
  let x0 = (-.w /. 2.) +. side +. 16. and room = w -. side -. 32. in
  let top = (h /. 2.) -. menu_bar -. bar -. 26. -. (3. *. 34.) -. 26. in
  let bottom = (-.h /. 2.) +. 56. in
  { Widget.x = x0 +. (room /. 2.); y = (top +. bottom) /. 2.; w = room;
    h = top -. bottom }

let button_box (computer : computer) (i : int) : Widget.box =
  let w = computer.screen.width and h = computer.screen.height in
  let x0 = (-.w /. 2.) +. side +. 16. in
  { Widget.x = x0 +. 60. +. (float_of_int i *. 130.); y = (-.h /. 2.) +. 28.;
    w = 120.; h = 30. }


let mailbox_name (m : model) : string =
  if m.mailbox = "INBOX" then
    match (m.screening, m.screen) with
    | false, _ -> "Inbox"
    | true, Screen.Imbox -> "Imbox"
    | _, Screen.Screener -> "The Screener"
    | _, Screen.Feed -> "The Feed"
    | _, Screen.Paper -> "Paper Trail"
    | _, Screen.Out -> "Screened Out"
  else if m.mailbox = Mail_sync.all_mail then "All Mail"
  else if m.mailbox = drafts then "Drafts"
  else m.mailbox

let view (computer : computer) (m : model) : shape list =
  let h = computer.screen.height in
  let a = area computer in
  let x0 = a.x0 and room = a.room and top = a.top in
  let title =
    match m.mode with
    | Asking Password ->
        "password: " ^ String.make (List.length (Text.chars m.field)) '*'
    | Asking Search -> "search: " ^ m.field ^ "_"
    | Asking Until -> "snooze until: " ^ m.field ^ "_"
    | Asking Due -> "a task, due: " ^ m.field ^ "_"
    | Composing ->
        (if m.draft.subject = "" then "New message" else m.draft.subject)
        ^ " \xe2\x80\x94 " ^ m.account
    | Browsing | Reading -> mailbox_name m ^ " \xe2\x80\x94 " ^ m.account
  in
  let right =
    if m.status <> "" then m.status
    else if m.mailbox = drafts then count (List.length m.drafts) "draft"
    else count (List.length m.conversations) "conversation"
  in
  let sidebar =
    Pim_look.sidebar a
      (List.map
         (fun (name, box, p) ->
           (name, box = m.mailbox && (box <> "INBOX" || p = m.screen)))
         (places m))
    @
    if m.query <> "" then
      [ text blue ~bold:false ~room:(side -. 24.) (a.left +. 16.)
          (row_y a (if m.screening then 7 else 4))
          ("/" ^ m.query) ]
    else []
  in
  let main =
    match m.mode with
    | Composing ->
        (* the fields' names; the fields, the text and the buttons are
         * the toolkit's (Gui.draw) *)
        List.mapi
          (fun i name ->
            let b = field_box computer i in
            text grey ~bold:false ~room:76. x0 (b.y -. 5.) name)
          [ "To"; "Cc"; "Subject"; "Attach" ]
    | Browsing when m.mailbox = drafts ->
        if m.drafts = [] then
          [ text grey ~bold:false ~room x0 (row_y a 0) "No drafts." ]
        else
          List.concat
            (List.mapi
               (fun i (d : Mail_compose.draft) ->
                 let y = row_y a i in
                 (if i = m.selected then [ selected a y ] else [])
                 @ [ text ink ~bold:false ~room:190. x0 y
                       (if d.to_ = "" then "(no one)" else d.to_);
                     text ink ~bold:false ~room:(room -. 200.) (x0 +. 200.) y
                       (if d.subject = "" then "(no subject)" else d.subject) ])
               m.drafts)
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
                | Some t -> wrap room (String.trim (Mail_text.text (Mail.parse t)))
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
        (* what Detect finds in a line underlined, x to keep it *)
        let underlined (y : float) (l : string) =
          List.filter_map
            (fun (f : Detect.found) ->
              match Detect.index l f.said with
              | Some p ->
                  let w = width f.said in
                  Some
                    (rectangle blue w 1.5
                    |> move (x0 +. width (String.sub l 0 p) +. (w /. 2.))
                         (y -. 4.))
              | None -> None)
            (Detect.find ~today:m.today l)
        in
        text ink ~bold:true ~room x0 (top -. bar -. 32.) subject
        :: List.concat
             (List.mapi
                (fun i (bold, l) ->
                  let y = top -. bar -. 62. -. (float_of_int i *. 22.) in
                  text (if bold then ink else grey) ~bold ~room x0 y l
                  :: (if bold then [] else underlined y l))
                shown)
    | Browsing | Asking _ ->
        if m.conversations = [] then
          [ text grey ~bold:false ~room x0 (row_y a 0) "No mail here: g gets it." ]
        else
          let fits = int_of_float ((h -. bar -. 12.) /. row) in
          let first = max 0 (m.selected - fits + 1) in
          List.concat
            (List.mapi
               (fun i (c : Imap.summary list) ->
                 if i < first || i >= first + fits then []
                 else
                   let s = List.hd c in
                   let y = row_y a (i - first) in
                   let bold = Conversations.unread c in
                   let many =
                     if List.length c > 1 then
                       Printf.sprintf " (%d)" (List.length c)
                     else ""
                   in
                   let day = Conversations.day s.headers in
                   (if i = m.selected then [ selected a y ] else [])
                   @ [
                       text ink ~bold ~room:190. x0 y
                         (Conversations.who s.headers ^ many);
                       text ink ~bold ~room:(room -. 310.) (x0 +. 200.) y
                         (Conversations.header s.headers "subject");
                       text grey ~bold
                         ~room:(width day +. 4.)
                         (x0 +. room -. width day)
                         y day;
                     ])
               m.conversations)
  in
  (rectangle white computer.screen.width h :: title_bar computer title right)
  @ sidebar @ main
