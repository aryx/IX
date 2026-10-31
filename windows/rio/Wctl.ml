(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Wctl.mli *)

type verb = [%mli]
type command = [%mli]

let verbs = [ "new", New; "resize", Resize; "move", Move; "top", Top; "bottom", Bottom; "current", Current;
              "hide", Hide; "unhide", Unhide; "delete", Delete; "scroll", Scroll; "noscroll", Noscroll ]

let parse text : command =
  let bad m = raise (P9_server.Error m) in
  (* (rio's numbers may be in square brackets, as it prints a rectangle) *)
  let number s =
    let s = String.concat "" (String.split_on_char '[' (String.concat "" (String.split_on_char ']' s))) in
    match int_of_string_opt s with Some n -> n | None -> bad "missing or bad wctl parameter" in
  let blank c = if c = '\n' || c = '\t' then ' ' else c in
  let verb, rest = match List.filter (fun s -> s <> "") (String.split_on_char ' ' (String.map blank text)) with
    | v :: rest when List.mem_assoc v verbs -> List.assoc v verbs, rest
    | _ -> bad "unrecognized wctl command" in
  let rec flags (c : command) = function
    | "-hide" :: more -> flags { c with hidden = true } more
    | "-scroll" :: more -> flags { c with scrolling = Some true } more
    | "-noscroll" :: more -> flags { c with scrolling = Some false } more
    | "-id" :: n :: more -> flags { c with id = Some (number n) } more
    | "-r" :: x0 :: y0 :: x1 :: y1 :: more -> let r = Rectangle.v (number x0) (number y0) (number x1) (number y1) in flags { c with place = (fun _ -> r) } more
    | side :: n :: more when List.mem side [ "-minx"; "-miny"; "-maxx"; "-maxy"; "-dx"; "-dy" ] ->
        (* a side's place: a number, or after a sign that much from where it is *)
        let signed = n <> "" && (n.[0] = '-' || n.[0] = '+') in
        let v = number (if signed then String.sub n 1 (String.length n - 1) else n) in
        let set old said = if not signed then said else if n.[0] = '-' then old - v else old + v in
        let edit (r : Rectangle.t) =
          if side = "-minx" then Rectangle.v (set r.min.x v) r.min.y r.max.x r.max.y
          else if side = "-miny" then Rectangle.v r.min.x (set r.min.y v) r.max.x r.max.y
          else if side = "-maxx" then Rectangle.v r.min.x r.min.y (set r.max.x v) r.max.y
          else if side = "-maxy" then Rectangle.v r.min.x r.min.y r.max.x (set r.max.y v)
          else if side = "-dx" then Rectangle.v r.min.x r.min.y (set r.max.x (r.min.x + v)) r.max.y
          else Rectangle.v r.min.x r.min.y r.max.x (set r.max.y (r.min.y + v)) in
        let before = c.place in
        flags { c with place = (fun r -> edit (before r)) } more
    | flag :: _ when flag.[0] = '-' && verb <> New -> bad "missing or bad wctl parameter"
    | rest -> c, rest in
  let c, rest = flags { verb; place = (fun r -> r); hidden = false; scrolling = None; id = None; arg = "" } rest in
  if verb <> New && rest <> [] then bad "extraneous text in wctl message";
  { c with arg = String.concat " " rest }

let requests : (Window.t * command) Event.channel = Event.new_channel ()

let wctl : Device.t = { Device.default with name = "wctl";
  read = (fun w ->
    let r = w.image.r in
    Device.part (Printf.sprintf "%11d %11d %11d %11d %s %s " r.min.x r.min.y r.max.x r.max.y
                   (if w.current then "current" else "notcurrent") (if w.hidden then "hidden" else "visible")));
  write = (fun w data ->
    let c = parse data in
    ignore (Thread.create (fun () -> Event.sync (Event.send requests (w, c))) ())) }
