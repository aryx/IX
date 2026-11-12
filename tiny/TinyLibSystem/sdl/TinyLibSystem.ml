(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyLibSystem in a window of SDL's (../../TinyLibSystem.mli): what
 * tiny-office, tiny-emacs, tiny-www, tiny-calc, tiny-tetris and
 * tiny-play run on (../../user/sdl/). Its files and processes are the
 * host's, ../unix/'s code (TinyLibSystemUnix, a copy of
 * ../unix/TinyLibSystem.ml that dune makes: one source, two modules);
 * what is tiny-kernel's is made here, as tiny-machine makes it:
 *
 * What a program writes where it draws (fd_draw) is done by tiny-kernel's
 * own drawing, KGraphics.ml, in a screen of KRaw's, and
 * shown (TinyMachineSDL, the palette tiny-machine's) when the program
 * next waits. The window's mouse is the box of fd_mouse, its keys the
 * bytes of fd_stdin (as tiny-machine's window makes them: Alt or a
 * Mac's Command a key's Escape, a key held typed again, the wheel the
 * arrows). An ENQ written to the console is answered in the box, as
 * tiny-windows answers it: the window's size. /dev/audio is the window's
 * sound, as tiny-kernel and tiny-machine make it: each open a voice
 * whose sounds KAudio.ml makes into a ring, mixed, and the ring
 * played by the clock (to SDL's queue, TinyMachineSDL's play) as
 * tiny-machine's speaker plays its ring.
 *
 * A dial to the wire's other end, its port 70 (10.0.0.1, tiny-machine's
 * peer, TinyMachinePeer.ml), is answered here as tiny-machine answers
 * it: a request "GET address HTTP/1.0" a web page, as HTTP's response,
 * "img w h address" a picture in the machine's colours, both fetched by
 * tiny-machine-fetch (ix's own HTTP and TLS), or, with TINY_WWW=dir, a
 * copy kept in dir when the fetch fails (as tiny-machine -net dir); the
 * answer's messages read one at a time, as a link's are. *)

include TinyLibSystemUnix

module G = KGraphics
module Audio = KAudio
module Peer = TinyMachinePeer
module SDL = TinyMachineSDL

(*****************************************************************************)
(* Descriptors *)
(*****************************************************************************)

(* what a program writes to its console to ask for its window's size,
 * answered in its mouse's box, as tiny-windows answers it *)
let enq = "\005"

(* A descriptor the window makes (the speaker's, a dial's) is a real
 * one of the host's, /dev/null's, so that a file opened after it never
 * has its number; and 3 and 4, the drawing's and the mouse's, are taken
 * so at the start *)
let reserve () : fd = number (Unix.openfile "/dev/null" [ Unix.O_RDWR ] 0)
let () =
  let rec take () =
    let n = reserve () in
    if n <= fd_mouse then take () else Unix.close (fd n) in
  take ()

(*****************************************************************************)
(* The screen *)
(*****************************************************************************)

let width = 1024
let height = 768
let screen_at = 0xf00000
(* the connection to the drawing, as tiny-kernel makes it: the font at
 * 0x1000, the images' memory its 2 MB below the screen and what is
 * after it (KDevices' font; a page of www's may have 1 MB of
 * pictures: old: only after the screen, 720 KB then, and Mars' article
 * ended www). The font is tiny-kernel's (plan9.font, Plan 9's), or
 * the file TINY_FONT names (TINY_FONT=tiny/TinyKernel/fonts/grey.font:
 * Ubuntu Mono with grey edges; tiny.font, the same a pixel set or not;
 * TINY_FONT=kernels/lib_machine/font1.bin: the bold and the large made
 * of its one face, as before tiny.font) *)
let conn = lazy (
  let font =
    match Sys.getenv_opt "TINY_FONT" with
    | Some file -> In_channel.with_open_bin file In_channel.input_all
    | None -> TinyFont.bits
  in
  Bytes.blit_string font 0 KRaw.mem 0x1000 (String.length font);
  G.arena 0xd00000 0x200000;
  G.free 0xfc0000 0x3f000;
  let (screen : G.image) =
    { r = G.rect 0 0 width height; at = screen_at; repl = false } in
  G.connect screen
    (G.font_mask 0x1000 (String.length font)
       (G.alloc 16384)))

let display =
  lazy (SDL.create ~title:(Filename.basename Sys.argv.(0)))

(* TINY_SCREEN=file: the screen written there as a PPM when the program
 * ends, a TERM signal ending it (for a look without a window:
 * SDL_VIDEODRIVER=dummy), as tiny-machine -screen *)
let () =
  match Sys.getenv_opt "TINY_SCREEN" with
  | Some file ->
      Sys.set_signal Sys.sigterm (Sys.Signal_handle (fun _ -> Stdlib.exit 0));
      at_exit (fun () ->
        Out_channel.with_open_bin file (fun oc ->
          output_string oc (KRaw.ppm width height)))
  | None -> ()

(* whether the screen was drawn on since it was last shown *)
let dirty = ref false

(* the screen shown, if it was drawn on since *)
let show () =
  if !dirty then begin
    dirty := false;
    let rgb = Bytes.create (3 * width * height) in
    for i = 0 to (width * height) - 1 do
      Bytes.blit_string TinyMachineDevices.colours
        (3 * Char.code (Bytes.get KRaw.mem (screen_at + i)))
        rgb (3 * i) 3
    done;
    (Lazy.force display).present width height (Bytes.unsafe_to_string rgb)
  end

(* the drawing's messages; one refused is said, and the program goes on, as
 * after tiny-kernel's write of /dev/draw (-1 there) (old: the program ended) *)
let draw s =
  match G.messages (Lazy.force conn) s with
  | () -> dirty := true
  | exception KGraphics.Graphics why ->
      prerr_string ("draw: " ^ why ^ "\n"); dirty := true

(*****************************************************************************)
(* The speaker *)
(*****************************************************************************)

(* The speaker, as tiny-kernel's (TinyKernel.ml's voices) and
 * tiny-machine's (its ring played, then silenced): a ring of 8,192
 * samples of KRaw's where the voices' sounds are added, each from
 * where it stopped or, when the speaker passed it, from where the
 * speaker is; played by the host's clock, 8,000 a second, a fifth of a
 * second ahead of it ([fed]: the samples given to SDL so far). A write
 * waits while its sounds would be more than a ring ahead. *)
let ring_at = 0xc00000
let ring = 8192
let fed = ref 0
(* when the speaker started, at the first open of /dev/audio (old: 0.
 * until then) *)
let started : float option ref = ref None

let feed () =
  match !started with
  | None -> ()
  | Some t0 ->
      let due = int_of_float ((Unix.gettimeofday () -. t0) *. 8000.) + 1600 in
      if due > !fed then begin
        let n = min (due - !fed) ring in
        let b = Bytes.create n in
        for i = 0 to n - 1 do
          let a = ring_at + ((!fed + i) land (ring - 1)) in
          Bytes.set b i (Bytes.get KRaw.mem a);
          Bytes.set KRaw.mem a '\000'
        done;
        fed := due;
        (Lazy.force display).play (Bytes.unsafe_to_string b)
      end

let speak (ahead : int ref) s =
  match Audio.sounds s with
  | sounds ->
      let total =
        List.fold_left
          (fun n snd -> n + Audio.sound_length snd) 0 sounds in
      let rec room () =
        feed ();
        if !ahead < !fed then ahead := !fed;
        if total > ring - (!ahead - !fed) then (Unix.sleepf 0.01; room ()) in
      if total <= ring then begin
        room ();
        List.iter
          (fun snd ->
            Audio.mix_sound ring_at ring !ahead snd;
            ahead := !ahead + Audio.sound_length snd)
          sounds
      end
  | exception Audio.Bad_sound -> ()

(*****************************************************************************)
(* The clock *)
(*****************************************************************************)

(* the machine's seed, as tiny-kernel's when it has none: the clock's
 * ticks, 400 a second, since the program started *)
let start = Unix.gettimeofday ()
let seed (_ : < Cap.random; .. >) =
  int_of_float ((Unix.gettimeofday () -. start) *. 400.)

(* now, as millis says it *)
let now () = int_of_float (Unix.gettimeofday () *. 1000.0)

(*****************************************************************************)
(* The keys and the mouse *)
(*****************************************************************************)

(* the mouse, as its box says it: where it is, its buttons held (a bit
 * each) (old: a triple) *)
type pointer = { p_x : int; p_y : int; p_buttons : int }

(* the keys typed and not read; the mouse, and whether it moved since it
 * was read; whether the window's size was asked (an ENQ written) *)
let typed = ref ""
let mouse = ref { p_x = 0; p_y = 0; p_buttons = 0 }
let fresh = ref false
let size_asked = ref false
let keys = SDL.keyboard ()

(* the window's events, made keys and the mouse *)
let pump () =
  if Lazy.is_val display then begin
    let key byte = typed := !typed ^ String.make 1 (Char.chr byte) in
    let now = Unix.gettimeofday () in
    List.iter (function
      | SDL.Quit -> Stdlib.exit 0
      | SDL.At (x, y) ->
          mouse := { !mouse with p_x = x; p_y = y };
          fresh := true
      | SDL.Button (b, down) ->
          let m = !mouse in
          let held =
            if down then m.p_buttons lor b else m.p_buttons land lnot b in
          mouse := { m with p_buttons = held };
          fresh := true
      | e -> List.iter key (SDL.typed keys now e))
      ((Lazy.force display).poll ());
    Option.iter key (SDL.repeated keys now)
  end

(* a word as tiny-kernel writes one, 4 bytes, the low first: the mouse's
 * box's, an entry's *)
let word v = String.init 4 (fun k -> Char.chr ((v asr (8 * k)) land 255))

(*****************************************************************************)
(* The window's descriptors *)
(*****************************************************************************)

(* the descriptors the window makes: a dial's question, its answer, a
 * voice of the speaker *)
type made =
  | Asking of Buffer.t
  | Answer of string list ref
  | Speaker of int ref
let made : (fd, made) Hashtbl.t = Hashtbl.create 8

(* a descriptor made, its number a reserved one *)
let opened (m : made) : fd =
  let n = reserve () in
  Hashtbl.replace made n m;
  n

(* what can be read without waiting: a key, the mouse, an answer; a
 * file's descriptor always *)
let can_read n =
  (n = fd_stdin && !typed <> "")
  || (n = fd_mouse && (!fresh || !size_asked))
  || (match Hashtbl.find_opt made n with
      | Some (Asking _) -> false
      | Some _ -> true
      | None -> n > fd_mouse)

(*****************************************************************************)
(* The wire's port 70 *)
(*****************************************************************************)

(* tiny-machine-fetch's output for its arguments, or why not; beside
 * this program, as tiny-machine finds it, or in dune's _build, from
 * tiny/user/sdl/ (old: ../TinyMachine/, from tiny/sdl/, where the
 * programs were built before 6ccdff26) *)
let fetch args =
  let dir = Filename.dirname Sys.executable_name in
  let helper =
    if Filename.check_suffix Sys.executable_name ".exe" then
      Filename.concat dir "../../TinyMachine/TinyMachineFetch.exe"
    else Filename.concat dir "tiny-machine-fetch" in
  let ic = Unix.open_process_args_in helper (Array.of_list (helper :: args)) in
  let out = In_channel.input_all ic in
  match Unix.close_process_in ic with Unix.WEXITED 0 -> Ok out | _ -> Error out

(* a copy kept in TINY_WWW's directory, by its name *)
let kept name = match Sys.getenv_opt "TINY_WWW", name with
  | Some dir, Some n when Sys.file_exists (Filename.concat dir n) ->
      Some (Filename.concat dir n)
  | _ -> None

(* the answer to a line asked of port 70, its messages *)
let answer line =
  match String.split_on_char ' ' (String.trim line) with
  | "GET" :: _ when Peer.www_request line <> None ->
      let url = Option.get (Peer.www_request line) in
      Peer.messages (match fetch [ url ] with
        | Ok answer -> answer
        | Error why -> (
            match kept (Peer.www_kept url) with
            | Some f ->
                Peer.www_kept_response f
                  (In_channel.with_open_bin f In_channel.input_all)
            | None -> Peer.www_failed why))
  | "img" :: _ ->
      let w, h, url =
        Option.get (Peer.www_picture_request (String.trim line)) in
      let decode source =
        match fetch [ "-picture"; string_of_int w; string_of_int h; source ] with
        | Ok pixels when String.length pixels = w * h ->
            Some (Peer.picture "" w h pixels)
        | _ -> None in
      (match if w = 0 then None else decode url with
       | Some l -> l
       | None -> (
           match
             Option.bind (kept (Peer.www_picture_kept url)) decode
           with
           | Some l -> l
           | None -> Peer.picture "" 0 0 ""))
  | _ -> []

(*****************************************************************************)
(* The calls *)
(*****************************************************************************)

(* the window shown, its events read, its sound fed, at each wait *)
let rec ready (fds : fd list) (until : milliseconds option) : fd option =
  show ();
  pump ();
  feed ();
  match List.find_opt can_read fds with
  | Some n -> Some n
  | None ->
      (match until with
       | Some t when now () >= t -> None
       | _ -> Unix.sleepf 0.005; ready fds until)

let read (n : fd) (max : int) : string =
  if n = fd_stdin then begin
    ignore (ready [ fd_stdin ] None);
    let k = min max (String.length !typed) in
    let s = String.sub !typed 0 k in
    typed := String.sub !typed k (String.length !typed - k);
    s
  end
  else if n = fd_mouse then begin
    if !size_asked then (
      size_asked := false;
      word width ^ word height ^ word (-1))
    else (
      let m = !mouse in
      fresh := false;
      word m.p_x ^ word m.p_y ^ word m.p_buttons)
  end
  else
    match Hashtbl.find_opt made n with
    | Some (Answer ({ contents = m :: rest } as left)) ->
        if String.length m <= max then (left := rest; m)
        else (
          left := String.sub m max (String.length m - max) :: rest;
          String.sub m 0 max)
    | Some _ -> ""
    | None -> TinyLibSystemUnix.read n max

let write (n : fd) (s : string) : unit =
  if n = fd_draw then draw s
  else if n = fd_stdout && s = enq then size_asked := true
  else
    match Hashtbl.find_opt made n with
    | Some (Speaker ahead) -> speak ahead s
    | Some (Asking b) ->
        Buffer.add_string b s;
        let asked = Buffer.contents b in
        (match String.index_opt asked '\n' with
         | Some i ->
             Hashtbl.replace made n (Answer (ref (answer (String.sub asked 0 i))))
         | None -> ())
    | Some (Answer _) -> ()
    | None -> TinyLibSystemUnix.write n s

let close (n : fd) : unit =
  if Hashtbl.mem made n then (Hashtbl.remove made n; Unix.close (fd n))
  else TinyLibSystemUnix.close n

(* /dev/audio, a voice; the speaker started at the first open, and what
 * was written heard to its end, as tiny-kernel's speaker plays on after
 * a program ends *)
let open_out (caps : < Cap.open_out; .. >) (file : Fpath.t) : fd =
  if Fpath.to_string file <> "/dev/audio" then TinyLibSystemUnix.open_out caps file
  else begin
    if !started = None then begin
      started := Some (Unix.gettimeofday ());
      at_exit (fun () ->
        let last =
          Hashtbl.fold
            (fun _ m k -> match m with Speaker a -> max k !a | _ -> k)
            made 0 in
        while !fed < last + 1600 do feed (); Unix.sleepf 0.02 done;
        while (Lazy.force display).queued () > 0 do Unix.sleepf 0.02 done)
    end;
    opened (Speaker (ref 0))
  end

(* the window's keys are raw already: ^C a key *)
let raw_console (_ : < Cap.keyboard; .. >) (_ : bool) = ()

(* /bin/play is tiny-play, else m-ix's mini-play (/bin/page: mini-page,
 * there is no tiny-page): in the bin/ this program was run from, beside
 * its executable (dune's _build, where tiny-play is play.exe), or on the
 * PATH *)
let spawn (_ : < Cap.fork; Cap.exec; .. >) (file : Fpath.t)
    (argv : string list) : pid option =
  let name = Filename.basename (Fpath.to_string file)
  and exe = Sys.executable_name and argv0 = Sys.argv.(0) in
  let dirs =
    (if String.contains argv0 '/' then [ Filename.dirname argv0 ] else [])
    @ [ Filename.dirname exe ]
    @ String.split_on_char ':'
        (Option.value (Sys.getenv_opt "PATH") ~default:"") in
  let names = [ "tiny-" ^ name; "mini-" ^ name ] in
  let found =
    List.find_opt Sys.file_exists
      (Filename.concat (Filename.dirname exe) (name ^ ".exe")
       :: List.concat_map
            (fun d -> List.map (Filename.concat d) names)
            (List.filter (( <> ) "") dirs)) in
  match found with
  | None -> None
  | Some prog -> (
      let args = match argv with _ :: rest -> rest | [] -> [] in
      flush_all ();
      try
        Some
          (Unix.create_process prog (Array.of_list (prog :: args)) Unix.stdin
             Unix.stdout Unix.stderr)
      with Unix.Unix_error _ -> None)

let dial (_ : < Cap.network; .. >) (address : string) (port : int) : fd =
  if address = "10.0.0.1" && port = 70 then opened (Asking (Buffer.create 64))
  else failwith ("no wire on the host to " ^ address ^ ": the window answers \
                  port 70 of 10.0.0.1 alone")
