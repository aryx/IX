(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Kweb.mli *)

let buf = Bytes.create 8
let keys = ref Hid.keyboard

(* at most so many at a tick: a tick must end *)
let most = 16

let clock () =
  let byte i = Char.code (Bytes.get buf i) in
  let rec ask left =
    if left > 0 then
      match Machine.web_input buf with
      | 1 ->
          let k, codes = Hid.typed !keys (Bytes.to_string buf) in
          keys := k;
          List.iter (fun s -> for i = 0 to String.length s - 1 do Kbd.kbdputsc (Char.code s.[i]) done) codes;
          ask (left - 1)
      | 2 ->
          Devmouse.at (byte 1 lor (byte 2 lsl 8)) (byte 3 lor (byte 4 lsl 8)) (byte 0);
          ask (left - 1)
      | _ -> () in
  ask most
