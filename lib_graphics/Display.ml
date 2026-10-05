(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Display.mli *)

type t = { data : Unix.file_descr; ctl : Unix.file_descr; buf : Buffer.t; mutable next : int; mutable root : image option; mutable white : image option; format : string }
and image = { display : t; id : int; r : Rectangle.t; repl : bool }

type color = { red : int; green : int; blue : int; alpha : int }
let rgb red green blue = { red; green; blue; alpha = 255 }
let black = rgb 0 0 0
let white = rgb 255 255 255

type chan = string

(* numbers the low byte first; a long by its halves (arm's int has 31 bits) *)
let byte b v = Buffer.add_char b (Char.chr (v land 0xff))
let long b v = byte b v; byte b (v asr 8); byte b (v asr 16); byte b (v asr 24)
let point b (p : Point.t) = long b p.x; long b p.y
let rect b (r : Rectangle.t) = point b r.min; point b r.max

(* a format's 32 bits: a byte a channel (its kind's number, then its
 * bits), the first channel the highest; so the low byte first is the
 * channels backwards *)
let chan_bytes b (c : chan) =
  let kind ch = match ch with 'r' -> 0 | 'g' -> 1 | 'b' -> 2 | 'k' -> 3 | 'a' -> 4 | 'm' -> 5 | 'x' -> 6 | _ -> invalid_arg ("Display: a pixel's format: " ^ c) in
  let n = String.length c / 2 in
  for k = n - 1 downto 0 do byte b ((kind c.[2 * k] lsl 4) lor (Char.code c.[(2 * k) + 1] - 48)) done;
  for _k = n to 3 do byte b 0 done

(* what is kept is sent when it grows: a write to the device is a few
 * messages, whole *)
let send (d : t) =
  if Buffer.length d.buf > 0 then begin
    let s = Buffer.contents d.buf in
    Buffer.clear d.buf;
    ignore (Unix.write_substring d.data s 0 (String.length s))
  end

let message (d : t) fill =
  let m = Buffer.create 64 in
  fill m;
  if Buffer.length d.buf + Buffer.length m > 8000 then send d;
  Buffer.add_buffer d.buf m

let flush (d : t) = message d (fun b -> Buffer.add_char b 'v'); send d

(* /dev/draw/new read: twelve numbers of 12 characters, the connection's
 * number first, then the screen: its image's number (0), its format,
 * whether it repeats, its rectangle, its clipping rectangle *)
let init (_ : < Cap.draw; .. >) =
  let ctl = Unix.openfile "/dev/draw/new" [ Unix.O_RDWR ] 0 in
  let info = Bytes.create 144 in
  let n = Unix.read ctl info 0 144 in
  if n < 143 then failwith "Display.init: /dev/draw/new: short read";
  let field k = String.trim (Bytes.sub_string info (12 * k) 12) in
  let num k = int_of_string (field k) in
  let data = Unix.openfile (Printf.sprintf "/dev/draw/%d/data" (num 0)) [ Unix.O_RDWR ] 0 in
  let d = { data; ctl; buf = Buffer.create 8192; next = 1; root = None; white = None; format = field 2 } in
  d.root <- Some { display = d; id = 0; r = Rectangle.v (num 4) (num 5) (num 6) (num 7); repl = false };
  d

let whole (d : t) = match d.root with Some i -> i | None -> assert false

(* 'b': the image's number (ours to choose), no screen (a window's
 * would be), no refresh, the format, repeated or not, the rectangle,
 * the clipping rectangle (all the plane when repeated), the colour
 * (red the high byte, alpha the low) *)
let alloc_on (d : t) screen_id (r : Rectangle.t) chan ~repl (c : color) =
  let id = d.next in
  d.next <- id + 1;
  message d (fun b ->
    Buffer.add_char b 'b';
    long b id; long b screen_id; byte b 0;
    chan_bytes b chan;
    byte b (if repl then 1 else 0);
    rect b r;
    rect b (if repl then Rectangle.v (-0x3fffffff) (-0x3fffffff) 0x3fffffff 0x3fffffff else r);
    byte b c.alpha; byte b c.blue; byte b c.green; byte b c.red);
  { display = d; id; r; repl }

let alloc d r chan ~repl c = alloc_on d 0 r chan ~repl c

let color d c = alloc d (Rectangle.v 0 0 1 1) "r8g8b8a8" ~repl:true c

(* an opaque mask: white, made once *)
let opaque (d : t) =
  match d.white with
  | Some i -> i
  | None -> let i = color d white in d.white <- Some i; i

(* (the connection is the control file's: open as long as the display is) *)
let close (d : t) = Unix.close d.data; Unix.close d.ctl

let free (i : image) = message i.display (fun b -> Buffer.add_char b 'f'; long b i.id)

(* Windows: a screen is an image (the display's) on which the kernel
 * keeps windows, images that may cover one another: it draws what
 * shows of each and keeps what does not (libmemlayer). 'A': the
 * screen's number (one for all the programs: ours is the process's),
 * its image, the image that fills where no window is. *)
type desktop = { on : image; number : int }

let desktop (on : image) (fill : image) =
  let number = Unix.getpid () in
  message on.display (fun b -> Buffer.add_char b 'A'; long b number; long b on.id; long b fill.id; byte b 0);
  { on; number }

(* 'b' with a screen: a window on it, in the screen's format, kept by
 * the kernel when covered (refresh 0: a backup) *)
let window (s : desktop) r c = alloc_on s.on.display s.number r s.on.display.format ~repl:false c

(* 't': windows to the front (1), here one *)
let top (w : image) = message w.display (fun b -> Buffer.add_char b 't'; byte b 1; byte b 1; byte b 0; long b w.id)

(* 'o': a window moved: where its corner is now in its own coordinates,
 * and on the screen (the two the same: it draws where it shows; the
 * second far away: it is hidden, and draws as before) *)
let origin (w : image) (mine : Point.t) (shown : Point.t) =
  message w.display (fun b -> Buffer.add_char b 'o'; long b w.id; point b mine; point b shown);
  { w with r = Rectangle.add w.r (Point.sub mine w.r.min) }

(* 'N': an image given a name, for another program to draw in it (a
 * window, for the program that runs in it) *)
let name (i : image) n =
  message i.display (fun b -> Buffer.add_char b 'N'; long b i.id; byte b 1; byte b (String.length n); Buffer.add_string b n)

(* 'n': the image of that name, as one of ours; what it is (its
 * rectangle) is then what the control file says: the same twelve
 * numbers as at the start *)
let named (d : t) n =
  let id = d.next in
  d.next <- id + 1;
  message d (fun b -> Buffer.add_char b 'n'; long b id; byte b (String.length n); Buffer.add_string b n);
  send d;
  ignore (Unix.lseek d.ctl 0 Unix.SEEK_SET);
  let info = Bytes.create 144 in
  if Unix.read d.ctl info 0 144 < 143 then failwith ("Display.named: " ^ n);
  let num k = int_of_string (String.trim (Bytes.sub_string info (12 * k) 12)) in
  { display = d; id; r = Rectangle.v (num 4) (num 5) (num 6) (num 7); repl = false }

(* 'y': a rectangle's pixels, as they are (not compressed) *)
let load (i : image) r pixels =
  send i.display;
  message i.display (fun b -> Buffer.add_char b 'y'; long b i.id; rect b r; Buffer.add_string b pixels);
  send i.display

(* Where a program draws: its window when it runs in one (/dev/winname
 * has the window's image's name: the window system's file), inside its
 * border; or all the screen (the kernel's /dev/winname, a name that
 * starts with "noborder"; or none) *)
let screen (d : t) =
  match (let fd = Unix.openfile "/dev/winname" [ Unix.O_RDONLY ] 0 in
         let b = Bytes.create 64 in
         let n = Unix.read fd b 0 64 in
         Unix.close fd;
         Bytes.sub_string b 0 n) with
  | exception Unix.Unix_error _ -> whole d
  | "" -> whole d
  | n when String.length n >= 8 && String.sub n 0 8 = "noborder" -> whole d
  | n -> let w = named d n in { w with r = Rectangle.inset w.r 4 }
