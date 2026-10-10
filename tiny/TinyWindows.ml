(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* A tiny window system, a program of TinyKernel.ml's, in ML: the
 * essential of Plan 9's rio (ix's twin is windows/, mini-rio). Compiled
 * by tiny-ml -tm after TinyDraw.ml, TinyKernel/user/mlsys.c its runtime
 * and its system calls (plan_tiny_windows.md):
 *
 *     ./tiny-machine -window tiny-kernel
 *     $ tiny-windows
 *     the right button: New, then a rectangle swept with the left one;
 *     in the window, a shell: ls, paint, tiny-windows
 *
 * The idea kept is rio's: {b a window looks like the machine}. A
 * program of TinyKernel.ml is given five descriptors: 0, 1 and 2 its
 * text, 3 where it draws (TinyGraphics.ml's messages), 4 its mouse. The
 * kernel gives the first shell the console, the screen and the mouse;
 * tiny-windows gives each window's shell three pipes and a box, and is
 * itself a program that reads its 0 and its 4 and draws on its 3. So a
 * program does not know whether it has the screen or a window, and
 * tiny-windows runs in one of its own windows unchanged.
 *
 *            the console        the screen        the mouse
 *     (or, in a window, what the window system above gives for them)
 *                | 0                 ^ 3               | 4
 *                v                   |                 v
 *          +------------------ tiny-windows ------------------+
 *          | the keys to the     every window's     the mouse  |
 *          | front window, a     messages, their    in a       |
 *          | line at the Enter   images renumbered  window     |
 *          +----|-------------^-----------^-------------|------+
 *               | a pipe      | a pipe    | a pipe      | a box
 *               v 0           | 1, 2      | 3           v 4
 *          +----------------- a window's shell ----------------+
 *          | sh, and what it runs: ls, paint, tetris,          |
 *          | tiny-windows                                      |
 *          +---------------------------------------------------+
 *
 * (one such column of four for each window). What goes up the third
 * pipe, for a program that makes a red image and fills its window
 * with it, and what tiny-windows writes on its own 3:
 *
 *     the program:       a 1 ... red          d 0 1 none, the window
 *     tiny-windows:      a 17 ... red         d 16 17 none, the same
 *                        then, for what changed on the screen:
 *                        d 0 16 none, where the window is
 *
 * 16 being the image it made for that window and 17 the first number
 * it had free. Run in a window of another tiny-windows, its 0 and its
 * 16 and 17 are renumbered again by the one above, and only the
 * outermost 0 is the kernel's screen.
 *
 * How, each the cheapest that keeps the idea:
 *
 * - {b The kernel has every pixel.} A window is an image off the
 *   screen, made by a message; tiny-windows has its number, never its
 *   bytes. What shows is composed: the windows drawn on the screen
 *   back to front, clipped to the rectangle that changed (no layers:
 *   mini-9pi's Memlayer keeps what is hidden apart; here nothing is).
 * - {b Forwarding is renumbering.} A window's program names its images
 *   by numbers of its own, 0 its window. tiny-windows reads its
 *   messages from a pipe, gives each number one of its own (0 is the
 *   window's image) and sends the message on, to its own 3. A window
 *   system in a window is renumbered twice.
 * - {b One loop.} ready, the kernel's call, waits for the mouse, the
 *   keys and every window's two pipes at once: rio has a thread a
 *   window and channels for it.
 * - {b A window is a text or a picture.} What its programs print is
 *   drawn in it, a character a cell, scrolled at the bottom; the keys
 *   are then a line, edited here and given at the Enter. When a
 *   program draws in it, the window is its picture: each key is given
 *   as typed, and the mouse in it is the program's, until something
 *   is printed again (the shell's prompt, after the program's end).
 * - {b A mouse is a box}: where it is in the window, written to the
 *   kernel's kind of pipe that keeps the last write only, so that a
 *   program that does not read its mouse stops nothing.
 *
 * The mouse: the left button on a window brings it to the front, where
 * it has the keys; the right button is the menu (New, Move, Delete,
 * Exit), then the left one says where: a rectangle swept, a window
 * dragged, a window pointed at.
 *
 * Dropped: a window's own menu, its scroll bar and its text kept (what
 * left the top is gone), selecting, snarf and paste, Resize and Hide,
 * the cursor's shapes, a border as a handle, a window's name and the
 * files it serves (rio is a file server: here descriptors are given,
 * TinyKernel.ml having no name space).
 *
 * Exercises:
 * - Resize: a new image, the old one drawn in it, freed;
 * - the text kept and a scroll bar; a selection, snarf and paste;
 * - the window's size told to its program (a message read on its 4);
 * - a program started by New other than the shell (an argument).
 *
 * Where it stands: TinyKernel gives the five descriptors, the pipes,
 * the box and ready; TinyGraphics, in the kernel, has the images;
 * TinyDraw makes and reads the messages; the programs in a window
 * (TinyKernel/user's paint in C, TinyTetris on TinyPlayground) are the
 * ones that run without it. mini-rio is the whole of it: Wm and
 * Window, a window's text as a Terminal, and Fileserver, Virtual_cons
 * and Virtual_mouse for what a window's program opens.
 *
 * cs-history:
 * The idea is the Blit's (Rob Pike, Bell Labs, 1982): its window
 * system, mpx, was called a multiplexer because that is all it did,
 * give each window a terminal like the one the whole screen had
 * been, so that a program written for a terminal ran in a window
 * knowing nothing. Pike's 8 1/2 for Plan 9 (1991) kept the idea and
 * found its form: the window system is a file server, and what it
 * serves each window, /dev/cons, /dev/mouse and the screen's files,
 * are the names of what the kernel serves it. rio (2000) is 8 1/2
 * rewritten with threads. A window system run in its own window is
 * the test of the idea, and all three pass it.
 *
 * plan9-is-cleaner:
 * In X a program does not draw on something it was given: it
 * connects to a server by a socket and speaks a protocol of about
 * a hundred and twenty requests; which window is where is decided by
 * a third program, the window manager, by rules of its own; and a
 * server run inside a window is a special server (Xnest, Xephyr),
 * written for that. Here, as in rio, there is no protocol to speak
 * of and no manager apart, since what a window's program sees is
 * the kernel's own interface, and nesting needs no code.
 *
 * modern:
 * Each window an image off the screen, and the screen composed from
 * them back to front, is what window systems came to when memory
 * and graphics processors allowed (Mac OS X's Quartz, 2001; the
 * compositors of X; Wayland, where it is the only way): a window
 * moved or uncovered is copied again, never asked to redraw. The
 * systems before drew a window where it shows, on the screen itself,
 * and dealt with the rest apart: layers that save the hidden parts
 * (rio), or a message telling a program which part of its window
 * was uncovered (X). The old way saves memory; the new one made
 * shadows, transparency and smooth moves nearly free.
 *
 * References (from memory): R. Pike, "The Blit: A Multiplexed Graphics
 * Terminal" (1984), "8½, the Plan 9 Window System" (1991) and "Rio:
 * Design of a Concurrent Window System" (2000): a window system as a
 * multiplexer that gives what it takes; N. Wirth and J. Gutknecht,
 * "Project Oberon" (1992), the other road, windows in the system. *)

open TinyDraw

(* TinyKernel/user/mlsys.c's: the kernel's calls. A read's string is ""
 * at the end; a pipe's or a box's two ends are one number (the reading
 * one, and 256 times the writing one) *)
external u_read : int -> int -> string = "u_read"
external u_write : int -> string -> int = "u_write"
external u_pipe : unit -> int = "u_pipe"
external u_box : unit -> int = "u_box"
external u_close : int -> int = "u_close"
external u_ready : int array -> int -> int -> int = "u_ready"
external u_spawn : int -> int -> int -> int -> string -> int = "u_spawn"
external u_kill : int -> int = "u_kill"
external u_wait : unit -> int = "u_wait"

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
let flush () = if !gathered <> "" then (ignore (u_write 3 !gathered); gathered := "")
let send m = gathered := !gathered ^ m; if String.length !gathered > 1024 then flush ()

(* the numbers in use; the lowest free one *)
let used = ref []
let fresh () =
  let rec from n = if List.mem n !used then from (n + 1) else n in
  let n = from 16 in
  used := n :: !used;
  n
let release n = used := List.filter (fun k -> k <> n) !used

(* a rectangle is its two corners; what two have in common; one of no pixel *)
let clip (ax0, ay0, ax1, ay1) (bx0, by0, bx1, by1) = max ax0 bx0, max ay0 by0, min ax1 bx1, min ay1 by1
let empty (x0, y0, x1, y1) = x1 <= x0 || y1 <= y0
let inside (x0, y0, x1, y1) x y = x >= x0 && x < x1 && y >= y0 && y < y1
let fill dst colour r = if not (empty r) then (let x0, y0, x1, y1 = r in send (d_fill dst colour x0 y0 x1 y1))
let everything = 0, 0, 640, 480

(*****************************************************************************)
(* Windows *)
(*****************************************************************************)

(* A window. Our ends of what its shell was given: its keys, what it
 * prints, what it draws, its mouse *)
type ends = { keys : int; mutable keys_open : bool; prints : int; draws : int; mouse : int }

(* what is in it: the drawn bytes that are not a whole message yet; its
 * programs' numbers for their images, and ours; whether it is a
 * picture; where the next character goes, and the line typed so far *)
type page = {
  mutable pending : string; mutable ids : (int * int) list; mutable picture : bool;
  mutable col : int; mutable row : int; mutable line : string;
}

(* its image (w by h pixels) and where its border's corner is on the
 * screen; its shell's pid. (Three records: tiny-ml -tm makes one of
 * nine fields at most, an expression being 11 registers deep.) *)
type window = { image : int; w : int; h : int; mutable x : int; mutable y : int; pid : int; ends : ends; page : page }

(* the front one first: it has the keys *)
let windows = ref []
let current w = match !windows with v :: _ -> v == w | [] -> false

let border = 3
let outer w = w.x, w.y, w.x + w.w + (2 * border), w.y + w.h + (2 * border)
let inner w = w.x + border, w.y + border, w.x + border + w.w, w.y + border + w.h

(* a rectangle's four sides, so many pixels thick, each given to f *)
let sides (x0, y0, x1, y1) t f = f (x0, y0, x1, y0 + t); f (x0, y1 - t, x1, y1); f (x0, y0, x0 + t, y1); f (x1 - t, y0, x1, y1)

(* a window's part in a rectangle of the screen: its border (the
 * current one's is blue), its image *)
let show r w =
  sides (outer w) border (fun side -> fill screen (if current w then blue else pale) (clip r side));
  let c = clip r (inner w) in
  if not (empty c) then begin
    let x0, y0, x1, y1 = c in
    send (d_draw screen w.image (-1) x0 y0 x1 y1 (x0 - w.x - border) (y0 - w.y - border))
  end

(* a rectangle of the screen again: the background, the windows back to front *)
let refresh r = fill screen grey r; List.iter (show r) (List.rev !windows)

(* a rectangle of a window's image changed: that part of the screen
 * again, from the window to the front (old: all of the window at each
 * change: a ball of 16 pixels moved was 80,000 copied, more than the
 * machine has between two moves) *)
let update w (x0, y0, x1, y1) =
  let r = clip (inner w) (x0 + w.x + border, y0 + w.y + border, x1 + w.x + border, y1 + w.y + border) in
  let rec upto l = match l with [] -> [] | v :: rest -> if v == w then [ v ] else v :: upto rest in
  if not (empty r) then List.iter (show r) (List.rev (upto !windows))

(* the smallest rectangle with both; one of no pixel is no part of it *)
let both a b =
  if empty a then b else if empty b then a
  else (let ax0, ay0, ax1, ay1 = a and bx0, by0, bx1, by1 = b in min ax0 bx0, min ay0 by0, max ax1 bx1, max ay1 by1)

(*****************************************************************************)
(* A window's text *)
(*****************************************************************************)

(* the cell where the next character goes: a bar under it, or none *)
let cursor w ink = fill w.image ink (w.page.col * 8, (w.page.row * 16) + 13, (w.page.col * 8) + 8, (w.page.row * 16) + 15)

(* the next line; at the bottom the image is drawn on itself a line up
 * (counted: what shows is then all of the window) *)
let scrolls = ref 0
let newline w =
  let last = ((w.h / 16) - 1) * 16 in
  w.page.col <- 0;
  if (w.page.row + 1) * 16 <= last then w.page.row <- w.page.row + 1
  else (incr scrolls; send (d_draw w.image w.image (-1) 0 0 w.w last 0 16); fill w.image white (0, last, w.w, w.h))

(* what a program printed: the characters that fit the line are one
 * text, on cells made white (old: a message a character, three seconds
 * for an ls) *)
let print w s =
  let n = String.length s in
  let cells k = fill w.image white (w.page.col * 8, w.page.row * 16, (w.page.col + k) * 8, (w.page.row * 16) + 16) in
  let rec from i =
    if i < n then begin
      if s.[i] = '\n' then (newline w; from (i + 1))
      else if s.[i] = '\b' then (if w.page.col > 0 then (w.page.col <- w.page.col - 1; cells 1); from (i + 1))
      else begin
        if (w.page.col + 1) * 8 > w.w then newline w;
        let room = (w.w / 8) - w.page.col in
        let rec upto j = if j < n && j - i < room && s.[j] >= ' ' then upto (j + 1) else j in
        let j = max (i + 1) (upto i) in
        cells (j - i);
        send (d_text w.image black (w.page.col * 8) (w.page.row * 16) (String.sub s i (j - i)));
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
  if !scrolls <> before then update w (0, 0, w.w, w.h) else update w (0, row * 16, w.w, (w.page.row + 1) * 16)

(* a key for the window that has them: a picture's program gets it as
 * typed; a text's line is edited here and given whole (Control-D with
 * nothing typed is its input's end) *)
let key w c =
  let give s = if w.ends.keys_open then ignore (u_write w.ends.keys s) in
  if w.page.picture then give (String.make 1 c)
  else if c = '\n' || c = '\r' then (print w "\n"; give (w.page.line ^ "\n"); w.page.line <- "")
  else if c = '\b' || c = '\127' then begin
    if w.page.line <> "" then (w.page.line <- String.sub w.page.line 0 (String.length w.page.line - 1); print w "\b")
  end
  else if c = '\004' then begin
    if w.page.line = "" then (if w.ends.keys_open then (w.ends.keys_open <- false; ignore (u_close w.ends.keys))) else (give w.page.line; w.page.line <- "")
  end
  else if c >= ' ' then (w.page.line <- w.page.line ^ String.make 1 c; print w (String.make 1 c))

(*****************************************************************************)
(* A window's picture: its programs' messages, renumbered *)
(*****************************************************************************)

(* our number for one of the window's programs': 0 is the window's
 * image, -1 no mask; one they did not make is none of ours either, and
 * the kernel says so *)
let ours w k =
  if k = 0 then w.image
  else if k < 0 then k
  else (let rec find l = match l with [] -> 32767 | (theirs, mine) :: rest -> if theirs = k then mine else find rest in find w.page.ids)

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
      let len, images = d_shape p i in
      if len < 0 then n, drew
      else if i + len > n then i, drew
      else begin
        let letter = p.[i] and first = int16 p (i + 1) in
        if letter = 'a' && first > 0 && ours w first = 32767 then w.page.ids <- (first, fresh ()) :: w.page.ids;
        if first <> 0 || (letter <> 'a' && letter <> 'f') then begin
          send (String.make 1 letter);
          for k = 0 to images - 1 do send (i16 (ours w (int16 p (i + 1 + (2 * k))))) done;
          send (String.sub p (i + 1 + (2 * images)) (len - 1 - (2 * images)))
        end;
        if letter = 'f' then (release (ours w first); w.page.ids <- List.filter (fun (theirs, _) -> theirs <> first) w.page.ids);
        (* what it changed of the window: a draw's rectangle, a line's two ends, a text's cells *)
        let at k = int16 p (i + 1 + (2 * k)) in
        let changed =
          if first <> 0 then nothing
          else if letter = 'd' then at 3, at 4, at 5, at 6
          else if letter = 'l' then min (at 2) (at 4), min (at 3) (at 5), max (at 2) (at 4) + 1, max (at 3) (at 5) + 1
          else if letter = 's' then at 2, at 3, at 2 + (8 * at 4), at 3 + 16
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
 * 3 and its 4. Its inside is whole characters, 8 by 16 *)
let create (x0, y0, x1, y1) =
  let k = u_pipe () and p = u_pipe () and d = u_pipe () and m = u_box () in
  let pid = if k < 0 || p < 0 || d < 0 || m < 0 then -1 else u_spawn (k land 255) (p / 256) (d / 256) (m land 255) "/sh" in
  (* the shell's ends are not ours; ours neither when there is no shell *)
  List.iter (fun fd -> if fd >= 0 then ignore (u_close fd)) [ k land 255; p / 256; d / 256; m land 255 ];
  if pid < 0 then List.iter (fun fd -> if fd >= 0 then ignore (u_close fd)) [ k / 256; p land 255; d land 255; m / 256 ]
  else begin
    let ends = { keys = k / 256; keys_open = true; prints = p land 255; draws = d land 255; mouse = m / 256 } in
    let page = { pending = ""; ids = []; picture = false; col = 0; row = 0; line = "" } in
    let wide = (x1 - x0 - (2 * border)) / 8 * 8 and high = (y1 - y0 - (2 * border)) / 16 * 16 in
    let w = { image = fresh (); w = wide; h = high; x = snap x0; y = y0; pid = pid; ends = ends; page = page } in
    send (d_image w.image 0 0 w.w w.h 255);
    windows := w :: !windows;
    refresh everything
  end

(* its ends closed, its shell ended, its images freed *)
let delete w =
  List.iter (fun fd -> ignore (u_close fd)) [ w.ends.prints; w.ends.draws; w.ends.mouse ];
  if w.ends.keys_open then ignore (u_close w.ends.keys);
  ignore (u_kill w.pid);
  ignore (u_wait ());
  List.iter (fun (_, mine) -> send (d_free mine); release mine) w.page.ids;
  send (d_free w.image);
  release w.image;
  windows := List.filter (fun v -> v != w) !windows;
  refresh everything

(*****************************************************************************)
(* The mouse *)
(*****************************************************************************)

(* what the mouse is doing: nothing; in the menu (its corner, the item
 * under the mouse); an item chosen, the left button awaited; a
 * rectangle swept (its first corner, the last one drawn); a window
 * dragged (the mouse in it, its last place drawn) *)
type doing = Idle | Menu of int * int * int | Chosen of int | Sweep of int * int * int * int | Drag of window * int * int * int * int

let doing = ref Idle
let buttons = ref 0

let items = [ "New"; "Move"; "Delete"; "Exit" ]
let menu_box mx my = mx - 1, my - 1, mx + 65, my + 65

let menu mx my chosen =
  fill screen black (menu_box mx my);
  List.iteri (fun i name ->
    fill screen (if i = chosen then blue else white) (mx, my + (16 * i), mx + 64, my + (16 * i) + 16);
    send (d_text screen (if i = chosen then white else black) (mx + 4) (my + (16 * i)) name)) items

(* a rectangle's four sides, two pixels thick: drawn in red, or what is under them again *)
let outline r = sides r 2 (fill screen red)
let erase r = sides r 2 refresh

let corners xa ya xb yb = min xa xb, min ya yb, max xa xb, max ya yb
let rec over x y l = match l with [] -> None | w :: rest -> if inside (outer w) x y then Some w else over x y rest
let word v = i16 v ^ i16 (v asr 16)

let finish () = List.iter delete !windows; flush (); exit 0

(* the mouse at (x, y), its buttons b (1 left, 4 right) *)
let mouse x y b =
  let left = b land 1 <> 0 && !buttons land 1 = 0 and right = b land 4 <> 0 && !buttons land 4 = 0 in
  buttons := b;
  match !doing with
  | Idle -> (
      match over x y !windows with
      | Some w when current w && w.page.picture && inside (inner w) x y ->
          ignore (u_write w.ends.mouse (word (x - w.x - border) ^ word (y - w.y - border) ^ word b))
      | _ when right -> doing := Menu (x, y, -1); menu x y (-1)
      | Some w when left && not (current w) -> windows := w :: List.filter (fun v -> v != w) !windows; refresh everything
      | _ -> ())
  | Menu (mx, my, was) ->
      let item = if inside (mx, my, mx + 64, my + 64) x y then (y - my) / 16 else -1 in
      if b land 4 <> 0 then (if item <> was then (doing := Menu (mx, my, item); menu mx my item))
      else begin
        refresh (menu_box mx my);
        if item = 3 then finish ();
        doing := if item >= 0 then Chosen item else Idle
      end
  | Chosen item ->
      if right then doing := Idle
      else if left then begin
        match item, over x y !windows with
        | 0, _ -> doing := Sweep (x, y, x, y)
        | 1, Some w -> doing := Drag (w, x - w.x, y - w.y, w.x, w.y)
        | 2, Some w -> doing := Idle; delete w
        | _ -> doing := Idle
      end
  | Sweep (sx, sy, lx, ly) ->
      erase (corners sx sy lx ly);
      if b land 1 <> 0 then (doing := Sweep (sx, sy, x, y); outline (corners sx sy x y))
      else begin
        doing := Idle;
        let x0, y0, x1, y1 = corners sx sy x y in
        if x1 - x0 >= 64 && y1 - y0 >= 48 then create (x0, y0, x1, y1)
      end
  | Drag (w, gx, gy, lx, ly) ->
      let size = w.w + (2 * border), w.h + (2 * border) in
      erase (lx, ly, lx + fst size, ly + snd size);
      if b land 1 <> 0 then (doing := Drag (w, gx, gy, x - gx, y - gy); outline (x - gx, y - gy, x - gx + fst size, y - gy + snd size))
      else (doing := Idle; w.x <- snap (x - gx); w.y <- y - gy; refresh everything)

(*****************************************************************************)
(* The loop *)
(*****************************************************************************)

(* whatever can be read first: the mouse (a word each: x, y, the
 * buttons), the keys, what a window's programs print or draw. The end
 * of the keys is ours; the end of a window's pipes (its shell and its
 * programs gone) is the window's *)
let rec loop () =
  flush ();
  let fds = Array.make 32 0 and n = ref 2 in
  fds.(0) <- 4;
  List.iter (fun w -> if !n < 31 then (fds.(!n) <- w.ends.prints; fds.(!n + 1) <- w.ends.draws; n := !n + 2)) !windows;
  let fd = u_ready fds !n 0 in
  if fd = 4 then begin
    let s = u_read 4 12 in
    if String.length s < 12 then exit 0;
    mouse (int16 s 0) (int16 s 4) (int16 s 8)
  end
  else if fd = 0 then begin
    let s = u_read 0 256 in
    if s = "" then exit 0;
    for i = 0 to String.length s - 1 do match !windows with w :: _ -> key w s.[i] | [] -> () done
  end
  else
    List.iter (fun w ->
      if fd = w.ends.prints || fd = w.ends.draws then begin
        let s = u_read fd 512 in
        if s = "" then delete w else if fd = w.ends.prints then print w s else forward w s
      end) !windows;
  loop ()

let () =
  send (d_colour grey 0xaa ^ d_colour white 255 ^ d_colour black 0 ^ d_colour blue 0x36 ^ d_colour pale 0x99 ^ d_colour red 0xf0);
  refresh everything;
  loop ()
