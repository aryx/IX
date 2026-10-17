(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyKernel.ml's calls on the host, in a window of SDL's (see
 * ../TinyKernel/host/TinyCalls.mli): what tiny-office, tiny-emacs,
 * tiny-calc and tiny-tetris run on, as their kernel's calls on
 * tiny-machine.
 *
 * What a program writes where it draws (its descriptor 3) is done by
 * tiny-kernel's own drawing, TinyKernelGraphics.ml, in a screen of
 * TinyMemory's, and shown (TinyMachineSDL, the palette tiny-machine's)
 * when the program next waits. The window's mouse is the box of the
 * program's descriptor 4, its keys the bytes of its 0 (as tiny-machine's
 * window makes them: Alt a key's Escape, a key held typed again, the
 * wheel the arrows). An ENQ written to the console is answered in the
 * box, as tiny-windows answers it: the window's size. A file is the
 * host's, read whole when opened, written when closed.
 *
 * A dial to the wire's other end, its port 70 (10.0.0.1, tiny-machine's
 * peer, TinyMachinePeer.ml), is answered here as tiny-machine answers
 * it: a line "www address" a web page, "img w h address" a picture in
 * the machine's colours, both fetched by tiny-machine-fetch (ix's own
 * HTTP and TLS), or, with TINY_WWW=dir, a copy kept in dir when the
 * fetch fails (as tiny-machine -net dir); the answer's messages read
 * one at a time, as a link's are. *)

let width = 640
let height = 480
let screen_at = 0xf00000

(* the connection to the drawing, as tiny-kernel makes it: the font at
 * 0x1000, the images' memory after the screen *)
let conn = lazy (
  Bytes.blit_string TinyFont.bits 0 TinyMemory.mem 0x1000 (String.length TinyFont.bits);
  TinyKernelGraphics.arena 0xf4b000 0xb4000;
  let screen = { TinyKernelGraphics.r = TinyKernelGraphics.rect 0 0 width height; at = screen_at; repl = false } in
  TinyKernelGraphics.connect screen (TinyKernelGraphics.font_mask 0x1000 (TinyKernelGraphics.alloc 16384)))

let display = lazy (TinyMachineSDL.create ~title:(Filename.basename Sys.argv.(0)))

(* TINY_SCREEN=file: the screen written there as a PPM when the program
 * ends, a TERM signal ending it (for a look without a window:
 * SDL_VIDEODRIVER=dummy), as tiny-machine -screen *)
let () =
  match Sys.getenv_opt "TINY_SCREEN" with
  | Some file ->
      Sys.set_signal Sys.sigterm (Sys.Signal_handle (fun _ -> exit 0));
      at_exit (fun () -> Out_channel.with_open_bin file (fun oc -> output_string oc (TinyMemory.ppm ())))
  | None -> ()
let dirty = ref false
let drawn = Buffer.create 0

(* the screen shown, if it was drawn on since *)
let show () =
  if !dirty then begin
    dirty := false;
    let rgb = Bytes.create (3 * width * height) in
    for i = 0 to (width * height) - 1 do
      Bytes.blit_string TinyMachineDevices.colours (3 * Char.code (Bytes.get TinyMemory.mem (screen_at + i))) rgb (3 * i) 3
    done;
    (Lazy.force display).present width height (Bytes.unsafe_to_string rgb)
  end

(* the clock, 400 ticks a second *)
let start = Unix.gettimeofday ()
let u_ticks () = int_of_float ((Unix.gettimeofday () -. start) *. 400.)

(* the keys typed and not read; the mouse, and whether it moved since it
 * was read; an ENQ to answer *)
let typed = ref ""
let mouse = ref (0, 0, 0)
let fresh = ref false
let enq = ref false
let shift = ref false and ctrl = ref false and alt = ref false
let held = ref None and again = ref 0.

(* the window's events, made keys and the mouse *)
let pump () =
  if Lazy.is_val display then begin
    let key byte = typed := !typed ^ String.make 1 (Char.chr byte) in
    List.iter (function
      | TinyMachineSDL.Quit -> exit 0
      | TinyMachineSDL.At (x, y) -> let (_, _, b) = !mouse in mouse := (x, y, b); fresh := true
      | TinyMachineSDL.Button (b, down) -> let (x, y, bs) = !mouse in mouse := (x, y, if down then bs lor b else bs land lnot b); fresh := true
      | TinyMachineSDL.Key ((225 | 229), down) -> shift := down
      | TinyMachineSDL.Key ((224 | 228), down) -> ctrl := down
      | TinyMachineSDL.Key ((226 | 230), down) -> alt := down
      | TinyMachineSDL.Key (usage, true) ->
          Option.iter (fun byte ->
            if !alt then key 27;
            key byte;
            held := Some (usage, byte);
            again := Unix.gettimeofday () +. 0.3) (TinyMachineSDL.key_byte usage ~shift:!shift ~ctrl:!ctrl)
      | TinyMachineSDL.Key (usage, false) -> (match !held with Some (u, _) when u = usage -> held := None | _ -> ())
      | TinyMachineSDL.Wheel v -> for _i = 1 to min 8 (abs v) do key (if v < 0 then 128 else 129) done) ((Lazy.force display).poll ());
    match !held with
    | Some (_, byte) when Unix.gettimeofday () >= !again -> key byte; again := Unix.gettimeofday () +. 0.05
    | _ -> ()
  end

(* the files open: their descriptor, what is left to read of one, what
 * is written to one *)
type file = Reading of string ref | Writing of string * Buffer.t | Asking of Buffer.t | Answer of string list ref
let files = Hashtbl.create 8
let next = ref 5

let ready fd =
  (fd = 0 && !typed <> "") || (fd = 4 && (!fresh || !enq))
  || (match Hashtbl.find_opt files fd with Some (Asking _) | None -> false | Some _ -> true)

(* tiny-machine-fetch's output for its arguments, or why not; beside
 * this program, as tiny-machine finds it *)
let fetch args =
  let dir = Filename.dirname Sys.executable_name in
  let helper = if Filename.check_suffix Sys.executable_name ".exe" then Filename.concat dir "../TinyMachine/TinyMachineFetch.exe" else Filename.concat dir "tiny-machine-fetch" in
  let ic = Unix.open_process_args_in helper (Array.of_list (helper :: args)) in
  let out = In_channel.input_all ic in
  match Unix.close_process_in ic with Unix.WEXITED 0 -> Ok out | _ -> Error out

(* a copy kept in TINY_WWW's directory, by its name *)
let kept name = match Sys.getenv_opt "TINY_WWW", name with
  | Some dir, Some n when Sys.file_exists (Filename.concat dir n) -> Some (Filename.concat dir n)
  | _ -> None

(* the answer to a line asked of port 70, its messages *)
let answer line =
  match String.split_on_char ' ' (String.trim line) with
  | "www" :: words ->
      let url = TinyMachinePeer.www_address (String.concat " " words) in
      TinyMachinePeer.messages (match fetch [ url ] with
        | Ok page -> page
        | Error why -> (match kept (TinyMachinePeer.www_kept url) with Some f -> In_channel.with_open_bin f In_channel.input_all | None -> why))
  | "img" :: w :: h :: address when int_of_string_opt w <> None && int_of_string_opt h <> None ->
      let w = int_of_string w and h = int_of_string h and url = String.concat " " address in
      let decode source = match fetch [ "-picture"; string_of_int w; string_of_int h; source ] with
        | Ok pixels when String.length pixels = w * h -> Some (TinyMachinePeer.picture "" w h pixels)
        | _ -> None in
      (match decode url with
       | Some l -> l
       | None -> (match Option.bind (kept (TinyMachinePeer.www_picture_kept url)) decode with Some l -> l | None -> TinyMachinePeer.picture "" 0 0 ""))
  | _ -> []

let rec u_ready (fds : int array) (n : int) (until : int) : int =
  show ();
  pump ();
  let rec first i = if i >= n then -1 else if ready fds.(i) then fds.(i) else first (i + 1) in
  match first 0 with
  | -1 when until > 0 && u_ticks () >= until -> -1
  | -1 -> Unix.sleepf 0.005; u_ready fds n until
  | fd -> fd

(* a word of the mouse's box: 4 bytes, the low first *)
let word v = String.init 4 (fun k -> Char.chr ((v asr (8 * k)) land 255))

let u_read (fd : int) (n : int) : string =
  if fd = 0 then begin
    ignore (u_ready [| 0 |] 1 0);
    let k = min n (String.length !typed) in
    let s = String.sub !typed 0 k in
    typed := String.sub !typed k (String.length !typed - k);
    s
  end
  else if fd = 4 then begin
    if !enq then (enq := false; word width ^ word height ^ word (-1))
    else (let (x, y, b) = !mouse in fresh := false; word x ^ word y ^ word b)
  end
  else
    match Hashtbl.find_opt files fd with
    | Some (Reading left) -> let k = min n (String.length !left) in let s = String.sub !left 0 k in left := String.sub !left k (String.length !left - k); s
    | Some (Answer ({ contents = m :: rest } as left)) ->
        if String.length m <= n then (left := rest; m) else (left := String.sub m n (String.length m - n) :: rest; String.sub m 0 n)
    | _ -> ""

let u_write (fd : int) (s : string) : int =
  if fd = 3 then (TinyKernelGraphics.messages (Lazy.force conn) s; dirty := true)
  else if fd = 1 && s = "\005" then enq := true
  else if fd = 1 then (print_string s; flush stdout)
  else if fd = 2 then (prerr_string s; flush stderr)
  else (match Hashtbl.find_opt files fd with
        | Some (Writing (_, b)) -> Buffer.add_string b s
        | Some (Asking b) ->
            Buffer.add_string b s;
            let asked = Buffer.contents b in
            (match String.index_opt asked '\n' with Some i -> Hashtbl.replace files fd (Answer (ref (answer (String.sub asked 0 i)))) | None -> ())
        | _ -> ());
  0

let u_open (name : string) (flags : int) : int =
  let fd = !next in
  if flags land 1 <> 0 then (Hashtbl.replace files fd (Writing (name, Buffer.create 4096)); incr next; fd)
  else if Sys.file_exists name && not (Sys.is_directory name) then (Hashtbl.replace files fd (Reading (ref (In_channel.with_open_bin name In_channel.input_all))); incr next; fd)
  else -1

let u_close (fd : int) : int =
  (match Hashtbl.find_opt files fd with
   | Some (Writing (name, b)) -> Out_channel.with_open_bin name (fun oc -> Buffer.output_buffer oc b)
   | _ -> ());
  Hashtbl.remove files fd;
  0

let u_rawcons (_ : int) = 0
let u_dial (address : string) (port : int) =
  if address = "10.0.0.1" && port = 70 then (let fd = !next in Hashtbl.replace files fd (Asking (Buffer.create 64)); incr next; fd) else -1
let u_argc () = Array.length Sys.argv
let u_arg (i : int) = Sys.argv.(i)
