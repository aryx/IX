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
let label (w : t) = Printf.sprintf "rc %d" w.id
let note : (t -> string -> unit) ref = ref (fun _ _ -> ())

let send (w : t) m = Event.sync (Event.send w.inbox m)

(* The thread: the window's state is its variables. *)
let run (w : t) desk font =
  let d = w.image.display in
  let term = ref (Terminal.make w.image (Rectangle.inset w.image.r (width + 2)) font) in
  let current = ref true in
  (* the line being typed; the lines typed and not read, and what a read
   * left of one; the reads that wait for a line *)
  let typing = Buffer.create 80 and lines = Queue.create () and rest = ref "" and readers = Queue.create () in
  (* a program that draws here: the keys as they come; the mouse's last
   * change not read yet, the reads that wait for one *)
  let raw = ref false and moved = ref None and mouse_readers = Queue.create () in
  (* (its window changed, and it was not told yet: its next mouse read says r) *)
  let reshaped = ref false in
  (* the border: a blue for the window that has the keyboard, pale for
   * the others (ix's colours: rio's are a grey green and a pale one) *)
  let border current_ =
    current := current_;
    let c = Display.color d (if current_ then Display.rgb 0x33 0x66 0x99 else Display.rgb 0xb8 0xcc 0xe0) in
    Draw.border w.image w.image.r width c;
    Display.free c in
  (* a read that waits answered by a line (what it does not take of it is the next read's) *)
  let rec serve () =
    if not (Queue.is_empty readers) && (!rest <> "" || not (Queue.is_empty lines)) then begin
      let reply, count = Queue.take readers in
      let line = if !rest <> "" then !rest else Queue.take lines in
      let n = min count (String.length line) in
      rest := String.sub line n (String.length line - n);
      reply (String.sub line 0 n);
      serve ()
    end in
  (* /dev/mouse's line: m, then four numbers of 12 characters *)
  let serve_mouse () =
    match !moved with
    | Some (m : Mouse.state) when not (Queue.is_empty mouse_readers) ->
        moved := None;
        let letter = if !reshaped then 'r' else 'm' in
        reshaped := false;
        (Queue.take mouse_readers) (Printf.sprintf "%c%11d %11d %11d %11d " letter m.pos.x m.pos.y m.buttons m.msec)
    | _ -> () in
  (* a key typed: shown, and kept until Enter makes the line (Backspace
   * takes one back, Ctrl-U all, Ctrl-D ends the input) *)
  let key c =
    match c with
    | '\n' | '\r' -> Terminal.put !term "\n"; Queue.add (Buffer.contents typing ^ "\n") lines; Buffer.clear typing
    | '\b' -> let n = Buffer.length typing in if n > 0 then begin Buffer.truncate typing (n - 1); Terminal.erase !term end
    | '\021' -> while Buffer.length typing > 0 do Buffer.truncate typing (Buffer.length typing - 1); Terminal.erase !term done
    | '\004' -> Queue.add (Buffer.contents typing) lines; Buffer.clear typing
    | '\127' -> !note w "interrupt"      (* Delete: its processes interrupted *)
    | c when c >= ' ' -> Buffer.add_char typing c; Terminal.put !term (String.make 1 c)
    | _ -> () in
  border true;
  let rec loop () =
    Display.flush d;
    match Event.sync (Event.receive w.inbox) with
    | Keys keys ->
        if !raw then Queue.add (String.concat "" keys) lines
        else
          (* the arrows scroll, up and down; any other key is typed, at
           * the end (a character of one byte: no other is shown yet) *)
          List.iter (fun k ->
            if k = Keyboard.up then Terminal.scroll !term (Terminal.half !term)
            else if k = Keyboard.down then Terminal.scroll !term (- (Terminal.half !term))
            else if String.length k = 1 then begin Terminal.scroll !term (-100000); key k.[0] end) keys;
        serve (); loop ()
    | Read (reply, count) -> Queue.add (reply, count) readers; serve (); loop ()
    | Wrote text -> Terminal.put !term text; loop ()
    | Raw on -> raw := on; loop ()
    | Moved m -> moved := Some m; serve_mouse (); loop ()
    | Mouse_read reply -> Queue.add reply mouse_readers; serve_mouse (); loop ()
    | Mouse_file true -> w.wants_mouse <- true; moved := Some !pointer; loop ()
    | Mouse_file false ->
        (* the program that drew here is done: the inside of the border as the text has it *)
        w.wants_mouse <- false;
        let white = Display.color d Display.white in
        Draw.fill w.image (Rectangle.inset w.image.r width) white;
        Display.free white;
        Terminal.redraw !term;
        loop ()
    | Front current -> border current; loop ()
    | Reshape r ->
        (* moved: the same image, elsewhere (the kernel moves its pixels);
         * another size: another image, the text in it again *)
        let old = w.image in
        if Rectangle.dx r = Rectangle.dx old.r && Rectangle.dy r = Rectangle.dy old.r then begin
          w.image <- Display.origin old r.min r.min;
          term := Terminal.reshape !term w.image (Rectangle.inset r (width + 2))
        end
        else begin
          w.image <- Display.window desk r Display.white;
          Display.free old;
          Display.name w.image (name w);
          term := Terminal.reshape !term w.image (Rectangle.inset r (width + 2))
        end;
        border !current;
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
  let w = { id; image; hidden = false; inbox = Event.new_channel (); pid = 0; wants_mouse = false; thread = None } in
  Display.name image (name w);
  (* (no thread left for it: no window) *)
  (match Thread.create (fun () -> run w desk font) () with
   | t -> w.thread <- Some t
   | exception Failure m -> Display.free image; failwith m);
  w

let quit (w : t) = send w Quit; Option.iter Thread.join w.thread
