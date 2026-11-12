(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyWindows.mli *)

module D = TinyLibDraw

module TSys = TinyLibSystem

(* what we write to a window's shell, or draw, when it may be gone: its
 * end's error ignored, the window deleted when its pipes end *)
let put fd s = try TSys.write fd s with Failure _ -> ()

(*****************************************************************************)
(* Drawing: messages gathered, written at each turn of the loop *)
(*****************************************************************************)

(* our images: the screen (or our window), the colours; a window's and
 * its programs' are numbers from 16 *)
let screen = 0
let grey = 1
let white = 2
let black = 3
let blue = 4
let pale = 5
let red = 6

(* (written past a kilobyte too: a message joined to n bytes copies them) *)
let gathered = ref ""
let flush () =
  if !gathered <> "" then (put TSys.fd_draw !gathered; gathered := "")
let send m =
  gathered := !gathered ^ m; if String.length !gathered > 1024 then flush ()

(* the numbers in use; the lowest free one *)
let used = ref []
let fresh () =
  let rec from n = if List.mem n !used then from (n + 1) else n in
  let n = from 16 in
  used := n :: !used;
  n
let release n = used := List.filter (fun k -> k <> n) !used

(* a rectangle is its two corners; what two have in common; one of no pixel *)
let clip (ax0, ay0, ax1, ay1) (bx0, by0, bx1, by1) =
  max ax0 bx0, max ay0 by0, min ax1 bx1, min ay1 by1
let empty (x0, y0, x1, y1) = x1 <= x0 || y1 <= y0
let inside (x0, y0, x1, y1) x y = x >= x0 && x < x1 && y >= y0 && y < y1
let fill dst colour r =
  if not (empty r) then
    send (D.d_fill dst colour r)
let everything = 0, 0, D.screen_w, D.screen_h

(*****************************************************************************)
(* Windows *)
(*****************************************************************************)

(* A window. Our ends of what its shell was given: its keys, what it
 * prints, what it draws, its mouse *)
type ends = {
  keys : int; mutable keys_open : bool; prints : int; draws : int; mouse : int
}

(* what is in it: the drawn bytes that are not a whole message yet; its
 * programs' numbers for their images, and ours; whether it is a
 * picture; where the next character goes, and the line typed so far *)
type page = {
  mutable pending : string; mutable ids : (int * int) list;
  mutable picture : bool;
  mutable col : int; mutable row : int; mutable line : string;
  mutable cursor : int;
    (* the mouse's look its program asked for (d_cursor) *)
}

(* its image (w by h pixels) and where its border's corner is on the
 * screen; its shell's pid. (Three records: tiny-ml makes one of
 * nine fields at most, an expression being 11 registers deep.) *)
type window = {
  image : int; w : int; h : int; mutable x : int; mutable y : int; pid : int;
  ends : ends; page : page
}

(* the front one first: it has the keys *)
let windows = ref []
let current w = match !windows with v :: _ -> v == w | [] -> false

(* The mouse's look on the screen: the front window's, as its program
 * asked for it (d_cursor), while the mouse is in that window; the arrow
 * anywhere else. Sent only when it changes. *)
let shown_cursor = ref 0
let show_cursor kind =
  if kind <> !shown_cursor then begin
    (* (the number its program's message carried: 1 a hand) *)
    shown_cursor := kind;
    send (D.d_cursor (if kind = 1 then D.Cursor_hand else D.Cursor_arrow))
  end

let border = 3
let outer w = w.x, w.y, w.x + w.w + (2 * border), w.y + w.h + (2 * border)
let inner w = w.x + border, w.y + border, w.x + border + w.w, w.y + border + w.h

(* a rectangle's four sides, so many pixels thick, each given to f *)
let sides (x0, y0, x1, y1) t f =
  f (x0, y0, x1, y0 + t); f (x0, y1 - t, x1, y1);
  f (x0, y0, x0 + t, y1); f (x1 - t, y0, x1, y1)

(* a window's part in a rectangle of the screen: its border (the
 * current one's is blue), its image *)
let show r w =
  sides (outer w) border (fun side ->
    fill screen (if current w then blue else pale) (clip r side));
  let c = clip r (inner w) in
  if not (empty c) then begin
    let x0, y0, _, _ = c in
    send
      (D.d_draw screen w.image (-1) c (x0 - w.x - border, y0 - w.y - border))
  end

(* a rectangle of the screen again: the background, the windows back to
 * front *)
let refresh r = fill screen grey r; List.iter (show r) (List.rev !windows)

(* a rectangle of a window's image changed: that part of the screen
 * again, from the window to the front (old: all of the window at each
 * change: a ball of 16 pixels moved was 80,000 copied, more than the
 * machine has between two moves) *)
let update w (x0, y0, x1, y1) =
  let r =
    clip (inner w)
      (x0 + w.x + border, y0 + w.y + border,
       x1 + w.x + border, y1 + w.y + border) in
  let rec upto l =
    match l with
    | [] -> []
    | v :: rest -> if v == w then [ v ] else v :: upto rest in
  if not (empty r) then List.iter (show r) (List.rev (upto !windows))

(* the smallest rectangle with both; one of no pixel is no part of it *)
let both a b =
  if empty a then b else if empty b then a
  else
    (let ax0, ay0, ax1, ay1 = a and bx0, by0, bx1, by1 = b in
     min ax0 bx0, min ay0 by0, max ax1 bx1, max ay1 by1)

(*****************************************************************************)
(* A window's text *)
(*****************************************************************************)

(* the cell where the next character goes: a bar under it, or none *)
let cursor w ink =
  fill w.image ink
    (w.page.col * 8, (w.page.row * 16) + 13,
     (w.page.col * 8) + 8, (w.page.row * 16) + 15)

(* the next line; at the bottom the image is drawn on itself a line up
 * (counted: what shows is then all of the window) *)
let scrolls = ref 0
let newline w =
  let last = ((w.h / 16) - 1) * 16 in
  w.page.col <- 0;
  if (w.page.row + 1) * 16 <= last then w.page.row <- w.page.row + 1
  else
    (incr scrolls;
     send (D.d_draw w.image w.image (-1) (0, 0, w.w, last) (0, 16));
     fill w.image white (0, last, w.w, w.h))

(* what a program printed: the characters that fit the line are one
 * text, on cells made white (old: a message a character, three seconds
 * for an ls). An ENQ (5) is a question: the window's size, posted in
 * its mouse box as a mouse at (width, height) with the buttons -1 *)
let print w s =
  let n = String.length s in
  let cells k =
    fill w.image white
      (w.page.col * 8, w.page.row * 16,
       (w.page.col + k) * 8, (w.page.row * 16) + 16) in
  let rec from i =
    if i < n then begin
      if s.[i] = '\n' then (newline w; from (i + 1))
      else if s.[i] = '\b' then
        (if w.page.col > 0 then (w.page.col <- w.page.col - 1; cells 1);
         from (i + 1))
      else if s.[i] = '\005' then
        (put w.ends.mouse
           (D.i16 w.w ^ D.i16 0 ^ D.i16 w.h ^ D.i16 0 ^ D.i16 (-1) ^ D.i16 (-1));
         from (i + 1))
      else begin
        if (w.page.col + 1) * 8 > w.w then newline w;
        let room = (w.w / 8) - w.page.col in
        let rec upto j =
          if j < n && j - i < room && s.[j] >= ' ' then upto (j + 1) else j in
        let j = max (i + 1) (upto i) in
        cells (j - i);
        send
          (D.d_text w.image black (w.page.col * 8, w.page.row * 16)
             (String.sub s i (j - i)));
        w.page.col <- w.page.col + j - i;
        from j
      end
    end
  in
  let row = w.page.row and before = !scrolls in
  cursor w white;
  from 0;
  cursor w black;
  w.page.picture <- false;
  (* the lines it went through; all of it if it scrolled *)
  if !scrolls <> before then update w (0, 0, w.w, w.h)
  else update w (0, row * 16, w.w, (w.page.row + 1) * 16)

(* a key for the window that has them: a picture's program gets it as
 * typed; a text's line is edited here and given whole (Control-D with
 * nothing typed is its input's end) *)
let key w c =
  let give s = if w.ends.keys_open then put w.ends.keys s in
  if w.page.picture then give (String.make 1 c)
  else if c = '\n' || c = '\r' then
    (print w "\n"; give (w.page.line ^ "\n"); w.page.line <- "")
  else if c = '\b' || c = '\127' then begin
    if w.page.line <> "" then
      (w.page.line <- String.sub w.page.line 0 (String.length w.page.line - 1);
       print w "\b")
  end
  else if c = '\004' then begin
    if w.page.line = "" then
      (if w.ends.keys_open then
         (w.ends.keys_open <- false; TSys.close w.ends.keys))
    else (give w.page.line; w.page.line <- "")
  end
  else if c >= ' ' then
    (w.page.line <- w.page.line ^ String.make 1 c; print w (String.make 1 c))

(*****************************************************************************)
(* A window's picture: its programs' messages, renumbered *)
(*****************************************************************************)

(* our number for one of the window's programs': 0 is the window's
 * image, -1 no mask; one they did not make is none of ours either, and
 * the kernel says so *)
let ours w k =
  if k = 0 then w.image
  else if k < 0 then k
  else
    (let rec find l =
       match l with
       | [] -> 32767
       | (theirs, mine) :: rest -> if theirs = k then mine else find rest in
     find w.page.ids)

(* the bytes read from its pipe, after those that were not a whole
 * message: each message sent on with our numbers (an image made gets
 * one, an image freed gives it back; the window's image is not theirs
 * to make or free). The window is a picture when one drew in it, and
 * what they changed of it, one rectangle around it all, is shown *)
let forward w s =
  let p = w.page.pending ^ s in
  let n = String.length p in
  let nothing = 0, 0, 0, 0 in
  let rec next i drew =
    if i >= n then i, drew
    else begin
      let ({ ds_length = len; ds_images = images } : D.message_shape) =
        D.d_shape p i in
      if len < 0 then n, drew
      else if i + len > n then i, drew
      else begin
        let letter = p.[i] and first = D.int16 p (i + 1) in
        if letter = 'a' && first > 0 && ours w first = 32767 then
          w.page.ids <- (first, fresh ()) :: w.page.ids;
        if letter = 'c' then begin
          w.page.cursor <- first; if current w then show_cursor first
        end
        else if first <> 0 || (letter <> 'a' && letter <> 'f') then begin
          send (String.make 1 letter);
          for k = 0 to images - 1 do
            send (D.i16 (ours w (D.int16 p (i + 1 + (2 * k)))))
          done;
          send (String.sub p (i + 1 + (2 * images)) (len - 1 - (2 * images)))
        end;
        if letter = 'f' then
          (release (ours w first);
           w.page.ids <-
             List.filter (fun (theirs, _) -> theirs <> first) w.page.ids);
        (* what it changed of the window: a draw's rectangle, a line's two
         * ends, a text's cells, a row of pixels *)
        let at k = D.int16 p (i + 1 + (2 * k)) in
        let changed =
          if first <> 0 then nothing
          else if letter = 'd' then at 3, at 4, at 5, at 6
          else if letter = 'l' then
            min (at 2) (at 4), min (at 3) (at 5),
            max (at 2) (at 4) + 1, max (at 3) (at 5) + 1
          else if letter = 's' then at 2, at 3, at 2 + (8 * at 4), at 3 + 16
          else if letter = 't' && at 5 land 16 <> 0 then
            at 2, at 3, at 2 + (4 * at 4), at 3 + 4
          else if letter = 't' then
            (let k = if at 5 land 8 <> 0 then 2 else 1 in
             at 2, at 3, at 2 + (8 * k * at 4) + (4 * k), at 3 + (16 * k))
          else if letter = 'p' then at 1, at 2, at 1 + at 3, at 2 + 1
          else nothing in
        next (i + len) (both drew changed)
      end
    end
  in
  let i, drew = next 0 nothing in
  w.page.pending <- String.sub p i (n - i);
  if not (empty drew) then (w.page.picture <- true; update w drew)

(*****************************************************************************)
(* Windows made, and ended *)
(*****************************************************************************)

(* where a window's corner goes: its inside at a multiple of 4 pixels
 * across, so that its rows and the screen's are at the same place in a
 * word, which the kernel then copies a word at a time *)
let snap x = x - ((x + border) land 3)

(* a window of that rectangle of the screen, a shell in it: three pipes
 * and a box, the shell given an end of each as its 0, its 1 and 2, its
 * 3 and its 4. Its inside is whole characters, 8 by 16. No window
 * when the kernel has no pipe or no process left *)
let create (caps : < Cap.pipe; Cap.fork; Cap.exec; .. >) (x0, y0, x1, y1) =
  let made make = try Some (make caps) with Failure _ -> None in
  let k = made TSys.pipe and p = made TSys.pipe and d = made TSys.pipe
  and m = made TSys.box in
  let closed e = match e with Some (r, w) -> TSys.close r; TSys.close w
    | None -> () in
  match k, p, d, m with
  | Some (kr, kw), Some (pr, pw), Some (dr, dw), Some (mr, mw) -> (
      match (try Some (TSys.fork caps) with Failure _ -> None) with
      | None -> List.iter closed [ k; p; d; m ]
      | Some None ->
          (* the shell: the window's ends its 0 to 4, the others (ours,
           * the other windows') TinyLibSystem's, closed by exec *)
          TSys.dup2 kr TSys.fd_stdin;
          TSys.dup2 pw TSys.fd_stdout;
          TSys.dup2 pw TSys.fd_stderr;
          TSys.dup2 dw TSys.fd_draw;
          TSys.dup2 mr TSys.fd_mouse;
          ignore (TSys.exec caps (Fpath.v "/bin/sh") [ "/bin/sh" ] []);
          (* the child's end, out of our code: its status by
           * TinyLibSystem.main *)
          raise (Exit.ExitCode 1)
      | Some (Some pid) ->
          (* the shell's ends are not ours *)
          List.iter TSys.close [ kr; pw; dw; mr ];
          let ends =
            { keys = kw; keys_open = true; prints = pr; draws = dr;
              mouse = mw } in
          let page =
            { pending = ""; ids = []; picture = false; col = 0; row = 0;
              line = ""; cursor = 0 } in
          let wide = (x1 - x0 - (2 * border)) / 8 * 8
          and high = (y1 - y0 - (2 * border)) / 16 * 16 in
          let w =
            { image = fresh (); w = wide; h = high; x = snap x0; y = y0;
              pid = pid; ends = ends; page = page } in
          send (D.d_image w.image (0, 0, w.w, w.h) 255);
          windows := w :: !windows;
          refresh everything)
  | _ -> List.iter closed [ k; p; d; m ]

(* its ends closed, its shell ended, its images freed *)
let delete (caps : < Cap.kill; Cap.wait; .. >) w =
  List.iter TSys.close [ w.ends.prints; w.ends.draws; w.ends.mouse ];
  if w.ends.keys_open then TSys.close w.ends.keys;
  ignore (TSys.kill caps w.pid);
  ignore (TSys.wait caps w.pid);
  List.iter (fun (_, mine) -> send (D.d_free mine); release mine) w.page.ids;
  send (D.d_free w.image);
  release w.image;
  windows := List.filter (fun v -> v != w) !windows;
  refresh everything

(*****************************************************************************)
(* The mouse *)
(*****************************************************************************)

(* the menu's items, from the top *)
type item =
  | Item_new
  | Item_move
  | Item_delete
  | Item_exit

(* what the mouse is doing: nothing; in the menu (its corner, the item
 * under the mouse, if any); an item chosen, the left button awaited; a
 * rectangle swept (its first corner, the last one drawn); a window
 * dragged (the mouse in it, its last place drawn) *)
type doing =
  | Idle
  | Menu of int * int * item option
  | Chosen of item
  | Sweep of int * int * int * int
  | Drag of window * int * int * int * int
  (* the menu's Exit chosen, the windows deleted: the loop's end *)
  | Ended

let doing = ref Idle
let buttons = ref 0

let items =
  [ Item_new, "New"; Item_move, "Move"; Item_delete, "Delete";
    Item_exit, "Exit" ]
let menu_box mx my = mx - 1, my - 1, mx + 65, my + 65

(* the menu at (mx, my), the item chosen lit *)
let menu mx my (chosen : item option) =
  fill screen black (menu_box mx my);
  List.iteri (fun i (item, name) ->
    let lit = chosen = Some item in
    fill screen (if lit then blue else white)
      (mx, my + (16 * i), mx + 64, my + (16 * i) + 16);
    send
      (D.d_text screen (if lit then white else black)
         (mx + 4, my + (16 * i)) name)) items

(* a rectangle's four sides, two pixels thick: drawn in red, or what is
 * under them again *)
let outline r = sides r 2 (fill screen red)
let erase r = sides r 2 refresh

let corners xa ya xb yb = min xa xb, min ya yb, max xa xb, max ya yb
let rec over x y l =
  match l with
  | [] -> None
  | w :: rest -> if inside (outer w) x y then Some w else over x y rest
let word v = D.i16 v ^ D.i16 (v asr 16)

let finish caps = List.iter (delete caps) !windows; flush (); doing := Ended

(* the mouse at (x, y), its buttons b (1 left, 4 right) *)
let mouse caps x y b =
  (match !doing, over x y !windows with
   | Idle, Some w when current w && inside (inner w) x y ->
       show_cursor w.page.cursor
   | _ -> show_cursor 0);
  let left = b land 1 <> 0 && !buttons land 1 = 0
  and right = b land 4 <> 0 && !buttons land 4 = 0 in
  buttons := b;
  match !doing with
  | Idle -> (
      match over x y !windows with
      | Some w when current w && w.page.picture && inside (inner w) x y ->
          put w.ends.mouse
            (word (x - w.x - border) ^ word (y - w.y - border) ^ word b)
      | _ when right -> doing := Menu (x, y, None); menu x y None
      | Some w when left && not (current w) ->
          windows := w :: List.filter (fun v -> v != w) !windows;
          refresh everything
      | _ -> ())
  | Menu (mx, my, was) ->
      let item =
        if inside (mx, my, mx + 64, my + 64) x y then
          Option.map fst (List.nth_opt items ((y - my) / 16))
        else None in
      if b land 4 <> 0 then
        (if item <> was then (doing := Menu (mx, my, item); menu mx my item))
      else begin
        refresh (menu_box mx my);
        match item with
        | Some Item_exit -> finish caps
        | Some item -> doing := Chosen item
        | None -> doing := Idle
      end
  | Chosen item ->
      if right then doing := Idle
      else if left then begin
        match item, over x y !windows with
        | Item_new, _ -> doing := Sweep (x, y, x, y)
        | Item_move, Some w -> doing := Drag (w, x - w.x, y - w.y, w.x, w.y)
        | Item_delete, Some w -> doing := Idle; delete caps w
        | _ -> doing := Idle
      end
  | Sweep (sx, sy, lx, ly) ->
      erase (corners sx sy lx ly);
      if b land 1 <> 0 then
        (doing := Sweep (sx, sy, x, y); outline (corners sx sy x y))
      else begin
        doing := Idle;
        let x0, y0, x1, y1 = corners sx sy x y in
        if x1 - x0 >= 64 && y1 - y0 >= 48 then create caps (x0, y0, x1, y1)
      end
  | Drag (w, gx, gy, lx, ly) ->
      let size = w.w + (2 * border), w.h + (2 * border) in
      erase (lx, ly, lx + fst size, ly + snd size);
      if b land 1 <> 0 then
        (doing := Drag (w, gx, gy, x - gx, y - gy);
         outline (x - gx, y - gy, x - gx + fst size, y - gy + snd size))
      else
        (doing := Idle; w.x <- snap (x - gx); w.y <- y - gy; refresh everything)
  | Ended -> ()

(*****************************************************************************)
(* The loop *)
(*****************************************************************************)

(* whatever can be read first: the mouse (a word each: x, y, the
 * buttons), the keys, what a window's programs draw or print (the
 * kernel gives the first ready of those asked about: what a program
 * drew before it ended is drawn before the shell's prompt after it,
 * which would be drawn over and the window left a picture). The end
 * of the keys is ours, as the mouse's and the menu's Exit; the end of a
 * window's pipes (its shell and its programs gone) is the window's. Our
 * end is the loop's return. The kernel asked about 31 descriptors at
 * most: the windows past the 14th not read until one in front of them
 * ends *)
let rec loop caps =
  flush ();
  let rec theirs n ws =
    match ws with
    | w :: rest when n < 31 -> w.ends.draws :: w.ends.prints :: theirs (n + 2) rest
    | _ -> [] in
  let fds = TSys.fd_mouse :: TSys.fd_stdin :: theirs 2 !windows in
  let more =
    match TSys.ready fds None with
    | None -> true
    | Some fd when fd = TSys.fd_mouse ->
      let s = TSys.read fd 12 in
      if String.length s < 12 then false
      else begin
        mouse caps (D.int16 s 0) (D.int16 s 4) (D.int16 s 8);
        match !doing with Ended -> false | _ -> true
      end
    | Some fd when fd = TSys.fd_stdin ->
      let s = TSys.read fd 256 in
      if s = "" then false
      else begin
        for i = 0 to String.length s - 1 do
          match !windows with w :: _ -> key w s.[i] | [] -> ()
        done;
        true
      end
    | Some fd ->
      List.iter (fun w ->
        if fd = w.ends.prints || fd = w.ends.draws then begin
          let s = TSys.read fd 512 in
          if s = "" then delete caps w
          else if fd = w.ends.prints then print w s
          else forward w s
        end) !windows;
      true in
  if more then loop caps

(*****************************************************************************)
(* The main *)
(*****************************************************************************)

let main (caps : < Cap.pipe; Cap.forkew; Cap.kill; .. >) (_ : string array) =
  send
    (D.d_colour grey 0xaa ^ D.d_colour white 255 ^ D.d_colour black 0
     ^ D.d_colour blue 0x36 ^ D.d_colour pale 0x99 ^ D.d_colour red 0xf0);
  refresh everything;
  loop caps;
  Exit.OK
