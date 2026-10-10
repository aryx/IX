(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Oberon.mli *)

exception Track of int * int * int
exception Consume of char
exception Mark of int * int
exception Neutralize
exception Defocus

type selection = { mutable text : Texts.t option; mutable beg : int; mutable end_ : int; mutable time : int }
exception Selection of selection

let clock = ref 0
let time () = incr clock; !clock

type copy = { mutable copied : Display.frame option }
exception Copy of copy

let get_selection () =
  let s = { text = None; beg = 0; end_ = 0; time = -1 } in
  Viewers.broadcast (Selection s);
  Option.map (fun t -> t, s.beg, s.end_, s.time) s.text

let esc = '\027'
let setstar = '\026'

let dw = Display.width
let dh = Display.height
let display_width = dw
let display_height = dh
let user_track = 0
let system_track = dw / 8 * 5

(*****************************************************************************)
(* The cursors *)
(*****************************************************************************)

type marker = { fade : int -> int -> unit; draw : int -> int -> unit }
type cursor = { mutable marker : marker; mutable on : bool; mutable cx : int; mutable cy : int }

(* the arrow's tip, the star's centre, at (x, y), kept in the display *)
let flip_arrow x y = Display.copy_pattern White Display.arrow (min x (dw - 15)) (max 14 (min y dh) - 14) Invert
let flip_star x y = Display.copy_pattern White Display.star (max 7 (min x (dw - 8)) - 7) (max 7 (min y (dh - 8)) - 7) Invert

let arrow = { fade = flip_arrow; draw = flip_arrow }
let star = { fade = flip_star; draw = flip_star }
let mouse = { marker = arrow; on = false; cx = 0; cy = 0 }
let pointer = { marker = star; on = false; cx = 0; cy = 0 }

let fade_cursor c = if c.on then begin c.marker.fade c.cx c.cy; c.on <- false end

let draw_cursor c m x y =
  if c.on && (x <> c.cx || y <> c.cy || m != c.marker) then fade_cursor c;
  if not c.on then begin m.draw x y; c.marker <- m; c.cx <- x; c.cy <- y; c.on <- true end

let draw_mouse m x y = draw_cursor mouse m x y
let draw_mouse_arrow x y = draw_cursor mouse arrow x y
let fade_mouse () = fade_cursor mouse
let draw_pointer x y = draw_cursor pointer star x y
let marked_viewer () = Viewers.this pointer.cx pointer.cy

let remove_marks x y w h =
  if mouse.cx > x - 16 && mouse.cx < x + w + 16 && mouse.cy > y - 16 && mouse.cy < y + h + 16 then fade_cursor mouse;
  if pointer.cx > x - 8 && pointer.cx < x + w + 8 && pointer.cy > y - 8 && pointer.cy < y + h + 8 then fade_cursor pointer

(*****************************************************************************)
(* The display *)
(*****************************************************************************)

(* a filler: black, and the cursors drawn over it *)
let handle_filler (f : Display.frame) m =
  match m with
  | Track (_, x, y) -> draw_mouse_arrow x y
  | Mark (x, y) -> draw_pointer x y
  | Viewers.Restore when f.w > 0 && f.h > 0 ->
      remove_marks f.x f.y f.w f.h;
      Display.repl_const Black f.x f.y f.w f.h Replace
  | Viewers.Modify (y, _) when y < f.y ->
      remove_marks f.x y f.w (f.y - y);
      Display.repl_const Black f.x y f.w (f.y - y) Replace
  | _ -> ()

let filler () : Viewers.viewer = { frame = Display.frame handle_filler; state = 0; menu_h = 0 }

let open_display uw sw h =
  Display.repl_const Black !Viewers.cur_w 0 (uw + sw) h Replace;
  List.iter (fun w -> Viewers.init_track w h (filler ())) [ uw; sw ]

let open_track x w = Viewers.open_track x w (filler ())

(* in the user's track: the whole height while its filler is high,
 * else half of the highest viewer *)
let allocate_user_viewer () =
  if pointer.on then pointer.cx, pointer.cy
  else begin
    let fil, _, _, max = Viewers.locate user_track 0 in
    user_track, (if fil.frame.h >= dh / 8 then dh else max.frame.y + (max.frame.h / 2))
  end

(* in the system's: the highest viewer cut at a third, a half, a fifth... of the display *)
let allocate_system_viewer () =
  if pointer.on then pointer.cx, pointer.cy
  else begin
    let h3 = dh - (dh / 3) in
    let h2 = h3 - (h3 / 2) and h1 = dh / 5 and h0 = dh / 10 in
    let fil, bot, alt, max = Viewers.locate system_track dh in
    let y =
      if fil.frame.h >= dh / 8 then dh
      else if max.frame.h >= dh - h0 then max.frame.y + h3
      else if max.frame.h >= h3 - h0 then max.frame.y + h2
      else if max.frame.h >= h2 - h0 then max.frame.y + h1
      else if max != bot then max.frame.y + (max.frame.h / 2)
      else if bot.frame.h >= h1 then bot.frame.h / 2
      else alt.frame.y + (alt.frame.h / 2)
    in
    system_track, y
  end

(*****************************************************************************)
(* The commands *)
(*****************************************************************************)

let log = ref (Texts.open_ "")
let open_log t = log := t

type par = { mutable vwr : Viewers.viewer option; mutable frame : Display.frame option; mutable text : Texts.t; mutable pos : int }
let par = { vwr = None; frame = None; text = !log; pos = 0 }

let set_par (f : Display.frame) text pos =
  par.vwr <- Viewers.this f.x f.y; par.frame <- Some f; par.text <- text; par.pos <- pos

let cur_fnt = ref (Fonts.default ())

(* Oberon's trap: the command is left where it was, the loop goes on *)
let call name =
  match Modules.this_command name with
  | None -> false
  | Some command ->
      (try command ()
       with e ->
         let w = Texts.open_writer () in
         Texts.write_string w ("  TRAP in " ^ name ^ ": " ^ Printexc.to_string e); Texts.write_ln w;
         Texts.append !log w.buf);
      true

(*****************************************************************************)
(* The tasks *)
(*****************************************************************************)

type task = { handler : unit -> unit; mutable period : int; mutable next_time : int }
let tasks : task list ref = ref []
let turns = ref 0

let new_task handler period = { handler; period; next_time = 0 }
let install t = if not (List.memq t !tasks) then tasks := !tasks @ [ t ]
let remove t = tasks := List.filter (fun u -> u != t) !tasks
let set_period t n = t.period <- max 1 n
let nof_tasks () = List.length !tasks

(* at each turn of the loop with nothing to do: the tasks whose time has come *)
let run_tasks () =
  incr turns;
  List.iter (fun t -> if !turns >= t.next_time then begin t.next_time <- !turns + t.period; t.handler () end) !tasks

let () = open_display (dw / 8 * 5) (dw / 8 * 3) dh

(*****************************************************************************)
(* The loop *)
(*****************************************************************************)

let focus_viewer : Viewers.viewer option ref = ref None

let send (v : Viewers.viewer) m = Display.send v.frame m

let pass_focus v =
  Option.iter (fun old -> send old Defocus) !focus_viewer;
  focus_viewer := v

(* to the viewer that has (x, y) *)
let send_at x y m = Option.iter (fun v -> send v m) (Viewers.this x y)

let loop () =
  let prev = ref (-1, -1) in
  while true do
    let keys, x, y = Input.mouse () in
    if Input.available () > 0 then begin
      let ch = Input.read () in
      if ch = esc then begin Viewers.broadcast Neutralize; fade_cursor pointer end
      else if ch = setstar then send_at x y (Mark (x, y))
      else Option.iter (fun v -> send v (Consume ch)) !focus_viewer
    end
    else if keys <> 0 then begin
      (* a key of the mouse went down: the viewers under it are told
       * until all are up (the interclicks: a handler waits for that
       * itself, asking the mouse) *)
      let rec track keys x y =
        send_at x y (Track (keys, x, y));
        let keys, x, y = Input.mouse () in
        if keys <> 0 then track keys x y
      in
      track keys x y
    end
    else begin
      if (x, y) <> !prev || not mouse.on then begin
        send_at x y (Track (0, x, y));
        prev := (x, y)
      end;
      run_tasks ()
    end
  done
