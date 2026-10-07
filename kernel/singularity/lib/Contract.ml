(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Contract.mli *)

type side = Imp | Exp

type carries =
  | Nothing
  | Block
  | Endpoint of string * side

type message = {
  label : string;
  from : side;
  carries : carries;
}

type t = {
  name : string;
  messages : message array;
  states : (string * (int * int) list) array;
}

let message (label : string) (from : side) (carries : carries) : message = { label; from; carries }
let make (name : string) (messages : message array) (states : (string * (int * int) list) array) : t = { name; messages; states }

(* Lines of words: the name; "m label side carries" a message, the
 * carries "-", "b", or "e" a contract's name and a side; "s name
 * tag>next ..." a state. *)
let side (s : side) : string = match s with Imp -> "i" | Exp -> "x"

let encode (c : t) : string =
  let b = Buffer.create 256 in
  Buffer.add_string b (c.name ^ "\n");
  Array.iter (fun (m : message) ->
    let carried = match m.carries with Nothing -> "-" | Block -> "b" | Endpoint (n, s) -> "e " ^ n ^ " " ^ side s in
    Buffer.add_string b (Printf.sprintf "m %s %s %s\n" m.label (side m.from) carried)) c.messages;
  Array.iter (fun ((state, l) : string * (int * int) list) ->
    Buffer.add_string b ("s " ^ state);
    List.iter (fun ((tag, next) : int * int) -> Buffer.add_string b (Printf.sprintf " %d>%d" tag next)) l;
    Buffer.add_string b "\n") c.states;
  Buffer.contents b

exception Bad

let decode (s : string) : t option =
  let a_side (w : string) : side = match w with "i" -> Imp | "x" -> Exp | _ -> raise Bad in
  let number (w : string) : int = match int_of_string_opt w with Some n when n >= 0 -> n | _ -> raise Bad in
  try
    match String.split_on_char '\n' s with
    | [] -> None
    | name :: lines ->
        let messages = ref [] and states = ref [] in
        List.iter (fun (line : string) ->
          match String.split_on_char ' ' line with
          | [ "m"; label; from; "-" ] -> messages := { label; from = a_side from; carries = Nothing } :: !messages
          | [ "m"; label; from; "b" ] -> messages := { label; from = a_side from; carries = Block } :: !messages
          | [ "m"; label; from; "e"; n; sd ] -> messages := { label; from = a_side from; carries = Endpoint (n, a_side sd) } :: !messages
          | "s" :: state :: moves ->
              states := (state, List.map (fun (w : string) ->
                match String.split_on_char '>' w with
                | [ tag; next ] -> (number tag, number next)
                | _ -> raise Bad) moves) :: !states
          | [ "" ] -> ()
          | _ -> raise Bad) lines;
        let c = { name; messages = Array.of_list (List.rev !messages); states = Array.of_list (List.rev !states) } in
        (* a state's moves name messages and states that are *)
        Array.iter (fun ((_, l) : string * (int * int) list) ->
          List.iter (fun ((tag, next) : int * int) ->
            if tag >= Array.length c.messages || next >= Array.length c.states then raise Bad) l) c.states;
        if name = "" || Array.length c.states = 0 then None else Some c
  with Bad -> None
