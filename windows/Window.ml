(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Window.mli *)

type t = {
  id : int;
  image : Display.image;
  term : Terminal.t;
  mutable pid : int;
  typing : Buffer.t;
  lines : string Queue.t;
  mutable rest : string;
  readers : ((string -> unit) * int) Queue.t;
}

let width = 4      (* the border's, as rio's *)

let border (w : t) ~current =
  let d = w.image.display in
  (* rio's: the window that has the keyboard a grey green, the others pale *)
  let c = Display.color d (if current then Display.rgb 0x55 0xaa 0xaa else Display.rgb 0x9e 0xee 0xee) in
  Draw.border w.image w.image.r width c;
  Display.free c

let make desk id r font =
  let image = Display.window desk r Display.white in
  let w = { id; image; term = Terminal.make image (Rectangle.inset r (width + 2)) font; pid = 0;
            typing = Buffer.create 80; lines = Queue.create (); rest = ""; readers = Queue.create () } in
  border w ~current:true;
  w

(* the reads that wait answered, a line each (what a read does not
 * take of a line is the next read's) *)
let rec serve (w : t) =
  if not (Queue.is_empty w.readers) && (w.rest <> "" || not (Queue.is_empty w.lines)) then begin
    let reply, count = Queue.take w.readers in
    let line = if w.rest <> "" then w.rest else Queue.take w.lines in
    let n = min count (String.length line) in
    w.rest <- String.sub line n (String.length line - n);
    reply (String.sub line 0 n);
    serve w
  end

let read (w : t) reply count = Queue.add (reply, count) w.readers; serve w

let wrote (w : t) text = Terminal.put w.term text

let typed (w : t) keys =
  String.iter (fun c ->
    match c with
    | '\n' | '\r' ->
        Terminal.put w.term "\n";
        Queue.add (Buffer.contents w.typing ^ "\n") w.lines;
        Buffer.clear w.typing
    | '\b' ->
        let n = Buffer.length w.typing in
        if n > 0 then begin Buffer.truncate w.typing (n - 1); Terminal.erase w.term end
    | '\021' -> while Buffer.length w.typing > 0 do Buffer.truncate w.typing (Buffer.length w.typing - 1); Terminal.erase w.term done
    | '\004' -> Queue.add (Buffer.contents w.typing) w.lines; Buffer.clear w.typing
    | c when c >= ' ' && c <> '\127' -> Buffer.add_char w.typing c; Terminal.put w.term (String.make 1 c)
    | _ -> ()) keys;
  serve w
