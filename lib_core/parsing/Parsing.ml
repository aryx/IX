(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Parsing.mli *)

exception Parse_error

type tables = {
  nterms : int; nnonterms : int;
  actions : string; defaults : string; gotos : string; lhs : string; len : string;
  reduce : (unit -> Obj.t) array;
}

(* The stack: a symbol's state, value and positions; sp its size; the
 * first, the start state's, with the positions where the text begins.
 * len: in an action, its rule's number of symbols, the stack's last.
 * One parser at a time owns them: run saves and restores them, for a
 * parser called by another's action. *)
type symbol = { state : int; v : Obj.t; first : Lexing.position; last : Lexing.position }
let stack = ref [||]
let sp = ref 0
let len = ref 0

let nth n = !stack.(!sp - !len + n - 1)
let value n = (nth n).v
let rhs_start_pos n = (nth n).first
let rhs_end_pos n = (nth n).last
let symbol_end_pos () = !stack.(!sp - 1).last
let symbol_start_pos () =
  let rec go n = if n > !len then symbol_end_pos () else let s = nth n in if s.first <> s.last then s.first else go (n + 1) in
  go 1
let symbol_start () = (symbol_start_pos ()).pos_cnum
let symbol_end () = (symbol_end_pos ()).pos_cnum
let rhs_start n = (rhs_start_pos n).pos_cnum
let rhs_end n = (rhs_end_pos n).pos_cnum

let push s =
  if !sp = Array.length !stack then stack := Array.append !stack (Array.make (max 64 !sp) s);
  !stack.(!sp) <- s;
  incr sp

let run (t : tables) start ~number ~semantic lexer (lexbuf : Lexing.lexbuf) =
  let u16 s i = String.get_uint16_le s (2 * i) in
  let saved = !stack, !sp, !len in
  let restore () = let a, b, c = saved in stack := a; sp := b; len := c in
  stack := [||]; sp := 0; len := 0;
  push { state = start; v = Obj.repr (); first = lexbuf.lex_curr_p; last = lexbuf.lex_curr_p };
  (* the token read and not yet shifted, if any *)
  let ahead = ref None in
  let rec loop () =
    let state = !stack.(!sp - 1).state in
    let action =
      match u16 t.defaults state with
      | 0 ->
          let tok = match !ahead with Some tok -> tok | None -> let tok = lexer lexbuf in ahead := Some tok; tok in
          u16 t.actions ((t.nterms * state) + number tok)
      | a -> a
    in
    if action = 0 then raise Parse_error
    else if action = 1 then !stack.(!sp - 1).v
    else if action land 1 = 0 then begin
      let tok = match !ahead with Some tok -> tok | None -> assert false in
      push { state = (action - 2) / 2; v = semantic tok; first = lexbuf.lex_start_p; last = lexbuf.lex_curr_p };
      ahead := None;
      loop ()
    end
    else begin
      let r = (action - 3) / 2 in
      len := u16 t.len r;
      let v = t.reduce.(r) () in
      (* the rule's text: from its first symbol to its last; of no symbol, where the last one before ended *)
      let before = !stack.(!sp - !len - 1) in
      let first = if !len = 0 then before.last else (nth 1).first and last = if !len = 0 then before.last else (nth !len).last in
      sp := !sp - !len;
      (match u16 t.gotos ((t.nnonterms * before.state) + u16 t.lhs r) with
       | 0 -> raise Parse_error
       | s -> push { state = s - 1; v; first; last });
      loop ()
    end
  in
  match loop () with
  | v -> restore (); v
  | exception e -> restore (); raise e
