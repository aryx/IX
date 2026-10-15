(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMachineWeb.mli *)

module Js = Js_of_ocaml.Js
module U = Js_of_ocaml.Js.Unsafe

let call o name args = U.meth_call o name args
let str s = U.inject (Js.string s)
let get o name = U.get o (Js.string name)
let document = get U.global "document"
let element id = call document "getElementById" [| str id |]
let listen o name f = ignore (call o "addEventListener" [| str name; U.inject (Js.wrap_callback f) |])
(* whether the page has the element asked for (getElementById's null) *)
let present e = Js.Opt.test (Obj.magic e : U.any Js.opt)
let now () : float = Js.float_of_number (call (get U.global "performance") "now" [||])

(*****************************************************************************)
(* The console: the machine's bytes as the page's text *)
(*****************************************************************************)

(* the last [kept] bytes; a backspace takes one back *)
let kept = 20000
let text = Buffer.create 1024
let text_changed = ref false

let put ch =
  (match ch with
   | '\b' -> if Buffer.length text > 0 then Buffer.truncate text (Buffer.length text - 1)
   | '\r' -> ()
   | ch -> Buffer.add_char text ch);
  if Buffer.length text > 2 * kept then begin
    let last = Buffer.sub text (Buffer.length text - kept) kept in
    Buffer.clear text; Buffer.add_string text last
  end;
  text_changed := true

(* the line being typed, a terminal's (see the keys), shown after the
 * text with its cursor: an element of its own (the page's style makes
 * it a block that blinks), put back after the text each time, since
 * setting the text removes it *)
let line = Buffer.create 80
let cursor = lazy (
  let c = call document "createElement" [| str "span" |] in
  U.set c (Js.string "id") (Js.string "cursor");
  U.set c (Js.string "textContent") (Js.string "\xc2\xa0");
  c)

let show_text () =
  if !text_changed then begin
    text_changed := false;
    let e = element "console" in
    U.set e (Js.string "textContent") (Js.bytestring (Buffer.contents text ^ Buffer.contents line));
    ignore (call e "appendChild" [| U.inject (Lazy.force cursor) |]);
    U.set e (Js.string "scrollTop") (get e "scrollHeight")
  end

let status s = U.set (element "status") (Js.string "textContent") (Js.string s)

(*****************************************************************************)
(* The keys and the mouse *)
(*****************************************************************************)

(* a key's byte: the arrows 128 to 131 (up, down, left, right),
 * tiny-machine's choice; control with a letter its control character *)
let key_byte e =
  let key = Js.to_string (get e "key") and ctrl = Js.to_bool (get e "ctrlKey") in
  match key with
  | "Enter" -> Some 10 | "Backspace" -> Some 8 | "Tab" -> Some 9 | "Escape" -> Some 27 | "Delete" -> Some 127
  | "ArrowUp" -> Some 128 | "ArrowDown" -> Some 129 | "ArrowLeft" -> Some 130 | "ArrowRight" -> Some 131
  | _ when String.length key = 1 && Char.code key.[0] < 127 ->
      let c = Char.code key.[0] in
      if Js.to_bool (get e "metaKey") then None else if ctrl then Some (c land 31) else Some c
  | _ -> None

(* whether a program has drawn on the screen (a pixel not black), and
 * whether the keys are the screen's: it has the focus, and is drawn on *)
let lit = ref false
let screen_keys () = !lit && get document "activeElement" == element "screen"

(* a terminal's key: the line edited and echoed, given at Enter; ^C at
 * once, as a terminal's interrupt (tiny-kernel kills the program
 * running) *)
let terminal_key (mc : TinyMachineDevices.machine) b =
  (match b with
   | 3 -> TinyMachineDevices.console_type mc.cons "\003"
   | 8 | 127 -> if Buffer.length line > 0 then Buffer.truncate line (Buffer.length line - 1)
   | 10 ->
       Buffer.add_char line '\n';
       Buffer.add_buffer text line;
       TinyMachineDevices.console_type mc.cons (Buffer.contents line);
       Buffer.clear line
   | b when b >= 32 && b < 127 -> Buffer.add_char line (Char.chr b)
   | _ -> ());
  text_changed := true

let listen_keys (mc : TinyMachineDevices.machine) =
  listen document "keydown" (fun e ->
    match key_byte e with
    | Some b ->
        if screen_keys () then TinyMachineDevices.console_type mc.cons (String.make 1 (Char.chr b)) else terminal_key mc b;
        ignore (call e "preventDefault" [||])
    | None -> ())

(* the place in the canvas's own pixels (the page may show it larger);
 * the browser's buttons are 1 left, 2 right, 4 middle, the machine's 1
 * left, 2 middle, 4 right, as Plan 9's *)
let listen_mouse (mc : TinyMachineDevices.machine) canvas =
  let int_of o name : int = truncate (Js.float_of_number (get o name)) in
  let moved e =
    let scaled v shown full = if shown > 0 then v * full / shown else v in
    let x = scaled (int_of e "offsetX") (int_of canvas "clientWidth") TinyMachineDevices.width
    and y = scaled (int_of e "offsetY") (int_of canvas "clientHeight") TinyMachineDevices.height
    and b = int_of e "buttons" in
    TinyMachineDevices.mouse_set mc.mouse x y ((b land 1) lor (if b land 2 <> 0 then 4 else 0) lor (if b land 4 <> 0 then 2 else 0));
    ignore (call e "preventDefault" [||]) in
  List.iter (fun name -> listen canvas name moved) [ "mousemove"; "mousedown"; "mouseup" ];
  (* (the focus by hand: the default, prevented above, would give it) *)
  listen canvas "mousedown" (fun _ -> ignore (call canvas "focus" [||]));
  listen canvas "contextmenu" (fun e -> ignore (call e "preventDefault" [||]))

(*****************************************************************************)
(* The screen: a canvas *)
(*****************************************************************************)

(* A canvas's pixel is four bytes, red, green, blue and how opaque: as
 * one word of 32 bits (the browsers' machines being little-endian),
 * the screen's byte is one store, through the table of its 256 colours *)
type screen = { context : U.any; picture : U.any; words : U.any; palette : int array; mutable shown : string }

let screen_open canvas =
  let context = call canvas "getContext" [| str "2d" |] in
  let picture = call context "createImageData" [| U.inject TinyMachineDevices.width; U.inject TinyMachineDevices.height |] in
  let words = U.new_obj (get U.global "Uint32Array") [| U.inject (get (get picture "data") "buffer") |] in
  let c k = Char.code TinyMachineDevices.colours.[k] in
  let palette = Array.init 256 (fun i -> (255 lsl 24) lor (c ((3 * i) + 2) lsl 16) lor (c ((3 * i) + 1) lsl 8) lor c (3 * i)) in
  { context; picture; words; palette; shown = "" }

let screen_show s (m : TinyMachineCPU.machine) =
  let n = TinyMachineDevices.width * TinyMachineDevices.height in
  let pixels = Bytes.sub_string m.mem TinyMachineDevices.screen n in
  if pixels <> s.shown then begin
    s.shown <- pixels;
    let any = ref 0 in
    for i = 0 to n - 1 do
      let c = Char.code (String.unsafe_get pixels i) in
      any := !any lor c;
      U.set s.words i s.palette.(c)
    done;
    lit := !any <> 0;
    ignore (call s.context "putImageData" [| U.inject s.picture; U.inject 0; U.inject 0 |])
  end

(* a file from beside the page, its bytes; k with None if it is not there *)
let fetch name k =
  let failed _ = k None in
  let bytes buffer = k (Some (Js_of_ocaml.Typed_array.String.of_arrayBuffer buffer)) in
  let got response =
    if Js.to_bool (get response "ok") then ignore (call (call response "arrayBuffer" [||]) "then" [| U.inject (Js.wrap_callback bytes); U.inject (Js.wrap_callback failed) |])
    else failed () in
  ignore (call (call U.global "fetch" [| str name |]) "then" [| U.inject (Js.wrap_callback got); U.inject (Js.wrap_callback failed) |])

(*****************************************************************************)
(* The network: the wire's other end is the page *)
(*****************************************************************************)

(* What the machine's wire leads to (TinyMachinePeer: tiny-kernel's own
 * stack, by OCaml, with its answers to a ping and to port 70). The
 * page gives it its documents, which is where the Internet comes in:
 * a name is a file beside the page (get); "wiki words" is Wikipedia's
 * article for the words, its first sentences and its picture. The
 * machine speaks IL to this end of its wire, and this end asks the
 * Internet as a page may: by fetch, from the sites that allow it.
 * Names, TLS, HTTP, JSON and a picture's format are the browser's. *)

(* a text for the console: its bytes over 127 (UTF-8's) a ?, each
 * character once, and lines of 72 at most. Wikipedia's text has its
 * formulas twice, as a column of indented symbols and as TeX in
 * braces: the indented and the empty lines are left out, and the
 * braces with what is in them *)
let plain s =
  let lines = List.filter (fun l -> l <> "" && l.[0] <> ' ') (String.split_on_char '\n' s) in
  let s = match lines with title :: rest -> title ^ "\n" ^ String.concat " " rest | [] -> "" in
  let depth = ref 0 in
  let s = String.concat "" (List.map (fun c ->
    if c = '{' then (incr depth; "") else if c = '}' then (depth := max 0 (!depth - 1); "") else if !depth > 0 then "" else String.make 1 c)
    (List.of_seq (String.to_seq s))) in
  let b = Buffer.create (String.length s) and col = ref 0 and space = ref false in
  String.iter (fun c ->
    let c = if Char.code c >= 0xc0 then Some '?' else if Char.code c >= 0x80 then None else Some c in
    match c with
    | None -> ()
    | Some '\n' -> Buffer.add_char b '\n'; col := 0; space := false
    (* (a space is written when a word follows: where a formula was,
     * two spaces, or one before a comma, are none) *)
    | Some ' ' -> space := true
    | Some c ->
        if !space && c <> ',' && c <> '.' && c <> ')' then (if !col >= 64 then (Buffer.add_char b '\n'; col := 0) else (Buffer.add_char b ' '; incr col));
        space := false;
        Buffer.add_char b c; incr col) s;
  Buffer.contents b ^ "\n"

(* the screen's colour nearest to one of 15 bits (5 of red, of green,
 * of blue), found once each *)
let nearest =
  let known = Array.make 32768 (-1) in
  fun r g b ->
    let key = ((r lsr 3) lsl 10) lor ((g lsr 3) lsl 5) lor (b lsr 3) in
    if known.(key) < 0 then begin
      let best = ref 0 and least = ref max_int in
      for i = 0 to 255 do
        let c k = Char.code TinyMachineDevices.colours.[(3 * i) + k] in
        let d = ((c 0 - r) * (c 0 - r)) + ((c 1 - g) * (c 1 - g)) + ((c 2 - b) * (c 2 - b)) in
        if d < !least then (least := d; best := i)
      done;
      known.(key) <- !best
    end;
    known.(key)

(* a picture at an address, reduced: no larger than 320 by 240, in its
 * proportions, a byte a pixel (the browser reads its format and makes
 * it smaller, on a canvas that is not shown; each pixel is then the
 * nearest of the screen's 256 colours, no dithering). k with its
 * width, its height, its rows; None if it cannot be had *)
(* a picture loaded by the browser, at the size [size] gives from its
 * own (w and h), drawn on a canvas and read back in the screen's
 * colours *)
let picture_sized url size k =
  let img = U.new_obj (get U.global "Image") [||] in
  U.set img (Js.string "crossOrigin") (Js.string "anonymous");
  listen img "error" (fun _ -> k None);
  listen img "load" (fun _ ->
    let iw : int = get img "naturalWidth" and ih : int = get img "naturalHeight" in
    if iw <= 0 || ih <= 0 then k None
    else begin
      let w, h = size iw ih in
      let canvas = call document "createElement" [| str "canvas" |] in
      U.set canvas (Js.string "width") w; U.set canvas (Js.string "height") h;
      let context = call canvas "getContext" [| str "2d" |] in
      (* (white under a picture with holes) *)
      U.set context (Js.string "fillStyle") (Js.string "white");
      ignore (call context "fillRect" [| U.inject 0; U.inject 0; U.inject w; U.inject h |]);
      ignore (call context "drawImage" [| U.inject img; U.inject 0; U.inject 0; U.inject w; U.inject h |]);
      match (try Some (get (call context "getImageData" [| U.inject 0; U.inject 0; U.inject w; U.inject h |]) "data") with _ -> None) with
      | None -> k None
      | Some data ->
          let at i : int = U.get data i in
          k (Some (w, h, String.init (w * h) (fun i -> Char.chr (nearest (at (4 * i)) (at ((4 * i) + 1)) (at ((4 * i) + 2))))))
    end);
  U.set img (Js.string "src") (Js.string url)

(* at most 320 by 240, for wiki *)
let picture url k =
  picture_sized url (fun iw ih ->
    let w, h = if iw * 240 > ih * 320 then 320, max 1 (ih * 320 / iw) else max 1 (iw * 240 / ih), 240 in
    if iw <= w then iw, ih else w, h) k

(* Wikipedia on some words: one request, a search whose five best
 * articles come with their first sentences and a picture's address;
 * the first that is not a list of meanings ("... may refer to:") is
 * taken. k with its messages for wiki (TinyMachinePeer.picture: the title
 * and the text, then the picture if it has one), None when Wikipedia
 * is not reached or has nothing *)
let wikipedia words k =
  let encoded : string = Js.to_string (U.fun_call (get U.global "encodeURIComponent") [| str words |]) in
  let url =
    "https://en.wikipedia.org/w/api.php?action=query&generator=search&gsrlimit=5&prop=extracts%7Cpageimages&exintro=1&explaintext=1"
    ^ "&exsentences=3&exlimit=5&pilimit=5&pithumbsize=320&format=json&origin=*&gsrsearch=" ^ encoded in
  fetch url (function
    | None -> k None
    | Some json ->
        let field o name = Js.Optdef.to_option (get o name) in
        let pages =
          try
            let answer = call (get U.global "JSON") "parse" [| str json |] in
            match Option.bind (field answer "query") (fun q -> field q "pages") with
            | Some pages -> Array.to_list (Js.to_array (call (get U.global "Object") "values" [| U.inject pages |]))
            | None -> []
          with _ -> [] in
        let text p name = match field p name with Some v -> Js.to_string v | None -> "" in
        let rank p : int = match field p "index" with Some i -> i | None -> 99 in
        let meanings p = let e = String.trim (text p "extract") in String.length e > 9 && String.sub e (String.length e - 9) 9 = "refer to:" in
        match List.sort (fun a b -> compare (rank a) (rank b)) (List.filter (fun p -> text p "extract" <> "" && not (meanings p)) pages) with
        | [] -> k None
        | p :: _ ->
            let said = plain (text p "title" ^ "\n" ^ text p "extract") in
            match Option.bind (field p "thumbnail") (fun t -> field t "source") with
            | None -> k (Some (TinyMachinePeer.picture said 0 0 ""))
            | Some source ->
                picture (Js.to_string source) (function
                  | Some (w, h, pixels) -> k (Some (TinyMachinePeer.picture said w h pixels))
                  | None -> k (Some (TinyMachinePeer.picture said 0 0 ""))))

(* a line's document: the messages given to [messages], when they are
 * there. [www] is where the page's own documents are; a wiki that
 * Wikipedia does not answer is a picture kept there, if there is one.
 * "www address" is a web page for tiny-kernel's browser, fetched by this
 * page (Wikipedia's REST HTML allows it; a site that does not allow
 * other pages to fetch it, by CORS, cannot be reached from here); if
 * the fetch fails, a kept copy beside the page answers *)
let peer_document www line messages =
  let name ok = if line = "" || line.[0] = '.' || String.contains line '/' then None else Some ok in
  if String.length line > 4 && String.sub line 0 4 = "img " then begin
    (* a page's picture at the size asked; a kept copy beside the page
     * when the site does not allow this page to read its pictures *)
    let none = TinyMachinePeer.picture "" 0 0 "" in
    match String.split_on_char ' ' (String.sub line 4 (String.length line - 4)) with
    | w :: h :: address when int_of_string_opt w <> None && int_of_string_opt h <> None ->
        let w = int_of_string w and h = int_of_string h and url = String.concat " " address in
        let answer = function Some (w, h, pixels) -> messages (TinyMachinePeer.picture "" w h pixels) | None -> messages none in
        picture_sized url (fun _ _ -> w, h) (function
          | Some p -> answer (Some p)
          | None ->
              match TinyMachinePeer.www_picture_kept url with
              | Some name -> picture_sized (www ^ name) (fun _ _ -> w, h) answer
              | None -> answer None)
    | _ -> messages none
  end
  else if String.length line > 4 && String.sub line 0 4 = "www " then begin
    let url = TinyMachinePeer.www_address (String.sub line 4 (String.length line - 4)) in
    let failed () = messages [ "www: " ^ url ^ ": not reached (no network, or the site does not allow a web page to fetch it)\n" ] in
    fetch url (function
      | Some page -> messages (TinyMachinePeer.messages page)
      | None ->
          match TinyMachinePeer.www_kept url with
          | Some kept -> fetch (www ^ kept) (function Some page -> messages (TinyMachinePeer.messages page) | None -> failed ())
          | None -> failed ())
  end
  else if String.length line > 5 && String.sub line 0 5 = "wiki " then begin
    let words = String.sub line 5 (String.length line - 5) in
    wikipedia words (function
      | Some l -> messages l
      | None ->
          let kept = String.map (fun c -> if c = ' ' then '_' else Char.lowercase_ascii c) words ^ ".wiki" in
          let nothing () = messages (TinyMachinePeer.picture ("wiki: Wikipedia does not answer, and nothing is kept on " ^ words ^ "\n") 0 0 "") in
          if String.contains kept '/' then nothing ()
          else fetch (www ^ kept) (fun file -> match Option.bind file TinyMachinePeer.kept with Some l -> messages l | None -> nothing ()))
  end
  else
    match name line with
    | None -> messages [ "get: no " ^ line ^ "\n" ]
    | Some name -> fetch (www ^ name) (function Some text -> messages (TinyMachinePeer.messages text) | None -> messages [ "get: no " ^ name ^ "\n" ])

(*****************************************************************************)
(* The wire, drawn *)
(*****************************************************************************)

(* A network does not show itself as a screen does. So the page draws
 * the wire: the machine at the left, this page's end at the right, a
 * dot for each packet, which crosses in half a second of the page's
 * time (the packet itself took 5 ms of the machine's: too fast to
 * see), and falls when it is lost; under it, each packet's line, as
 * tiny-machine -net-trace says it. A page without these elements has
 * the network all the same. *)
type dot = { born : float; to_machine : bool; lost : bool; colour : string }

let dots = ref []
let lost = ref 0
let wire_lines = ref []
let wire_changed = ref false
let crossing = 500.

let wire_said dir packet =
  let line = TinyMachinePeer.net_describe packet in
  (* (without ", from 10.0.0.2 to 10.0.0.1": the direction says it) *)
  let line = if String.length line > 27 && String.sub line (String.length line - 27) 7 = ", from " then String.sub line 0 (String.length line - 27) else line in
  let starts p = String.length line >= String.length p && String.sub line 0 (String.length p) = p in
  let colour = if dir = "x" then "#cc0000" else if starts "data" then "#0055aa" else if starts "query" || starts "state" then "#dd8800"
    else if starts "echo" then "#222222" else if starts "ack" then "#999999" else "#228822" in
  dots := { born = now (); to_machine = dir <> ">"; lost = dir = "x"; colour } :: !dots;
  (* the button says how many it lost *)
  if dir = "x" then begin
    incr lost;
    let button = element "lose" in
    if present button then U.set button (Js.string "textContent") (Js.string (Printf.sprintf "lose the next packet (%d lost so far)" !lost))
  end;
  wire_lines := (dir ^ " " ^ line) :: (match !wire_lines with a :: b :: c :: d :: e :: f :: g :: _ -> [ a; b; c; d; e; f; g ] | l -> l);
  wire_changed := true

let wire_show () =
  let canvas = element "wire" in
  if present canvas then begin
    let t = now () in
    let was = !dots <> [] in
    dots := List.filter (fun d -> t -. d.born < crossing) !dots;
    if was || !wire_changed then begin
      let c = call canvas "getContext" [| str "2d" |] in
      let set name v = U.set c (Js.string name) (Js.string v) in
      let w : int = get canvas "width" and h : int = get canvas "height" in
      ignore (call c "clearRect" [| U.inject 0; U.inject 0; U.inject w; U.inject h |]);
      set "strokeStyle" "#444444"; set "fillStyle" "#444444"; set "font" "12px sans-serif";
      ignore (call c "beginPath" [||]);
      ignore (call c "moveTo" [| U.inject 100; U.inject 20 |]);
      ignore (call c "lineTo" [| U.inject (w - 130); U.inject 20 |]);
      ignore (call c "stroke" [||]);
      ignore (call c "fillText" [| str "the machine"; U.inject 4; U.inject 18 |]);
      ignore (call c "fillText" [| str "10.0.0.2"; U.inject 4; U.inject 34 |]);
      ignore (call c "fillText" [| str "this page: the Internet"; U.inject (w - 126); U.inject 18 |]);
      ignore (call c "fillText" [| str "10.0.0.1"; U.inject (w - 126); U.inject 34 |]);
      List.iter (fun d ->
        let f = (t -. d.born) /. crossing in
        let along = if d.lost then Float.min f 0.5 else f in
        let along = if d.to_machine then 1. -. along else along in
        let x = 100. +. (along *. float_of_int (w - 230)) in
        let y = if d.lost && f > 0.5 then 20. +. ((f -. 0.5) *. 2. *. float_of_int (h - 24)) else 20. in
        set "fillStyle" d.colour;
        ignore (call c "beginPath" [||]);
        ignore (call c "arc" [| U.inject x; U.inject y; U.inject 4; U.inject 0; U.inject 6.3 |]);
        ignore (call c "fill" [||])) !dots
    end;
    if !wire_changed then begin
      wire_changed := false;
      let log = element "wirelog" in
      if present log then U.set log (Js.string "textContent") (Js.string (String.concat "\n" (List.rev !wire_lines)))
    end
  end

(*****************************************************************************)
(* The loop: a frame's instructions, then what is shown *)
(*****************************************************************************)

(* the milliseconds of a frame the machine may take *)
let budget = 12.

let run image disk www =
  let on_open (k : TinyMachineDevices.console) = k.opened <- true in
  (* the wire's other end, which gives packets to the machine it is
   * called by: by a reference *)
  let machine = ref None in
  let give after packet = Option.iter (fun mc -> TinyMachineDevices.net_give mc ~after packet) !machine in
  let peer = TinyMachinePeer.create ~give ~said:wire_said ~document:(peer_document www) ~outside:None in
  let mc : TinyMachineDevices.machine = TinyMachineDevices.create ~put ~on_open ~send:(Some (TinyMachinePeer.send peer)) ~disk ~events:None image in
  machine := Some mc;
  (* the page's button: the peer's next packet is lost *)
  let button = element "lose" in
  if present button then listen button "click" (fun _ -> TinyMachinePeer.lose peer 1);
  let env = TinyMachineDevices.env mc in
  let canvas = element "screen" in
  let screen = screen_open canvas in
  listen_keys mc; listen_mouse mc canvas;
  text_changed := true;
  let last = ref (now ()) and running = ref true in
  (* the speed shown: the instructions and the time since it was said *)
  let done_ = ref 0 and since = ref (now ()) in
  let rec frame _ =
    let start = now () in
    (* a quarter of a second at most: a page left and come back to *)
    let due = truncate (float_of_int !TinyMachineDevices.rate *. Float.min 0.25 ((start -. !last) /. 1000.)) in
    last := start;
    (try
       let n = ref 0 in
       while !n < due && now () -. start < budget do
         TinyMachineDevices.ticks mc env (min 4096 (due - !n));
         n := !n + min 4096 (due - !n)
       done;
       done_ := !done_ + !n
     with
     | TinyMachineDevices.Halt code -> running := false; status (Printf.sprintf "the machine halted (%d); reload the page to boot it again" code)
     | TinyMachineCPU.Error e -> running := false; status ("tiny-machine: " ^ e));
    screen_show screen mc.cpu; show_text (); wire_show ();
    if !running then begin
      if start -. !since > 1000. then begin
        (* of the speed the machine is meant to have *)
        let percent = truncate (100. *. float_of_int !done_ /. ((start -. !since) /. 1000. *. float_of_int !TinyMachineDevices.rate)) in
        status (if percent >= 97 then "Running at full speed."
                else Printf.sprintf "Running at %d%% of full speed in this browser: everything is that much slower." percent);
        done_ := 0; since := start
      end;
      ignore (call U.global "requestAnimationFrame" [| U.inject (Js.wrap_callback frame) |])
    end in
  frame ()

let () =
  let search = U.new_obj (get U.global "URLSearchParams") [| U.inject (get (get U.global "location") "search") |] in
  let text v = Js.Opt.to_option (Js.Opt.map (Js.Opt.option (Js.Optdef.to_option v)) Js.to_string) in
  let page = Js.Optdef.to_option (get U.global "tiny_machine") in
  let param name =
    match page with
    | Some o -> text (get o name)
    | None -> Js.Opt.to_option (Js.Opt.map (call search "get" [| str name |]) Js.to_string) in
  let image = Option.value (param "image") ~default:"boot.img" in
  let missing name = status ("tiny-machine: " ^ name ^ " could not be fetched") in
  status ("loading " ^ image);
  fetch image (function
    | None -> missing image
    | Some bytes ->
        (* where the documents of the wire's other end are: beside the
         * image, in www/, unless the page says *)
        let www = match param "www" with
          | Some w -> w
          | None -> (match String.rindex_opt image '/' with Some i -> String.sub image 0 (i + 1) | None -> "") ^ "www/" in
        match param "disk" with
        | None -> run bytes Bytes.empty www
        | Some d -> fetch d (function None -> missing d | Some disk -> run bytes (Bytes.of_string disk) www))
