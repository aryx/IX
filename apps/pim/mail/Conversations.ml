(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Conversations.mli *)

let group (l : Imap.summary list) : Imap.summary list list =
  let key (s : Imap.summary) =
    if s.thread = "" then string_of_int s.uid else s.thread
  in
  let rec go (acc : (string * Imap.summary list) list) l =
    match l with
    | [] -> acc
    | s :: rest ->
        let k = key s in
        let acc =
          match List.assoc_opt k acc with
          | Some ms -> (k, s :: ms) :: List.remove_assoc k acc
          | None -> (k, [ s ]) :: acc
        in
        go acc rest
  in
  (* (oldest first in: the newest message's conversation ends on top) *)
  List.map snd (go [] l)

let unread (c : Imap.summary list) : bool =
  List.exists (fun (s : Imap.summary) -> not (List.mem "\\Seen" s.flags)) c

let header (m : Mail.t) (name : string) : string =
  match Mail.get m name with Some v -> Mime.decode_words v | None -> ""

let who (m : Mail.t) : string =
  match Mail.address (header m "from") with
  | Some a -> Mail.who a
  | None -> header m "from"

let day (m : Mail.t) : string =
  match Option.bind (Mail.get m "date") Mail.date with
  | Some d -> Printf.sprintf "%04d-%02d-%02d" d.day.year d.day.month d.day.day
  | None -> ""
