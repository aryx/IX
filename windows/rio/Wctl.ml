(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Wctl.mli *)

type verb = [%mli]
type command = [%mli]

let verbs = [ "new", New; "resize", Resize; "move", Move; "top", Top; "bottom", Bottom; "current", Current;
              "hide", Hide; "unhide", Unhide; "delete", Delete; "scroll", Scroll; "noscroll", Noscroll; "exit", Exit ]

let plain : command =
  { verb = New; place = (fun r -> r); area = None; hidden = false; scrolling = None; id = None; arg = ""; label = ""; cd = ""; hold = false; layer = Window.Normal }

(* -edge's rectangle: along a side of the area, [size] deep *)
let along side size (work : Rectangle.t) =
  if side = "top" then Rectangle.v work.min.x work.min.y work.max.x (work.min.y + size)
  else if side = "bottom" then Rectangle.v work.min.x (work.max.y - size) work.max.x work.max.y
  else if side = "left" then Rectangle.v work.min.x work.min.y (work.min.x + size) work.max.y
  else Rectangle.v (work.max.x - size) work.min.y work.max.x work.max.y

(* -at's rectangle: a corner, a side or the middle of the area *)
let anchored where wide high (work : Rectangle.t) =
  let w = min wide (Rectangle.dx work) and h = min high (Rectangle.dy work) in
  let x = if String.contains where 'w' then work.min.x else if String.contains where 'e' then work.max.x - w else work.min.x + ((Rectangle.dx work - w) / 2) in
  let y = if String.contains where 'n' then work.min.y else if String.contains where 's' then work.max.y - h else work.min.y + ((Rectangle.dy work - h) / 2) in
  Rectangle.v x y (x + w) (y + h)

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
    | "-max" :: more -> flags { c with area = Some (fun work -> work) } more
    | "-at" :: where :: w :: h :: more when List.mem where [ "nw"; "n"; "ne"; "w"; "c"; "e"; "sw"; "s"; "se" ] ->
        let w = number w and h = number h in
        flags { c with area = Some (anchored where w h) } more
    | "-at" :: _ -> bad "missing or bad wctl parameter"
    | "-edge" :: side :: n :: more when List.mem side [ "top"; "bottom"; "left"; "right" ] ->
        let n = number n in
        flags { c with area = Some (along side n) } more
    | "-edge" :: _ -> bad "missing or bad wctl parameter"
    | "-desk" :: more -> flags { c with layer = Window.Desk } more
    | "-panel" :: more -> flags { c with layer = Window.Panel } more
    | "-popup" :: more -> flags { c with layer = Window.Popup } more
    | "-label" :: l :: more -> flags { c with label = l } more
    | "-cd" :: d :: more -> flags { c with cd = d } more
    | "-hold" :: more -> flags { c with hold = true } more
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
  let c, rest = flags { plain with verb } rest in
  if verb <> New && rest <> [] then bad "extraneous text in wctl message";
  { c with arg = String.concat " " rest }

let requests : (Window.t option * command) Event.channel = Event.new_channel ()

let ask w c = ignore (Thread.create (fun () -> Event.sync (Event.send requests (w, c))) ())
let ended w = ask (Some w) { plain with verb = Delete }
let written w data = ask w (parse data)

let wctl : Device.t = { Device.default with name = "wctl";
  read = (fun w ->
    let r = w.image.r in
    Device.part (Printf.sprintf "%11d %11d %11d %11d %s %s %s" r.min.x r.min.y r.max.x r.max.y
                   (if w.current then "current" else "notcurrent") (if w.hidden then "hidden" else "visible")
                   (match w.layer with Window.Normal -> "" | Window.Desk -> "desk " | Window.Panel -> "panel " | Window.Popup -> "popup ")));
  write = (fun w data -> written (Some w) data) }
