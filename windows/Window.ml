(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Window.mli *)

(* (the two types are Window.mli's: said once, there) *)
type message = [%mli]
type t = [%mli]

let width = 4      (* the border's, as rio's *)

let pointer : Mouse.state ref = ref { Mouse.pos = Point.zero; buttons = 0; msec = 0; resized = false }

(* (a window's image has another name when it is another image: its number) *)
let name (w : t) = Printf.sprintf "window.%d.%d.%d" (Unix.getpid ()) w.id w.image.id
(* the text's rectangle: inside the border, and 2 pixels more *)
let text_r (w : t) = Rectangle.inset w.image.r (width + 2)
let in_bar (w : t) (p : Point.t) = Terminal.in_bar (text_r w) p
let on_border (w : t) (p : Point.t) = Rectangle.contains w.image.r p && not (Rectangle.contains (Rectangle.inset w.image.r width) p)

let text (w : t) = Terminal.contents w.text
let note : (t -> string -> unit) ref = ref (fun _ _ -> ())

let send (w : t) m = Event.sync (Event.send w.inbox m)

(* The thread: the window's state is its variables. *)
let run (w : t) desk =
  let d = w.image.display in
  (* the line being typed; the lines typed and not read, and what a read
   * left of one; the reads that wait for a line *)
  let typing = Buffer.create 80 and lines = Queue.create () and rest = ref "" and readers = Queue.create () in
  (* a program that draws here: the keys as they come; the mouse's last
   * change not read yet, the reads that wait for one *)
  let raw = ref false and moved = ref None and mouse_readers = Queue.create () in
  (* (its window changed, and it was not told yet: its next mouse read says r) *)
  let reshaped = ref false in
  (* the keys held: the kernel's messages for a program that reads the
   * window's kbd file (a game), kept until read; the reads that wait *)
  let held = Queue.create () and held_readers = Queue.create () and reads_held = ref false in
  let rec serve_held () =
    if not (Queue.is_empty held) && not (Queue.is_empty held_readers) then begin
      if (Queue.take held_readers) (Queue.peek held) then ignore (Queue.take held);
      serve_held ()
    end in
  (* the border: a blue for the window that has the keyboard, pale for
   * the others (ix's colours: rio's are a grey green and a pale one) *)
  let border current_ =
    w.current <- current_;
    let c = Display.color d (if current_ then Display.rgb 0x33 0x66 0x99 else Display.rgb 0xb8 0xcc 0xe0) in
    Draw.border w.image w.image.r width c;
    Display.free c in
  (* a read that waits answered by a line (what it does not take of it is the next read's) *)
  let rec serve () =
    if not (Queue.is_empty readers) && (!rest <> "" || not (Queue.is_empty lines)) then begin
      let reply, count = Queue.take readers in
      let line = if !rest <> "" then !rest else Queue.peek lines in
      let n = min count (String.length line) in
      (* (a reader that is gone, its program ended with its read waiting,
       * takes nothing: the line is the next reader's) *)
      if reply (String.sub line 0 n) then begin
        if !rest = "" then ignore (Queue.take lines);
        rest := String.sub line n (String.length line - n)
      end;
      serve ()
    end in
  (* /dev/mouse's line: m, then four numbers of 12 characters *)
  let serve_mouse () =
    match !moved with
    | Some (m : Mouse.state) when not (Queue.is_empty mouse_readers) ->
        moved := None;
        let letter = if !reshaped then 'r' else 'm' in
        reshaped := false;
        ignore ((Queue.take mouse_readers) (Printf.sprintf "%c%11d %11d %11d %11d " letter m.pos.x m.pos.y m.buttons m.msec))
    | _ -> () in
  (* a key typed: shown, and kept until Enter makes the line (Backspace
   * takes one back, Ctrl-U all, Ctrl-D ends the input) *)
  (* (a character is its bytes: the last one typed is taken back whole) *)
  let back () =
    let s = Buffer.contents typing in
    Buffer.truncate typing (String.length (Utf8.sub s 0 (Utf8.length s - 1))); Terminal.erase w.text in
  let key k =
    match k.[0] with
    | '\n' | '\r' -> Terminal.put w.text "\n"; Queue.add (Buffer.contents typing ^ "\n") lines; Buffer.clear typing
    | '\b' -> if Buffer.length typing > 0 then back ()
    | '\021' -> while Buffer.length typing > 0 do back () done
    | '\004' -> Queue.add (Buffer.contents typing) lines; Buffer.clear typing
    | '\127' -> !note w "interrupt"      (* Delete: its processes interrupted *)
    (* (not the keyboard's own keys, Plan 9's runes from 0xF000: Home, Insert...) *)
    | c when c >= ' ' && not (let n = Utf8.code k in n >= 0xF000 && n < 0xF900) -> Buffer.add_string typing k; Terminal.put w.text k
    | _ -> () in
  (* the writes that wait, shown while the text's end is: one that does
   * not scroll holds them when it is full, until it is scrolled (not
   * when its program draws: the text is not what one sees) *)
  let writes = Queue.create () in
  let rec show () =
    if not (Queue.is_empty writes) && (Terminal.scrolling w.text || Terminal.at_end w.text || w.wants_mouse) then begin
      let text, reply = Queue.take writes in
      Terminal.put w.text text;
      ignore (reply "");
      show ()
    end in
  border true;
  let rec loop () =
    show ();
    Display.flush d;
    match Event.sync (Event.receive w.inbox) with
    | Keys keys ->
        if !raw then Queue.add (String.concat "" keys) lines
        else
          (* the arrows scroll, up and down; any other key is typed, at
           * the end *)
          List.iter (fun k ->
            if k = Keyboard.up then Terminal.scroll w.text (Terminal.half w.text)
            else if k = Keyboard.down then Terminal.scroll w.text (- (Terminal.half w.text))
            else begin Terminal.scroll w.text (-100000); key k end) keys;
        serve (); loop ()
    | Read (reply, count) -> Queue.add (reply, count) readers; serve (); loop ()
    | Wrote (text, reply) -> Queue.add (text, reply) writes; loop ()
    | Scroll on -> Terminal.set_scrolling w.text on; loop ()
    | Raw on -> raw := on; loop ()
    (* the mouse: the program's that reads it; else the text's own *)
    | Moved m -> (if w.wants_mouse then begin moved := Some m; serve_mouse () end else Terminal.mouse w.text m); loop ()
    | Mouse_read reply -> Queue.add reply mouse_readers; serve_mouse (); loop ()
    (* (kept for a program that has the file open: the others' would only pile up) *)
    | Held m -> if !reads_held then begin Queue.add m held; serve_held () end; loop ()
    | Held_read reply -> Queue.add reply held_readers; serve_held (); loop ()
    | Held_file on -> reads_held := on; Queue.clear held; loop ()
    | Mouse_file true -> w.wants_mouse <- true; moved := Some !pointer; loop ()
    | Mouse_file false ->
        (* the program that drew here is done: the inside of the border as the text has it *)
        w.wants_mouse <- false;
        w.cursor <- None;
        let white = Display.color d Display.white in
        Draw.fill w.image (Rectangle.inset w.image.r width) white;
        Display.free white;
        Terminal.redraw w.text;
        loop ()
    | Label l -> w.label <- l; loop ()
    | Cursor c -> w.cursor <- c; loop ()
    | Front current ->
        border current;
        (* (the keyboard is another window's: no key is held here any more,
         * whatever was when it left) *)
        if not current && !reads_held then begin Queue.add "K\000" held; serve_held () end;
        loop ()
    | Reshape r ->
        (* moved: the same image, elsewhere (the kernel moves its pixels);
         * another size: another image, the text in it again *)
        let old = w.image in
        if Rectangle.dx r = Rectangle.dx old.r && Rectangle.dy r = Rectangle.dy old.r then begin
          w.image <- Display.origin old r.min r.min;
          w.text <- Terminal.reshape w.text w.image (Rectangle.inset r (width + 2))
        end
        else begin
          w.image <- Display.window desk r Display.white;
          Display.free old;
          Display.name w.image (name w);
          w.text <- Terminal.reshape w.text w.image (Rectangle.inset r (width + 2))
        end;
        border w.current;
        (* a program that draws here is told, at its next mouse read *)
        if w.wants_mouse then begin reshaped := true; moved := Some !pointer; serve_mouse () end;
        loop ()
    | Hide on ->
        (* off the screen: its place there far away, its own coordinates kept *)
        w.hidden <- on;
        w.image <- Display.origin w.image w.image.r.min (if on then Point.v 20000 20000 else w.image.r.min);
        loop ()
    | Quit -> Display.free w.image; Display.flush d in
  loop ()

let make desk id r font =
  let image = Display.window desk r Display.white in
  let w = { id; image; text = Terminal.make image (Rectangle.inset image.r (width + 2)) font; hidden = false; current = true; label = Printf.sprintf "rc %d" id; cursor = None; inbox = Event.new_channel (); pid = 0; wants_mouse = false; thread = None } in
  Display.name image (name w);
  (* (no thread left for it: no window) *)
  (match Thread.create (fun () -> run w desk) () with
   | t -> w.thread <- Some t
   | exception Failure m -> Display.free image; failwith m);
  w

let quit (w : t) = send w Quit; Option.iter Thread.join w.thread
