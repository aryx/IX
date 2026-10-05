(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* QEMU's machine protocol, the part xv6's graphical tests use
 * (scripts/qemu_graphics.py): on a Unix socket (-qmp unix:PATH,server,
 * nowait), JSON objects a line each; qmp_capabilities, query-status,
 * screendump (the framebuffer as a PPM file), send-key (keys by QEMU's
 * qcodes, held 100ms of the board's time, or hold-time), quit. Polled
 * between batches of instructions, never blocking. *)


(* QEMU's qcodes, as USB HID usages *)
let usage_of_qcode q =
  let letters = "abcdefghijklmnopqrstuvwxyz" in
  match q with
  | _ when String.length q = 1 && String.contains letters q.[0] -> Some (4 + String.index letters q.[0])
  | "0" -> Some 0x27
  | _ when String.length q = 1 && q.[0] >= '1' && q.[0] <= '9' -> Some (0x1e + Char.code q.[0] - Char.code '1')
  | "ret" -> Some 0x28 | "esc" -> Some 0x29 | "backspace" -> Some 0x2a | "tab" -> Some 0x2b | "spc" -> Some 0x2c
  | "minus" -> Some 0x2d | "equal" -> Some 0x2e | "bracket_left" -> Some 0x2f | "bracket_right" -> Some 0x30
  | "backslash" -> Some 0x31 | "semicolon" -> Some 0x33 | "apostrophe" -> Some 0x34 | "grave_accent" -> Some 0x35
  | "comma" -> Some 0x36 | "dot" -> Some 0x37 | "slash" -> Some 0x38 | "caps_lock" -> Some 0x39
  | "right" -> Some 0x4f | "left" -> Some 0x50 | "down" -> Some 0x51 | "up" -> Some 0x52
  | "ctrl" -> Some 0xe0 | "shift" -> Some 0xe1 | "alt" -> Some 0xe2 | "ctrl_r" -> Some 0xe4 | "shift_r" -> Some 0xe5 | "alt_r" -> Some 0xe6
  | _ -> None

type t = { server : Unix.file_descr; mutable clients : (Unix.file_descr * Buffer.t) list }

(* "unix:PATH,server,nowait" (or server=on,wait=off) *)
let create spec =
  match String.split_on_char ',' spec with
  | path :: _ when String.length path > 5 && String.sub path 0 5 = "unix:" ->
      let path = String.sub path 5 (String.length path - 5) in
      (try Unix.unlink path with Unix.Unix_error _ -> ());
      let s = Unix.socket PF_UNIX SOCK_STREAM 0 in
      Unix.bind s (ADDR_UNIX path);
      Unix.listen s 4;
      Unix.set_nonblock s;
      { server = s; clients = [] }
  | _ -> failwith ("mini-qemu: -qmp " ^ spec ^ ": only unix:PATH,server,nowait")

let send fd json =
  let s = Json.to_text json ^ "\r\n" in
  ignore (try Unix.write_substring fd s 0 (String.length s) with Unix.Unix_error _ -> 0)

let greeting =
  Json.Assoc [ "QMP", Json.Assoc [ "version", Json.Assoc [ "qemu", Json.Assoc [ "micro", Json.Int 0; "minor", Json.Int 2; "major", Json.Int 8 ]; "package", Json.String "mini-qemu" ];
                           "capabilities", Json.List [] ] ]

let ok = Json.Assoc [ "return", Json.Assoc [] ]
let error desc = Json.Assoc [ "error", Json.Assoc [ "class", Json.String "GenericError"; "desc", Json.String desc ] ]

(* an input event of input-send-event: the mouse's, a key's, or one
 * that does nothing (a wheel's release) *)
type event = Pointer_event of Usb.input | Key_event of int * bool | No_event

(* one command, its answer *)
(* claude: what QMP asks of a machine: the Pi1's board, the Pi4's *)
type machine = {
  screen : unit -> (int * int * string) option;
  send_keys : int list -> hold:int -> unit;
  key : int -> bool -> unit;
  pointer : Usb.input list -> unit;
}

let execute (board : machine) ~quit json =
  let args = try Json.member "arguments" json with _ -> Json.Null in
  match (try Json.member "execute" json |> Json.string with _ -> "") with
  | "qmp_capabilities" -> ok
  | "query-status" -> Json.Assoc [ "return", Json.Assoc [ "running", Json.Bool true; "status", Json.String "running" ] ]
  | "screendump" ->
      (match board.screen (), (try args |> Json.member "filename" |> Json.string with _ -> "") with
       | _, "" -> error "screendump: no filename"
       | None, _ -> error "no framebuffer yet"
       | Some s, f -> Out_channel.with_open_bin f (fun oc -> output_string oc (Framebuffer.ppm s)); ok)
  | "send-key" ->
      let keys = try args |> Json.member "keys" |> Json.list with _ -> [] in
      let hold = try args |> Json.member "hold-time" |> Json.int with _ -> 100 in
      let usages = List.filter_map (fun k -> try usage_of_qcode (k |> Json.member "data" |> Json.string) with _ -> None) keys in
      if List.length usages <> List.length keys then error "send-key: an unknown key"
      else (board.send_keys usages ~hold:(hold * 1000); ok)
  | "input-send-event" ->
      (* claude: QEMU's input events: relative motion and buttons to the
       * mouse (then synced, as one QMP command is), keys to the
       * keyboard *)
      let events = try args |> Json.member "events" |> Json.list with _ -> [] in
      let button = function
        | "left" -> Some (Usb.Button (1, true)) | "right" -> Some (Usb.Button (2, true))
        | "middle" -> Some (Usb.Button (4, true)) | "side" -> Some (Usb.Button (8, true))
        | "extra" -> Some (Usb.Button (16, true)) | "wheel-up" -> Some (Usb.Wheel (-1))
        | "wheel-down" -> Some (Usb.Wheel 1) | _ -> None in
      let one e =
        let data = Json.member "data" e in
        match Json.member "type" e |> Json.string with
        | "rel" ->
            let v = data |> Json.member "value" |> Json.int in
            (match data |> Json.member "axis" |> Json.string with "x" -> Some (Pointer_event (Usb.Rel_x v)) | "y" -> Some (Pointer_event (Usb.Rel_y v)) | _ -> None)
        | "btn" ->
            let down = data |> Json.member "down" |> Json.bool in
            (match button (data |> Json.member "button" |> Json.string) with
             | Some (Usb.Button (b, _)) -> Some (Pointer_event (Usb.Button (b, down)))
             | Some (Usb.Wheel v) -> if down then Some (Pointer_event (Usb.Wheel v)) else Some No_event
             | _ -> None)
        | "key" ->
            let down = data |> Json.member "down" |> Json.bool in
            (match usage_of_qcode (data |> Json.member "key" |> Json.member "data" |> Json.string) with
             | Some u -> Some (Key_event (u, down))
             | None -> None)
        | _ -> None in
      let parsed = List.map (fun e -> try one e with _ -> None) events in
      if List.mem None parsed then error "input-send-event: an event not handled"
      else begin
        let parsed = List.filter_map Fun.id parsed in
        List.iter (function Key_event (u, down) -> board.key u down | _ -> ()) parsed;
        let inputs = List.filter_map (function Pointer_event i -> Some i | _ -> None) parsed in
        if inputs <> [] then board.pointer inputs;
        ok
      end
  | "quit" -> quit (); ok
  | c -> Json.Assoc [ "error", Json.Assoc [ "class", Json.String "CommandNotFound"; "desc", Json.String ("The command " ^ c ^ " has not been found") ] ]

(* new clients greeted, complete lines run *)
let poll t (board : machine) ~quit =
  (match Unix.accept t.server with
   | fd, _ -> Unix.set_nonblock fd; send fd greeting; t.clients <- (fd, Buffer.create 256) :: t.clients
   | exception Unix.Unix_error ((EAGAIN | EWOULDBLOCK), _, _) -> ());
  let buf = Bytes.create 4096 in
  t.clients <- List.filter (fun (fd, b) ->
    match Unix.read fd buf 0 4096 with
    | 0 -> Unix.close fd; false
    | n ->
        Buffer.add_subbytes b buf 0 n;
        let text = Buffer.contents b in
        let lines = String.split_on_char '\n' text in
        let complete = List.filteri (fun i _ -> i < List.length lines - 1) lines in
        Buffer.clear b; Buffer.add_string b (List.nth lines (List.length lines - 1));
        List.iter (fun l ->
          if String.trim l <> "" then
            send fd (try execute board ~quit (Json.of_text l) with Json.Error m -> error m)) complete;
        true
    | exception Unix.Unix_error ((EAGAIN | EWOULDBLOCK), _, _) -> true
    | exception Unix.Unix_error _ -> Unix.close fd; false) t.clients
